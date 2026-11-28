-- The guide engine: reads Data/Routes.lua, finds the character's guide and step, and tracks progress.
--
-- A step is a serialized table, parsed on first use and turned into "elements" (a command plus
-- arguments); everything past "Guide format to elements" reads only those. Progress is keyed by step id.
--   * A step applies when its `when` fits the character, play settings and current state.
--   * A step is done when every task in it is. Live state is re-read each time; one-off events
--     (arriving, flying) are latched per character.
--   * A step "with" another runs beside the main step; a sticky step runs until done; a step that
--     "requires" a side step waits for it; a hidden step only lends its waypoints.
--   * Quest, level and place commands are judged here (Judge); the rest in GuideChecks.lua (G.checks).
--   * Skip drops a step, and any quest it would have accepted, from the rest of the guide.
--     Back reopens an earlier step and holds it until done or skipped.

local ADDON, ns = ...
local T = ns.T
local D, W, L = ns.Data, ns.World, ns.Log

local G = {}
ns.Guide = G

local UNITS = 10000
local STICKY_REACH = 40      -- side steps older than this many steps are dropped
local ARRIVE = 30            -- yards: default arrival radius
local guides, byName         -- parsed guide headers, in file order
local facts                  -- faction, race and class, as the guides spell them
local applies = {}           -- condition -> result cache; cleared on level up
local appliesAll = {}        -- ... and by a whole "a|b" text, cleared with it
local generation = 0         -- bumped whenever that cache is cleared
local canBack                -- cached "is there a step to go back to"; reset on every Refresh

-- G.checks[command] = function(element, env) returning what Judge returns (GuideChecks.lua).
G.checks = {}

-- Conditions

-- `home`: the race whose starting zone the character began in when that isn't its own (G.Began).
local function ReadFacts()
	local _, race = UnitRace("player")
	local _, class = UnitClass("player")
	local began = ns.char and ns.char.began
	facts = { faction = UnitFactionGroup("player"), race = race == "Scourge" and "Undead" or race, class = class,
		home = type(began) == "string" and began or nil }
end

-- "Human Warrior/Dwarf": any "/" alternative, all of its words.
local function Applies(cond)
	if not cond or cond == "" then return true end
	local known = applies[cond]
	if known ~= nil then return known end
	local level, match = L.Level(), false
	for alternative in cond:gmatch("[^/]+") do
		local all = true
		for entry in alternative:gmatch("!?%w+") do
			local negated = entry:sub(1, 1) == "!"
			local word = negated and entry:sub(2) or entry
			local needed = tonumber(word)
			local fits = word == facts.faction or word == facts.race or word:upper() == facts.class
				or (needed ~= nil and level >= needed) or (facts.home ~= nil and word == facts.home)
			if fits == negated then
				all = false
				break
			end
		end
		if all then
			match = true
			break
		end
	end
	applies[cond] = match
	return match
end

-- "a|b": all must fit. (Kept by the whole text too: every step's and guide's are asked at each scan, and taking
-- the text apart made something every time.)
local function AppliesAll(conds)
	if not conds or conds == "" then return true end
	local known = appliesAll[conds]
	if known ~= nil then return known end
	local fits = true
	for cond in conds:gmatch("[^|]+") do
		if not Applies(cond) then
			fits = false
			break
		end
	end
	appliesAll[conds] = fits
	return fits
end

local function ForgetApplies()
	wipe(applies)
	wipe(appliesAll)
	generation = generation + 1
end

-- Reading the data

local function Numbers(text)
	local out = {}
	for number in text:gmatch("%-?%d+") do out[#out + 1] = tonumber(number) end
	return out
end

-- The numbers in an element's arguments, usually a quest id first. A negative id on .turnin /
-- .complete means "only if the quest is in the log" (element.held).
local HELD = { turnin = true, complete = true }
local function Ids(element)
	local ids = element.ids
	if not ids then
		ids = Numbers(element.args)
		if HELD[element.command] and ids[1] and ids[1] < 0 then
			ids[1] = -ids[1]
			element.held = true
		end
		element.ids = ids
	end
	return ids
end

-- An element's arguments, split at commas and trimmed.
local function Args(element)
	local list = element.list
	if not list then
		list = {}
		for arg in element.args:gmatch("[^,]+") do
			local trimmed = strtrim(arg)
			if trimmed ~= "" then list[#list + 1] = trimmed end
		end
		element.list = list
	end
	return list
end

-- Guide names repeat across faction groups.
local function Key(guide)
	-- (Asked at every look at what is saved for it: made once a guide.)
	local key = guide.savedKey
	if not key then
		key = guide.group .. "\\" .. guide.name
		guide.savedKey = key
	end
	return key
end

-- Guide format to elements
-- A step is a table: `id`, `when` (conditions), `at` (places) and `tasks` (typed lines such as
-- { type = "accept", quest = 783 }). LINES has one converter per task type, TESTS one per
-- condition. An unknown task type becomes a note; an unknown test counts as met.

local NONE = {}
local PLAIN = false      -- G.lib.Plain(true): don't generate text for a line that has none

local function Each(value)
	if value == nil then return NONE end
	if type(value) == "table" and value[1] ~= nil then return value end
	return { value }
end

local function Comma(value)
	local out = {}
	for i, part in ipairs(Each(value)) do out[i] = tostring(part) end
	return table.concat(out, ",")
end

-- Expands a character condition to the alternatives Applies takes:
-- { { "Alliance", "!Hunter" }, { "Horde" } } for "Alliance !Hunter/Horde". nil when it isn't only about the character.
local function Fits(node)
	if type(node) ~= "table" then return nil end
	local out = {}
	if node.all ~= nil then
		-- Cross product of the members' alternatives.
		out[1] = {}
		for _, member in ipairs(node.all) do
			local ways = Fits(member)
			if not ways then return nil end
			local grown = {}
			for _, chosen in ipairs(out) do
				for _, way in ipairs(ways) do
					local both = {}
					for i, had in ipairs(chosen) do both[i] = had end
					for _, word in ipairs(way) do both[#both + 1] = word end
					grown[#grown + 1] = both
				end
			end
			out = grown
		end
	elseif node.no ~= nil then
		-- Negation: one word of each alternative must fail.
		local ways = Fits(node.no)
		if not ways then return nil end
		out[1] = {}
		for _, way in ipairs(ways) do
			local grown = {}
			for _, chosen in ipairs(out) do
				for _, word in ipairs(way) do
					local both = {}
					for i, had in ipairs(chosen) do both[i] = had end
					both[#both + 1] = word:sub(1, 1) == "!" and word:sub(2) or ("!" .. word)
					grown[#grown + 1] = both
				end
			end
			out = grown
		end
	elseif node.any ~= nil then
		for _, member in ipairs(node.any) do
			local ways = Fits(member)
			if not ways then return nil end
			for _, way in ipairs(ways) do out[#out + 1] = way end
		end
	else
		local words = node.class or node.race or node.faction
		if words ~= nil then
			for _, word in ipairs(Each(words)) do out[#out + 1] = { tostring(word) } end
		elseif node.minLevel ~= nil then
			out[1] = { tostring(node.minLevel) }
		elseif node.never ~= nil then
			out[1] = { "skip" }
		else
			return nil
		end
	end
	return out
end

-- The same as a condition string for Applies ("" for none).
local function Who(node)
	local ways = node ~= nil and Fits(node)
	if not ways then return "" end
	local out = {}
	for i, way in ipairs(ways) do out[i] = table.concat(way, " ") end
	return table.concat(out, "/")
end

-- { below = 20 } -> "<20". `plain` is the comparison written without a sign.
local SIGN = { below = "<", above = ">", atMost = "<=", atLeast = ">=", exactly = "=" }
local function Compared(range, plain)
	for name, number in pairs(range) do
		return (name == plain and "" or SIGN[name] or "") .. tostring(number)
	end
	return ""
end

-- A level point: 14, 13.5, { level = 7, xp = 1140 }, { level = 14, short = 1200 }.
local function Point(point)
	if type(point) ~= "table" then return tostring(point) end
	if point.xp ~= nil then return point.level .. "+" .. point.xp end
	return point.level .. "-" .. (point.short or 0)
end

-- An XP rate: { below = 1.5 }, { above = 1.59 }, { atLeast = 2 }, { from = 1.49, to = 1.59 }.
local function Rate(range)
	if range.from ~= nil then return range.from .. "-" .. range.to end
	return Compared(range, "atLeast")
end

-- Tests in a step's `when`. Each returns "tag" or "line", a name and arguments, or nil (counts as met).
local SETTINGS = { hardcore = "hardcore", softcore = "softcore", auctionHouse = "ah", selfFound = "ssf" }
local QUEST_IS = { active = { "isOnQuest", "isNotOnQuest" }, ready = { "isQuestComplete", "isQuestNotComplete" },
	done = { "isQuestTurnedIn" }, open = { "isQuestAvailable" } }
local STATS = { dps = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", armor = "ITEM_MOD_ARMOR_SHORT", quality = "QUALITY", itemLevel = "LEVEL" }

local function Cooldown(kind)
	return function(test)
		local left = test.left or NONE
		return "line", "cooldown", kind .. "," .. test[kind .. "Cooldown"] .. "," .. (left.atLeast ~= nil and ("<" .. left.atLeast) or (">" .. (left.atMost or 0)))
	end
end

local TESTS = {
	setting = function(test, no)
		if not no and SETTINGS[test.setting] then return "tag", SETTINGS[test.setting], "" end
	end,
	xprate = function(test, no)
		if not no then return "tag", "xprate", Rate(test.xprate) end
	end,
	group = function(test, no)
		if not no then return "line", "group", test.group == true and "" or tostring(test.group) end
	end,
	solo = function(_, no)
		if not no then return "line", "solo", "" end
	end,
	dead = function(_, no)
		if not no then return "line", "showwhiledead", "" end
	end,
	dungeon = function(test, no) return "line", "dungeon", (no and "!" or "") .. tostring(test.dungeon) end,
	quest = function(test, no)
		local command = (QUEST_IS[test.is] or NONE)[no and 2 or 1]
		if command then return "line", command, Comma(test.quest) end
	end,
	level = function(test, no)
		local level = test.level
		if not no and type(level) == "table" then
			return "line", "xp", (level.atLeast ~= nil and ("<" .. Point(level.atLeast)) or (">" .. Point(level.below))) .. ",1"
		end
	end,
	maxLevel = function(test, no)
		if not no then return "line", "maxlevel", test.maxLevel .. (test.thenFrom and ("," .. test.thenFrom) or "") end
	end,
	zone = function(test, no)
		local names = {}
		for i, zone in ipairs(Each(test.zone)) do names[i] = tostring(zone) end
		return "line", "zoneskip", table.concat(names, "+") .. (no and "" or ",1")
	end,
	area = function(test, no)
		local flags = (no and 0 or 1) + (test.unmapped and 2 or 0)
		return "line", "subzoneskip", test.area .. (flags > 0 and ("," .. flags) or "")
	end,
	item = function(test, no)
		if not no then return "line", "itemcount", test.item .. "," .. Compared(test.count or NONE, "atLeast") .. (test.bank and ",1" or "") end
	end,
	money = function(test, no)
		local money = test.money
		if not no and type(money) == "table" then
			return "line", "money", money.atLeast ~= nil and ("<" .. money.atLeast) or (">" .. tostring(money.below))
		end
	end,
	gear = function(test, no)
		if not no then return "line", "itemStat", test.gear .. "," .. (STATS[test.stat] or tostring(test.stat)) .. "," .. Compared(test.is or NONE, "exactly") end
	end,
	skill = function(test, no)
		local is = test.is
		if not no and type(is) == "table" then
			return "line", "skill", test.skill .. "," .. (is.atLeast ~= nil and ("<" .. is.atLeast) or tostring(is.below)) .. ",1"
		end
	end,
	spell = function(test, no) return "line", "train", test.spell .. (no and ",1" or ",3") end,
	itemCooldown = Cooldown("item"),
	spellCooldown = Cooldown("spell"),
	aura = function(test, no) return "line", "aura", tostring(no and test.aura or -test.aura) end,
	wearing = function(test, no) return "line", "equip", (no and test.slot or -test.slot) .. "," .. test.wearing end,
	homeAt = function(test, no)
		if not no then return "line", "bindlocation", test.homeAt .. ",1" end
	end,
}

local function Test(node)
	if type(node) ~= "table" then return nil end
	local no = node.no ~= nil
	local test = no and node.no or node
	if type(test) ~= "table" then return nil end
	for key in pairs(test) do
		if TESTS[key] then return TESTS[key](test, no) end
	end
end

-- "Durotar,52.1,43.2", "1411,52.1,43.2", or world yards as "1411/1,-4214.45,-623.92".
local function Spot(spot)
	if spot.west ~= nil or spot.north ~= nil then
		return ("%d/%d,%s,%s"):format(spot.map or 0, spot.continent or 0, tostring(spot.west), tostring(spot.north))
	end
	return tostring(spot.zone or spot.map) .. "," .. tostring(spot.x) .. "," .. tostring(spot.y)
end

-- A place by its `as`: the place itself, waypoint, pin, fallback, nearest, backup.
local function PlaceLine(spot)
	local kind, within, args = spot.as, spot.within, Spot(spot)
	if kind == "backup" then
		if within == nil then return "waypoint", args end
		return "waypoint", args .. (within ~= 0 and ("," .. within .. ",0") or ",0")
	elseif kind == "waypoint" then
		return "goto", args .. "," .. (within or ARRIVE) .. ",0"
	elseif kind == "nearest" then
		return "goto", args .. ",-" .. (within or ARRIVE)
	elseif kind == "pin" then
		return "goto", args .. ",0"
	elseif kind == "fallback" then
		return "goto", args .. ",0,0"
	end
	return "goto", args
end

-- The people a line names: "Name::1234;Other Name", with a "+" when they belong to the task above.
local function Names(line)
	local out = {}
	for i, who in ipairs(Each(line.who)) do
		out[i] = type(who) == "table" and (tostring(who.name) .. (who.npc and ("::" .. who.npc) or "")) or tostring(who)
	end
	return (line.attached and "+" or "") .. table.concat(out, ";")
end

local function Listed(command, field)
	return function(line) return command, Comma(line[field]) end
end

local function Flagged(command, field, flags)
	return function(line)
		local sum = 0
		for name, bit in pairs(flags) do
			if line[name] then sum = sum + bit end
		end
		return command, tostring(line[field] or "") .. (sum > 0 and ("," .. sum) or "")
	end
end

local function Button(command, field)
	return function(line)
		local out = {}
		for i, id in ipairs(Each(line[field])) do out[i] = id .. (line.always and ":p" or "") end
		return command, table.concat(out, ",")
	end
end

-- Task types in a step's `tasks`. Each returns command, arguments, and default text for a line with none.
local LINES = {
	-- (A note's argument: the yards of the step's place within which alone it is said, or nothing.)
	note = function(line) return "", line.near ~= nil and tostring(line.near) or "" end,
	["do"] = function() return "+", "" end,
	accept = function(line)
		local flags = (line.byHand and 1 or 0) + (line.onlyAfter and 2 or 0)
		return "accept", line.quest .. (flags > 0 and ("," .. flags) or "") .. (line.onlyAfter and ("," .. line.onlyAfter) or "")
	end,
	turnin = function(line)
		if line.ifHeld then return "turnin", "-" .. line.quest .. (line.whenReady and ",1" or "") end
		local more = (line.reward or line.byHand) and ("," .. (line.reward or 0)) or ""
		return "turnin", line.quest .. more .. (line.byHand and ",1" or "")
	end,
	objective = function(line)
		local more = (line.count or line.hideWhenDone) and ("," .. (line.count or 0)) or ""
		return "complete", (line.ifHeld and "-" or "") .. line.quest .. "," .. (line.objective or 1) .. more .. (line.hideWhenDone and ",1" or "")
	end,
	collect = function(line)
		local args = { line.item, line.count or 1 }
		local mask = 0
		for _, index in ipairs(Each(line.objectives)) do mask = mask + 2 ^ (index - 1) end
		local flags = (line.showOnly and 1 or 0) + (line.lessCounted and 2 or 0) + (line.doneWithObjectives and 4 or 0) + (line.bank and 8 or 0)
			+ (line.keepAfterTurnin and 16 or 0) + (line.onlyIfCarried and 64 or 0) + (line.usedUp and 128 or 0)
		local tail = NONE
		if line.lessItem then
			flags = flags + 32
			tail = { "item", line.lessItem.each or 1, line.lessItem.item }
		elseif line.lessSkill then
			flags = flags + 32
			tail = { line.lessSkill.skill, line.lessSkill.each or 1, line.lessSkill.from or 0, line.lessSkill.atLeast or 0 }
		elseif line.each ~= nil then
			tail = { line.each }
		end
		-- Arguments are positional, so options without a quest need a 0 in its place.
		if line.quest or mask > 0 or flags > 0 then
			args[#args + 1] = line.quest or 0
			if mask > 0 or flags > 0 then args[#args + 1] = mask end
			if flags > 0 then args[#args + 1] = flags end
		end
		for _, part in ipairs(tail) do args[#args + 1] = part end
		return "collect", Comma(args)
	end,
	abandon = Listed("abandon", "quest"),
	grind = function(line) return "xp", Point(line.to) end,
	die = function() return "deathskip", "", "Die here and res at the spirit healer" end,
	train = function(line)
		return "train", tostring(line.spell), line.spell and ("Train " .. (C_Spell.GetSpellName(line.spell) or "at your trainer")) or nil
	end,
	skill = function(line) return "skill", tostring(line.skill) .. "," .. tostring(line.to) end,
	fly = function(line) return "fly", tostring(line.to or ""), line.to and ("Fly to " .. line.to) or "Take the flight" end,
	flightpath = function(line)
		local flags = (line.noteOnly and 1 or 0)
		return "fp", tostring(line.name or "") .. (flags > 0 and line.name and ("," .. flags) or ""),
			line.name and ("Get the flight path: " .. line.name) or "Get the flight path"
	end,
	hearth = function(line) return "hs", tostring(line.to or ""), line.to and ("Hearth to " .. line.to) or "Use your hearthstone" end,
	sethome = function(line) return "home", tostring(line.inn or ""), line.inn and ("Set your hearthstone: " .. line.inn) or "Set your hearthstone here" end,
	homeIs = function(line) return "bindlocation", tostring(line.area) end,
	enterZone = function(line)
		local zone = line.zone
		return "zone", tostring(zone), "Travel to " .. tostring(type(zone) == "number" and W.MapName(zone) or zone)
	end,
	area = Flagged("subzone", "area", { leave = 1, unmapped = 2 }),
	place = PlaceLine,
	travel = function(line) return "goto", Spot(line) .. "," .. (line.within or ARRIVE) end,
	path = function(line)
		local out = { tostring(line.zone or line.map) }
		for _, point in ipairs(line.points or NONE) do
			out[#out + 1] = tostring(point[1])
			out[#out + 1] = tostring(point[2])
		end
		return "line", table.concat(out, ",")
	end,
	target = function(line) return "target", Names(line) end,
	kill = function(line) return "mob", Names(line) end,
	scan = function(line) return "unitscan", Names(line) end,
	gossip = function(line)
		return "skipgossip", (line.npc ~= nil and tostring(line.npc) or "") .. (line.picks ~= nil and ("," .. Comma(line.picks)) or "")
	end,
	pickGossip = function(line) return "skipgossipid", (line.attached and "+" or "") .. Comma(line.options) end,
	talk = Listed("gossipoption", "option"),
	vendor = function(line) return "vendor", line.npc ~= nil and tostring(line.npc) or "", "Sell and restock" end,
	trainer = function() return "trainer", "", "Visit your trainer" end,
	useItem = Button("use", "item"),
	useSpell = Button("usespell", "spell"),
	macro = function(line) return "macro", tostring(line.name) .. (line.icon ~= nil and ("," .. line.icon) or "") end,
	link = function(line) return "link", tostring(line.url or "") end,
	cast = Listed("cast", "spell"),
	destroy = Listed("destroy", "item"),
	deposit = Listed("bankdeposit", "item"),
	withdraw = Listed("bankwithdraw", "item"),
	haveAura = function(line) return "aura", tostring(line.gone and -line.spell or line.spell) end,
	equip = function(line) return "equip", (line.off and -line.slot or line.slot) .. "," .. tostring(line.item) end,
	timer = function(line) return "timer", line.seconds .. (line.label and ("," .. line.label) or "") end,
	noCheckbox = function() return "disablecheckbox", "" end,
	check = function(line)
		local where, command, args = Test(line.test)
		if where == "line" then return command, args end
	end,
}

-- Converts a step table to { index, id, cond, tags, elements }.
local function Build(named, index, id)
	local step = { index = index, id = named.id or id, tags = {}, elements = {} }
	local who, tests = {}, {}
	local function Tag(name, value, cond)
		step.tags[#step.tags + 1] = { name = name, value = value, cond = cond ~= "" and cond or nil }
	end
	local function Add(command, args, text, cond)
		step.elements[#step.elements + 1] = { command = command, args = args, text = text ~= nil and text ~= "" and text or nil,
			cond = cond ~= "" and cond or nil }
	end
	-- A step field is a value, { is, when } for a conditional one, or a list of those.
	local function Field(key, name)
		local value = named[key]
		if value == nil then return end
		for _, entry in ipairs(type(value) == "table" and value.is == nil and value or { value }) do
			local is, when = entry, nil
			if type(entry) == "table" then is, when = entry.is, entry.when end
			if is ~= nil and is ~= false then Tag(name, is == true and "" or tostring(is), Who(when)) end
		end
	end

	local when = named.when
	for _, member in ipairs(type(when) == "table" and when.all ~= nil and next(when, next(when)) == nil and when.all or { when }) do
		if Fits(member) then
			who[#who + 1] = member
		elseif type(member) == "table" then
			local among, test = nil, member
			if member.among ~= nil and member.needs ~= nil then among, test = member.among, member.needs end
			local where, name, args = Test(test)
			if where == "tag" then
				Tag(name, args, Who(among))
			elseif where == "line" then
				tests[#tests + 1] = { name, args, Who(among) }
			end
		end
	end
	step.cond = #who == 0 and "" or Who(#who == 1 and who[1] or { all = who })

	Field("sticky", "sticky")
	Field("requires", "requires")
	Field("label", "label")
	Field("with", "completewith")
	Field("hidden", "hidewindow")
	Field("loop", "loop")

	local function Places(at, cond)
		if at == nil then return end
		for _, spot in ipairs(at[1] ~= nil and at or { at }) do
			local command, args = PlaceLine(spot)
			Add(command, args, nil, spot.when ~= nil and Who(spot.when) or cond)
		end
	end
	Places(named.at, "")
	for _, line in ipairs(named.tasks or NONE) do
		local make = LINES[line.type]
		local cond = Who(line.when)
		local command, args, words
		if make then command, args, words = make(line) end
		if command then
			local text = line.type == "macro" and line.body or line.text
			if (text == nil or text == "") and not PLAIN then text = words end
			Add(command, args, text, cond)
			-- What the objective counts, used to find its line in the quest log (Objective).
			local counts = line.type == "objective" and type(line.counts) == "table" and line.counts
			if counts then
				local kind = counts.item and "i" or counts.npc and "c" or counts.object and "o"
				if kind then step.elements[#step.elements].counts = { kind = kind, id = counts.item or counts.npc or counts.object } end
			end
		else
			-- Unknown task type: shown as a note.
			Add("", "", line.text or "Part of this step needs a newer ShyQuest.", cond)
		end
		Places(line.at, cond)
	end
	for _, test in ipairs(tests) do Add(test[1], test[2], nil, test[3]) end
	return step
end

-- `raw` is a step table, or a string holding one (shipped guides).
local function ReadStep(raw, index, id)
	if type(raw) == "string" then
		local make = loadstring("return " .. raw)
		raw = make and make() or nil
	end
	return Build(type(raw) == "table" and raw or NONE, index, id)
end

-- A step's stable id: saved progress is keyed by it.
local function IdOf(guide, index)
	local raw = guide.raw[index]
	if raw == nil then return nil end
	return guide.ids and guide.ids[index] or (type(raw) == "table" and raw.id) or ("#" .. index)
end

local function LoadGuides()
	guides, byName = {}, {}
	for _, raw in ipairs(ns.data.routes or {}) do
		local guide = { name = raw.name, group = raw.group, cond = Who(raw.who), raw = raw.steps or {}, ids = raw.ids, rev = raw.rev,
			steps = {}, next = {} }
		if raw.starts ~= nil then guide.default = raw.starts ~= true and Who(raw.starts) or "" end
		for _, entry in ipairs(type(raw.next) == "table" and raw.next or NONE) do
			if type(entry) == "table" then
				guide.next[#guide.next + 1] = { name = entry.guide, cond = entry.when ~= nil and Who(entry.when) or nil }
			else
				guide.next[#guide.next + 1] = { name = entry }
			end
		end
		guide.internal = raw.internal == true
		-- Only for characters levelling at that XP rate.
		guide.xprate = type(raw.xprate) == "table" and Rate(raw.xprate) or nil
		-- The careful (no-death) route: offered when careful play is on, never auto-picked.
		guide.careful = raw.careful == true
		guide.low, guide.high = raw.name:match("^(%d+)%-(%d+)")
		guide.low, guide.high = tonumber(guide.low) or 1, tonumber(guide.high) or 60
		guides[#guides + 1] = guide
		byName[Key(guide)] = guide
	end
end

local FarDetours   -- (below, with the places steps are at)
local Away         -- (below too)

local function Step(guide, index)
	local step = guide.steps[index]
	if not step and guide.raw[index] then
		-- Through G.lib so the reader can be replaced.
		step = G.lib.Read(guide.raw[index], index, IdOf(guide, index))
		-- A dungeon run's steps are for its dungeon whatever the settings say of it (Wanted).
		step.run = guide.run
		guide.steps[index] = step
		if guide.far == nil then FarDetours(guide) end
	end
	return step
end

-- label -> step index, and guide.requiredBy: label -> first main step that requires it.
local function Labels(guide)
	if not guide.labels then
		guide.labels, guide.requiredBy = {}, {}
		for index = 1, #guide.raw do
			local needs, side
			for _, tag in ipairs(Step(guide, index).tags) do
				if tag.name == "label" then guide.labels[tag.value] = index end
				if tag.name == "requires" then needs = tag.value end
				if tag.name == "completewith" or tag.name == "sticky" then side = true end
			end
			if needs and not side and not guide.requiredBy[needs] then guide.requiredBy[needs] = index end
		end
	end
	return guide.labels
end

-- Does a step apply to this player

-- "<1.5", ">1.49", "1.49-1.59" against the XP rate setting.
local function RateFits(spec)
	local rate = T.db.guide.xprate
	local op, low, high = spec:match("^([<>]?)%s*([%d.]+)%-?([%d.]*)")
	low, high = tonumber(low), tonumber(high)
	if not low then return true end
	if op == "<" then return rate < low end
	if op == ">" then return rate > low end
	return rate >= low and rate <= (high or math.huge)
end

local function Wanted(step)
	if not AppliesAll(step.cond) then return false end
	local db = T.db.guide
	for _, tag in ipairs(step.tags) do
		if not tag.cond or Applies(tag.cond) then
			local name, value = tag.name, tag.value
			if name == "hardcore" and not db.hardcore then return false end
			if name == "softcore" and db.hardcore then return false end
			if name == "ssf" and not db.selfFound then return false end
			if name == "ah" and db.selfFound then return false end
			if name == "xprate" and not RateFits(value) then return false end
		end
	end
	for _, element in ipairs(step.elements) do
		if not element.cond or Applies(element.cond) then
			local command = element.command
			if command == "group" and not db.group then return false end
			-- The solo alternative to a group step.
			if command == "solo" and db.group then return false end
			if command == "dungeon" then
				local not_, name = element.args:match("^(!?)(%w+)")
				if name then
					-- One across the sea from the guide comes in only when ticked, never just for being at your level.
					-- A run's own dungeon is in.
					local on = step.run == name or (ns.DungeonOn(name) and (not step.far or ns.DungeonTicked(name)))
					if on == (not_ == "!") then return false end
					-- You said to do it as you get there: its step waits until you're near.
					if on and not_ == "" and step.run ~= name and Away(step, name) then return false end
				end
			end
		end
	end
	return true
end

-- Step structure

-- Is this element a task, with a line of its own that later elements can attach to. (Whether
-- it blocks the step is Judge's call.)
local TASK_ALWAYS = { accept = true, turnin = true, complete = true, abandon = true, hs = true, home = true, fly = true,
	vendor = true, trainer = true, zone = true, subzone = true, destroy = true, bankdeposit = true,
	collect = true, skipgossip = true, cast = true, deathskip = true, ["+"] = true }
local TASK_IF_SAID = { gossipoption = true, aura = true, equip = true, bankwithdraw = true, train = true }
local function IsTask(element)
	local command = element.command
	if TASK_ALWAYS[command] then return true end
	local list = Args(element)
	if command == "train" then return element.text ~= nil and (tonumber(list[2]) or 0) % 2 == 0 end
	if TASK_IF_SAID[command] then return element.text ~= nil end
	if command == "fp" then return (tonumber(list[2]) or 0) % 2 == 0 end
	if command == "xp" then return tonumber(list[2]) == nil end
	if command == "skill" then return element.text ~= nil and tonumber(list[3]) == nil end
	if command == "goto" then return (tonumber(list[4]) or 0) > 0 and list[5] == nil end
	return false
end

-- Elements that attach to the task before them.
local FOLLOW = {
	plain = { ["goto"] = true, waypoint = true, line = true, timer = true, disablecheckbox = true },
	-- ...and these only when written with a "+" ("mob +Redridge Mongrel").
	plus = { target = true, mob = true, unitscan = true, skipgossipid = true },
}

-- Derived from element order, cached per `generation` (conditions decide which elements count):
--   parent[n]    the task element n belongs to
--   soft[n]      task n only shows a count (.disablecheckbox follows it)
--   timer[n]     { seconds, label } to count down once task n is done
--   binds        the step has a .bindlocation, which answers for its .home
local function Shape(step)
	local shape = step.shape
	if shape and shape.generation == generation then return shape end
	shape = { generation = generation, parent = {}, soft = {}, timer = {}, binds = false }
	local last
	for number, element in ipairs(step.elements) do
		if not element.cond or Applies(element.cond) then
			local command = element.command
			if command == "bindlocation" then shape.binds = true end
			local follows = FOLLOW.plain[command] and not (command == "goto" and IsTask(element))
			if FOLLOW.plus[command] and element.args:sub(1, 1) == "+" then follows = true end
			if follows and last then
				shape.parent[number] = last
				if command == "disablecheckbox" then
					shape.soft[last] = true
				elseif command == "timer" then
					local list = Args(element)
					local seconds = tonumber(list[1])
					if seconds then shape.timer[last] = { seconds, list[2] } end
				end
			end
			if IsTask(element) then last = number end
		end
	end
	step.shape = shape
	return shape
end

-- Saved progress

-- Per character and guide (ns.char.guides):
--   start     where the guide was started: nothing before it is asked for
--   floor     the live step when last looked: the place never slips behind it, whatever setting changes
--   done      [step] = true (ticked off, or passed) or "skip"
--   dropped   [quest] = the step whose skip dropped it from the guide
--   held      [step] = true: the player went back to it, so it isn't auto-passed
--   latched   [step][element] = true: one-off events that have happened
--   after     the guide that handed over to this one
--
-- In memory these are keyed by step index; on disk by step id, so a rebuilt guide keeps
-- everyone's place. Thaw converts on first use in a session, Freeze converts back at logout.
-- A place (start, left, floor) is saved as its step id plus the AROUND ids before it; if its
-- own step is gone it resumes just past the nearest survivor, else it is found again (Scan).

local AROUND = 3      -- ids saved before a place, in case its own step is removed
local thawed = {}     -- guide key -> thawed this session (keyed by step index)

-- step id -> index.
local function Whereabouts(guide)
	local at = guide.at
	if not at then
		at = {}
		for index = #guide.raw, 1, -1 do at[IdOf(guide, index)] = index end
		guide.at = at
	end
	return at
end

local function Thaw(guide, saved)
	if saved.v ~= 2 then
		-- Not in the id-keyed form (or new this session): start clean and find the place again.
		saved.start, saved.floor, saved.left, saved.rev, saved.prints = nil, nil, nil, nil, nil
		saved.done, saved.latched, saved.held, saved.dropped = {}, {}, {}, {}
		return
	end
	saved.v, saved.rules = nil, nil
	local at = Whereabouts(guide)
	local function Move(old)
		local new = {}
		for id, value in pairs(type(old) == "table" and old or NONE) do
			if at[id] then new[at[id]] = value end
		end
		return new
	end
	local function Place(kept)
		if type(kept) ~= "table" then return nil end
		if kept[1] and at[kept[1]] then return at[kept[1]] end
		for off = 1, AROUND do
			local before = kept[off + 1] and at[kept[off + 1]]
			if before then return before + 1 end
		end
	end
	saved.done, saved.latched, saved.held, saved.dropped = Move(saved.done), Move(saved.latched), Move(saved.held), type(saved.dropped) == "table" and saved.dropped or {}
	for quest, id in pairs(saved.dropped) do saved.dropped[quest] = at[id] end
	saved.start, saved.left, saved.floor = Place(saved.start), Place(saved.left), Place(saved.floor)
end

local function Saved(guide)
	local all = ns.char.guides
	local key = Key(guide)
	local saved = all[key]
	if type(saved) ~= "table" then
		saved = { done = {}, latched = {} }
		all[key] = saved
	end
	if not thawed[key] and guide.raw then
		thawed[key] = true
		Thaw(guide, saved)
	end
	saved.done = saved.done or {}
	saved.latched = saved.latched or {}
	saved.held = saved.held or {}
	saved.dropped = saved.dropped or {}
	return saved
end

-- At PLAYER_LOGOUT: converts this session's records back to step ids.
local function Freeze()
	for key in pairs(thawed) do
		local guide, saved = byName[key], ns.char.guides[key]
		if guide and type(saved) == "table" and saved.v ~= 2 then
			local function Keep(old)
				local new = {}
				for index, value in pairs(old or NONE) do
					local id = IdOf(guide, index)
					if id then new[id] = value end
				end
				return new
			end
			local function Place(index)
				if not index then return nil end
				local kept = { IdOf(guide, index) or false }
				for off = 1, AROUND do kept[off + 1] = IdOf(guide, index - off) or false end
				return kept
			end
			saved.done, saved.latched, saved.held = Keep(saved.done), Keep(saved.latched), Keep(saved.held)
			for quest, index in pairs(saved.dropped or NONE) do saved.dropped[quest] = IdOf(guide, index) end
			saved.start, saved.left, saved.floor = Place(saved.start), Place(saved.left), Place(saved.floor)
			saved.v = 2
		end
	end
	wipe(thawed)
end

-- Whether a step applies to this player, and a guide's step, for callers outside this file.
G.Wanted, G.Step = Wanted, Step


-- Step indexes per quest and command: asks.accept[12] = { 31, 207 }. asks.collect is keyed by
-- the quest the item is for ("collect item,count,quest").
local function Asks(guide)
	local asks = guide.asks
	if not asks then
		asks = { accept = {}, complete = {}, turnin = {}, collect = {} }
		for index = 1, guide.raw and #guide.raw or 0 do
			for _, element in ipairs(Step(guide, index).elements) do
				local list = asks[element.command]
				local id = list and Ids(element)[element.command == "collect" and 3 or 1]
				if id and id > 0 then
					local steps = list[id]
					if not steps then
						steps = {}
						list[id] = steps
					end
					if steps[#steps] ~= index then steps[#steps + 1] = index end
				end
			end
		end
		guide.asks = asks
	end
	return asks
end
G.Asks = Asks

-- Returns the step whose skip dropped this element's quest, ABSENT, or nil when it still counts.
--   * Skipped accept: its quest is dropped everywhere but in that step, until it is picked up anyway.
--   * A quest not in the log that no step of this guide accepts: its objectives, turn-in and
--     collects (".collect item,count,quest") are ABSENT.
--   * A quest its giver doesn't offer this character (L.Unoffered), or doesn't list for being gray
--     (L.Hidden), is ABSENT until offered; one the data has for another race or class (L.ForMe), until
--     picked up anyway. A dungeon run asks for its quests gray or not: its guide only lets go of one not offered.
--     So is one whose giver waits to see an item in the bags that isn't there (L.Lacks).
-- A failed quest is not dropped: it stays in the log and counts as still to accept (Judge, L.Holds).
--   * A quest whose chain is lost (L.Lost: it, or one it needs first, is for another character, gray, past its
--     levels, not listed by its giver...) is ABSENT, and so is one whose earlier quests reach back below your
--     level and don't pay for going back (Route.Catching), or whose earlier quest was skipped or left behind
--     here (Gone): a chain is let go whole, never asked for at a giver who won't offer it.
local QUEST = { accept = true, turnin = true, complete = true }
local ABSENT = 0
-- Stand-ins for a step's latches: none saved, and "live state only" (see Evaluate's `bare`).
local NOTHING, BARE = {}, {}
local CHAIN = 5              -- prerequisite depth followed (here and by the catch-up, Roots)
local function Barred(quest, guide)
	local data = D.Quest(quest)
	return L.Unoffered(quest) or (data ~= nil and (L.Lacks(data) or (not guide.run and L.Hidden(data))))
end

-- Whether a quest can be started now, as this guide asks: a dungeon run asks for its quests gray or not.
local function Startable(data, guide)
	return L.CanStart(data, false, false, guide.run ~= nil)
end

-- Whether the chain to `quest` (not in the log, not done) is let go: lost for good, not worth catching up, or an
-- escort through elites your level or higher (Escort.Perilous: back once you outlevel them).
-- A dungeon run asks for its quests gray or not, and only lets go of one that can't be had.
local function ChainGone(quest, guide)
	if L.Lost(quest, guide.run ~= nil) then return true end
	if ns.Escort and ns.Escort.Perilous(quest) then return true end
	local data = not guide.run and D.Quest(quest)
	return data and not ns.Route.Catching(data) or false
end

-- Whether `quest` won't be had on this guide by the step at `index`: not in the log or done, and its chain let go
-- (ChainGone), its accept skipped, passed by where the player chose to go on from (saved.left), or handed in
-- here never accepted; or so for a quest it needs first.
local function Gone(guide, saved, quest, index, depth)
	-- (Set aside while a vendor is out of what it needs, Stock.lua: what waits on it waits with it.)
	if ns.Stock and not L.Done(quest) and ns.Stock.Aside(quest) then return true end
	if L.Has(quest) or L.Done(quest) then return false end
	if saved.dropped[quest] or ChainGone(quest, guide) then return true end
	local asks = Asks(guide)
	local given = asks.accept[quest]
	if given == nil then
		local handed = asks.turnin[quest]
		if handed ~= nil and handed[1] <= index then return true end
	elseif saved.left ~= nil and given[#given] < saved.left then
		return true
	end
	local data = depth < CHAIN and D.Quest(quest)
	if not data then return false end
	for _, before in ipairs(data.preGroup or NOTHING) do
		if L.Unmet(data, before) and Gone(guide, saved, before, index, depth + 1) then return true end
	end
	-- (One of preSingle done, or still to be had, keeps it.)
	for _, before in ipairs(data.preSingle or NOTHING) do
		if not Gone(guide, saved, before, index, depth + 1) then return false end
	end
	return data.preSingle ~= nil
end

local function Dropped(saved, element, index, guide)
	local command = element.command
	local list = Ids(element)
	-- (A quest set aside while a vendor is out of what it needs, Stock.lua: its steps stand aside with it.)
	local stock = ns.Stock
	if command == "collect" then
		local quest = list[3]
		if quest and quest > 0 and stock and stock.Aside(quest) then return index end
		if not quest or quest <= 0 or L.Has(quest) or L.Done(quest) then return nil end
		local by = saved.dropped[quest]
		if by and by ~= index then return by end
		if Barred(quest, guide) or ChainGone(quest, guide) then return ABSENT end
		local taken = guide.raw and Asks(guide).accept[quest]
		if taken and saved.left and taken[#taken] < saved.left and taken[#taken] < index then return ABSENT end
		return nil
	end
	-- "Only if in the log" lines (element.held) are Judge's to answer.
	if not QUEST[command] or element.held then return nil end
	local id = list[1]
	if id and stock and not L.Done(id) and stock.Aside(id) then return index end
	if not id or L.Has(id) or L.Done(id) then return nil end
	local by = saved.dropped[id]
	if by and by ~= index then return by end
	if Barred(id, guide) or ChainGone(id, guide) then return ABSENT end
	local taken = guide.raw and Asks(guide).accept[id]
	if command == "complete" and #list < 4 and guide.raw and not taken then return ABSENT end
	if command == "turnin" and guide.raw and not taken then return ABSENT end
	-- The player chose where to continue from (saved.left): quests accepted only before that are gone.
	if taken and saved.left and command ~= "accept" and taken[#taken] < saved.left and taken[#taken] < index then
		return ABSENT
	end
	-- A quest whose earlier quest won't be had here (skipped, left behind, its own chain gone) can't be either.
	if guide.raw then
		local data = D.Quest(id)
		if data and L.Before(data) ~= nil then
			for _, before in ipairs(data.preGroup or NOTHING) do
				if L.Unmet(data, before) and Gone(guide, saved, before, index, 1) then return ABSENT end
			end
			if data.preSingle then
				local open = false
				for _, before in ipairs(data.preSingle) do
					if L.Done(before) or not Gone(guide, saved, before, index, 1) then open = true end
				end
				if not open then return ABSENT end
			end
		end
	end
	return nil
end

-- "14", "7+1140" (1140 XP into level 7), "14-1200" (within 1200 XP of 14) or "13.5" (halfway through 13).
local function Reached(spec)
	local level, offset = spec:match("(%d+)([%+%.%-]?%d*)")
	level, offset = tonumber(level), tonumber(offset) or 0
	if not level then return true end
	local mine, xp, max = L.Level(), UnitXP("player"), UnitXPMax("player")
	if offset < 0 then return mine >= level or (mine == level - 1 and xp >= max + offset) end
	if offset >= 1 then return mine > level or (mine == level and xp >= offset) end
	return mine > level or (mine == level and xp >= max * offset)
end

local function OnAny(ids)
	for _, id in ipairs(ids) do
		if L.Has(id) then return true end
	end
	return false
end

local function AnyDone(ids)
	for _, id in ipairs(ids) do
		if L.Done(id) then return true end
	end
	return false
end

-- `enough`: a partial count that satisfies the guide (".complete 94896,1,3").
local function ObjectiveDone(id, objective, enough)
	if L.Done(id) then return true end
	local entry = L.entries[id]
	if not entry then return false end
	if entry.complete then return true end
	local info = (C_QuestLog.GetQuestObjectives(id) or {})[objective]
	if not info then return false end
	if info.finished == true then return true end
	return enough ~= nil and enough > 0 and (info.numFulfilled or 0) >= enough
end

-- The quest-log objective index a "complete" is for. The data's order can differ from the
-- client's, so `counts` (what the objective counts) is matched against the log first.
local function Objective(element)
	local ids = Ids(element)
	local counts = element.counts
	return counts and ids[1] and L.GoalOf(ids[1], counts.kind, counts.id) or ids[2] or 1
end

-- A uiMapID, or a zone name from the guides' own list.
local function MapOf(name)
	return tonumber(name) or (ns.data.routeInfo and ns.data.routeInfo.maps[name]) or nil
end

local function InZone(name)
	name = strtrim(name)
	local id = MapOf(name)
	if id and W.map == id then return true end
	if tonumber(name) then return false end
	name = name:lower()
	local zone, real, here = GetZoneText(), GetRealZoneText(), W.MapName(W.map)
	return (zone and zone:lower() == name) or (real and real:lower() == name) or (here and here:lower() == name) or false
end

-- Is the player in an area by area id (".subzone 16635"). `unmapped`: only where there is no map (a dungeon).
local function InArea(id, unmapped)
	-- (A guide that asks this is asked again in every part of a zone: ShyQuest.lua, within.)
	G.readsArea = true
	local name = id and C_Map.GetAreaInfo(id)
	if not name or (unmapped and W.map ~= nil) then return false end
	return name == GetSubZoneText() or name == GetZoneText()
end

-- Parses a ".goto" or ".waypoint":
--
--   .goto 1436/0,918.42,-9851.50    map/continent, then world yards (west, north)
--   .goto 2521,42.82,23.41          map, then percent across and down
--   .goto Mulgore,63.77,43.97       the same, map by name
--
-- then a radius and an optional fifth argument:
--
--   (nothing)   the place itself: arrow and pin
--   R           a task: done within R yards
--   R,0         a waypoint: passed within R yards, no pin
--   0           pin, no arrow: one of several places to look
--   0,0         last resort: the arrow goes there when nothing else is left
--   -R          one of several: the arrow takes the nearest
--
-- A ".waypoint" never has a pin; with a fifth argument, or no radius, it is a last resort.
local function Place(element)
	local at = element.at
	if at ~= nil then return at or nil end
	element.at = false
	local list = Args(element)
	local zone = list[1]
	local first = list[2] and tonumber(list[2]:match("^%-?%d+%.?%d*"))
	local second = list[3] and tonumber(list[3]:match("^%-?%d+%.?%d*"))
	if not (zone and first and second) then return nil end
	at = {}
	local map = zone:match("^(%d+)/%d+$")
	if map then
		at.map, at.west, at.north = tonumber(map), first, second
		at.continent = W.ToWorld(at.map, 5000, 5000)
		if at.continent then
			local _, position = C_Map.GetMapPosFromWorldPos(at.continent, CreateVector2D(at.north, at.west), at.map)
			if position then
				local x, y = position:GetXY()
				at.x, at.y = math.floor(x * UNITS + 0.5), math.floor(y * UNITS + 0.5)
			end
		end
	else
		at.map = MapOf(zone)
		if not at.map then return nil end
		at.x, at.y = math.floor(first * 100 + 0.5), math.floor(second * 100 + 0.5)
		at.continent, at.north, at.west = W.ToWorld(at.map, at.x, at.y)
	end

	local radius = list[4] and tonumber(list[4]:match("^%-?%d+%.?%d*"))
	local along = list[5] ~= nil
	at.arrow, at.pin = true, true
	if element.command == "waypoint" then
		at.pin = false
		at.low = along or radius == nil or radius == 0
		at.nearest = radius ~= nil and radius < 0
		if radius and radius ~= 0 then at.reach = math.abs(radius) end
	elseif radius then
		if radius > 0 then
			at.reach = radius
			if along then at.pin = false else at.task = true end
		elseif radius < 0 then
			at.nearest = true
		elseif along then
			at.low = true
		else
			at.arrow = false
		end
	end
	element.at = at
	return at
end

-- A dungeon taken "as you get there" (Run.lua's question): its step waits while you're far from it.
-- Near is ALONG.near yards, a little more once it leads. A step with no place never waits.
local ALONG = { near = 500, stay = 1.3 }
function Away(step, short)
	if not (ns.DungeonAlong and ns.DungeonAlong(short)) then return false end
	local at = step.spot
	if at == nil then
		at = false
		for _, element in ipairs(step.elements) do
			local place = (element.command == "goto" or element.command == "waypoint") and Place(element)
			if place and place.continent and place.north then
				at = place
				break
			end
		end
		step.spot = at
	end
	if not at then return false end
	local near = W.Known() and at.continent == W.continent
		and W.Between(W.north, W.west, at.north, at.west) <= ALONG.near * (step.nearby and ALONG.stay or 1)
	step.nearby = near or nil
	return not near
end

-- Whether a step is ever this character's: its class, race, side and starting place fit (the level it waits
-- for comes in time).
local function Ours(step)
	local cond = step.cond
	if not cond or cond == "" then return true end
	if not facts then ReadFacts() end
	return AppliesAll((cond:gsub("!?%d+", "")))
end

-- A dungeon far from a guide. Its steps go into every guide it can be run from, even one that never comes
-- near it (at that guide's head); when none of them lies within DETOUR_NEAR yards of any of the guide's own
-- steps this character is ever given (another class's errand there brings it no nearer), they are marked
-- `far` (with the steps for when it is not run), and "At my level" leaves it out of that guide (Wanted).
-- guide.far: short name -> true; guide.detours: the indexes of its dungeons' steps.
function FarDetours(guide)
	local DETOUR_NEAR = 3000
	guide.far, guide.detours = false, {}
	local home, theirs, marked = {}, {}, {}
	for index = 1, #guide.raw do
		local step = Step(guide, index)
		local short, alone
		for _, element in ipairs(step.elements) do
			if element.command == "dungeon" then
				local not_, name = element.args:match("^(!?)(%w+)")
				short, alone = name, not_ == "!"
			end
		end
		if short then marked[#marked + 1] = { step, short } end
		local where = Ours(step) and home or {}
		if short and not alone then
			where = theirs[short] or {}
			theirs[short] = where
			guide.detours[#guide.detours + 1] = index
		end
		for _, element in ipairs(step.elements) do
			local at = (element.command == "goto" or element.command == "waypoint") and Place(element)
			if at and at.continent and at.north then where[#where + 1] = at end
		end
	end
	local far = {}
	for short, places in pairs(theirs) do
		local near = #places == 0
		for _, there in ipairs(places) do
			for _, here in ipairs(home) do
				if here.continent == there.continent and W.Between(here.north, here.west, there.north, there.west) <= DETOUR_NEAR then
					near = true
					break
				end
			end
			if near then break end
		end
		if not near then far[short] = true end
	end
	for _, each in ipairs(marked) do
		if far[each[2]] then each[1].far = true end
	end
	guide.far = far
end

local function Arrived(at)
	return W.Known() and at.north ~= nil and at.reach ~= nil and (at.continent == nil or at.continent == W.continent)
		and W.Between(W.north, W.west, at.north, at.west) <= math.max(at.reach, 5)
end

-- Does the character know a flight path, by partial name ("Crossroads" matches "The Crossroads, The Barrens"):
-- ShyWay's (Shy.Way.KnowsFlight).
local function HasFlight(name)
	return Shy.Way.KnowsFlight(name)
end

-- Whether the flight a step asks for can be taken from its flight master (the step's place), as ShyWay's
-- journeys take flights (Shy.Way.CanFly): to a point the character knows, over points they know. nil where
-- that can't be told (ShyWay off, or no flight point of that name).
local function CanFly(step, name)
	local from
	for _, element in ipairs(step.elements) do
		local at = element.command == "goto" and Place(element)
		if at and at.continent and at.north then
			from = Shy.Way.Place(at.continent, at.north, at.west)
			break
		end
	end
	return Shy.Way.CanFly(from, name and strtrim(name))
end

-- Profession skill by the guides' name ("cooking", "firstaid"); -1 when not learned.
local function SkillLevel(name)
	local line = name and ns.data.routeInfo and ns.data.routeInfo.skills[name:lower()]
	local info = line and C_SkillInfo.GetSkillLineInfoByID(line)
	return info and info.rank or -1
end

-- ".collect item,count,quest,objectives,flags,...": have this many of an item.
--
--   quest        done once it is turned in or complete; with no objectives named, also once accepted
--   objectives   bitmask of the quest objectives the item is for
--   flags    1   show a count, never block
--            2   subtract what those objectives already count
--            4   done when those objectives are
--            8   count the bank
--           16   turning the quest in doesn't settle it
--           32   subtract profession skill: name, per point, from, at least
--           64   ask nothing while the player has none
--          128   over once the bags have held it since the quest was taken: it is used up on the
--                way (L.Had, which keeps that for an item the quest needs and doesn't count)
--   a negative flag: as 3, subtracting that many per objective count
--
-- Returns as Judge does and sets element.have / element.need.
local function Collect(element)
	local list = Args(element)
	local id = list[1] and tonumber(list[1]:match("^%d+"))
	if not id then return false end
	local need, quest = tonumber(list[2]) or 1, tonumber(list[3])
	local objectives, flags = tonumber(list[4]) or 0, tonumber(list[5]) or 0
	local per, profession = 1, nil
	if flags < 0 then per, profession, flags = -flags, list[6], 3 end
	local function Has(bit) return flags % (bit * 2) >= bit end
	if list[6] and Has(2) and per == 1 then per = tonumber(list[6]) or 1 end
	local from, least = 0, 0
	if Has(32) then profession, per, from, least = list[6], tonumber(list[7]) or 1, tonumber(list[8]) or 0, tonumber(list[9]) or 0 end

	local settled, counted = false, false
	if quest then
		if profession == "item" then
			need = math.max(0, need - C_Item.GetItemCount(from) * per)
		elseif profession then
			local skill = SkillLevel(profession)
			if skill >= 0 then need = math.max(0, need - math.max(0, skill - from) * per) end
		elseif Has(2) or Has(4) then
			local infos = C_QuestLog.GetQuestObjectives(quest) or {}
			local named, finished = 0, 0
			for i = 1, 8 do
				if objectives % (2 ^ i) >= 2 ^ (i - 1) then
					named = named + 1
					local info = infos[i]
					if info then
						if Has(2) then need = need - (info.numFulfilled or 0) * per end
						if info.finished then finished = finished + 1 end
					end
				end
			end
			-- counted: the quest has counted everything that was asked (flag 2).
			counted = Has(2) and named > 0 and need <= 0
			need = math.max(0, need)
			settled = not Has(2) and named > 0 and finished == named
		end
	end
	need = math.max(math.ceil(need), least)

	local count = C_Item.GetItemCount(id, Has(8))
	if count == 0 and Has(64) and (list[6] ~= nil or C_Item.GetItemCount(id, true) == 0) then need = 0 end
	if count < need and Has(128) and L.Had(id) then count = need end
	if quest and quest > 0 then
		local entry = L.entries[quest]
		if (objectives == 0 and entry ~= nil) or (not Has(16) and (settled or L.Done(quest) or (entry ~= nil and entry.complete))) then
			count = need
		end
	end
	element.have, element.need = math.min(count, need), need
	-- Nothing to ask is no task; but with every one counted by the quest the task is over, so that
	-- a step of this line alone is done and not left standing for a later step to wait on.
	if need <= 0 then
		if counted and not Has(1) then return true, true end
		return false
	end
	return true, count >= need, Has(1) and "soft" or nil
end

-- One-off events that can't be queried afterwards (latched).
local LATCH = {
	once = { fly = true, fp = true, hs = true, home = true },
	-- The same, but only a task when the line has text.
	onceIfSaid = { vendor = true, trainer = true },
	-- Commands whose state the client can always answer. A step with none of them is "soft" and is
	-- passed over once the player is clearly beyond it (see Scan).
	hard = { accept = true, turnin = true, complete = true, xp = true, collect = true, abandon = true, train = true, skill = true },
}

-- Passed to the checks in GuideChecks.lua; one table, refilled per call.
local env = {}

-- A quest that comes in several versions, one from each town, can be only a walk to who gives another of them:
-- Divine Grace from Goldshire is "Speak to Laurena in Stormwind", and Laurena gives her own. Taking the walk is
-- worth it only from nearer its giver. Nearer her, its step is passed over, and hers is taken in its own step.
-- Only where this guide has a step for her version that applies to you: the quest is never left out.
local Walk = { quests = {} }

-- What a quest is a walk to: { to = the NPC it ends with, from = { NPCs who give it }, other = the version that
-- NPC gives }, or false. A walk: nothing to do in it but go, and taking it shuts out the other.
function Walk.Of(quest)
	local known = Walk.quests[quest]
	if known ~= nil then return known end
	known = false
	local q = D.Quest(quest)
	if q and q.exclusive and #q.goals == 0 and #q.trigger == 0 then
		local ends, from = {}, {}
		for _, token in ipairs(q.ends) do
			if token.kind == "n" then ends[token.id] = true end
		end
		for _, token in ipairs(q.starts) do
			if token.kind == "n" then from[#from + 1] = token.id end
		end
		for _, other in ipairs(q.exclusive) do
			local o = D.Quest(other)
			for _, token in ipairs(o and o.starts or NONE) do
				if not known and token.kind == "n" and ends[token.id] and #from > 0 then
					known = { to = token.id, from = from, other = other }
				end
			end
		end
	end
	Walk.quests[quest] = known
	return known
end

-- The steps of a guide that take each quest, read once off its raw steps (not parsed: a guide is thousands).
function Walk.Takes(guide, quest)
	local at = guide.takesAt
	if not at then
		at = {}
		for index, raw in ipairs(guide.raw) do
			if type(raw) == "string" then
				for digits in raw:gmatch('type="accept",quest=(%d+)') do
					local id = tonumber(digits)
					at[id] = at[id] or {}
					table.insert(at[id], index)
				end
			end
		end
		guide.takesAt = at
	end
	return at[quest] or NONE
end

-- Yards from you to the nearest place of an NPC on your continent; nil where none is, or yours isn't known.
function Walk.Yards(npc)
	if not (W.continent and W.north) then return nil end
	local record = D.Npc(npc)
	local least
	for _, place in ipairs(record and record.places or NONE) do
		if not place.dungeon then
			for i = 1, #place.points - 1, 2 do
				local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
				if continent == W.continent and north then
					local yards = W.Between(W.north, W.west, north, west)
					if not least or yards < least then least = yards end
				end
			end
		end
	end
	return least
end

-- A step that runs alongside the guide's own (sticky, or beside another).
function Walk.Beside(step)
	for _, tag in ipairs(step.tags) do
		if tag.name == "sticky" or tag.name == "completewith" then return true end
	end
	return false
end

-- Whether a quest's step (at `index`) is to be passed over now: a walk, with its other version taken in a step of
-- this guide that applies to you and is still to come (after it, or alongside), and you nearer who gives that than
-- who gives the walk.
function Walk.Skip(guide, quest, index)
	local walk = Walk.Of(quest)
	if not walk then return false end
	local mine = false
	for _, at in ipairs(Walk.Takes(guide, walk.other)) do
		local step = Step(guide, at)
		if step and Wanted(step) and (at > index or Walk.Beside(step)) then
			mine = true
			break
		end
	end
	if not mine then return false end
	local there = Walk.Yards(walk.to)
	if not there then return false end
	for _, giver in ipairs(walk.from) do
		local here = Walk.Yards(giver)
		if here and here <= there then return false end
	end
	return true
end

-- Judges one element. Returns "skip" (the step doesn't apply), "done" (the step is over), or
-- isTask, isDone.
local function Judge(guide, step, number, element, latched)
	local command, args = element.command, element.args
	local ids = Ids(element)
	local id = ids[1]

	if command == "accept" then
		-- ".accept 731,2,729": not available until quest 729 is turned in.
		local list = Args(element)
		local needs = (tonumber(list[2]) or 0) % 4 >= 2 and tonumber(list[3]) or nil
		-- L.Holds is false for a failed quest, so it reads as still to accept.
		local done = id ~= nil and (L.Holds(id) or L.Done(id) or (needs ~= nil and not L.Done(needs)))
		-- A class quest is taken from its own row, at the nearest giver (ClassQuests.lua): the step is no stop.
		if id and not done and ns.ClassQuests and ns.ClassQuests.Takes(id) then return true, true end
		-- A walk to who gives her own version, and you nearer her (Walk).
		if id and not done and Walk.Skip(guide, id, step.index) then return "skip" end
		return true, done
	elseif command == "turnin" then
		if element.held and id then
			-- ".turnin -414": done without the quest. ".turnin -414,2": also until it is complete.
			local entry = L.entries[id]
			if not entry or ((tonumber(Args(element)[2]) or 0) > 0 and not entry.complete) then return true, true end
		end
		return true, id ~= nil and L.Done(id)
	elseif command == "complete" then
		local list = Args(element)
		local done = id ~= nil and (ObjectiveDone(id, Objective(element), tonumber(list[3])) or (element.held == true and not L.Has(id)))
		-- An odd fourth argument makes it a check: skip once the objective is done.
		if (tonumber(list[4]) or 0) % 2 == 1 then
			if done then return "skip" end
			return false
		end
		return true, done
	elseif command == "+" then
		-- A manual task: only the player can tick it off.
		return true, false
	elseif command == "xp" then
		local spec, flag = args:match("^([^,]*),?%s*(%-?%d*)")
		local reverse = spec:find("<", 1, true) ~= nil or (tonumber(flag) or 0) < 0
		local met = Reached(spec) == not reverse
		if flag ~= "" then
			if met then return "skip" end
			return false
		end
		return true, met
	elseif command == "maxlevel" then
		if id and L.Level() > id then return "skip" end
	elseif command == "isOnQuest" then
		if not OnAny(ids) then return "skip" end
	elseif command == "isNotOnQuest" then
		if OnAny(ids) then return "skip" end
	elseif command == "isQuestComplete" then
		local entry = id and L.entries[id]
		if not (entry and entry.complete) then return "skip" end
	elseif command == "isQuestNotComplete" then
		local entry = id and L.entries[id]
		if entry and entry.complete then return "skip" end
	elseif command == "isQuestTurnedIn" then
		if not AnyDone(ids) then return "skip" end
	elseif command == "isQuestAvailable" then
		local open = false
		for _, quest in ipairs(ids) do
			if not L.Done(quest) then open = true end
		end
		if not open then return "skip" end
	elseif command == "zoneskip" then
		-- ".zoneskip Durotar": skip while there. ",1": skip unless there. Several zones: "A+B".
		local list = Args(element)
		if W.map then
			local inside = false
			for zone in (list[1] or ""):gmatch("[^%+/]+") do
				if InZone(zone) then inside = true end
			end
			if inside == ((tonumber(list[2]) or 0) % 2 == 0) then return "skip" end
		end
	elseif command == "itemcount" then
		-- ".itemcount 159,<20": applies only with fewer than 20. No sign: at least that many.
		local list = Args(element)
		local op, eq, total = (list[2] or ""):match("([<>]?)(=?)%s*(%d+)")
		total = tonumber(total)
		if id and total then
			local count = C_Item.GetItemCount(id, list[3] ~= nil)
			local ok = (eq == "=" and count == total) or (op == "<" and count < total) or (op == ">" and count > total)
				or (eq == "" and op == "" and count >= total)
			if not ok then return "skip" end
		end
	elseif command == "collect" then
		return Collect(element)
	elseif command == "goto" then
		local at = Place(element)
		-- Only a place with a radius is a task. With BARE, standing there counts, so Back doesn't
		-- land on a travel step that completes again at once.
		if at and at.task then return true, latched[number] == true or (latched == BARE and Arrived(at)) end
	elseif command == "zone" then
		if InZone(args) then return "done" end
		return true, false
	elseif command == "subzone" then
		-- ",1": done once out of it. ",2": only where there is no map.
		local flags = tonumber(Args(element)[2]) or 0
		return true, InArea(id, flags % 4 >= 2) == (flags % 2 == 0)
	elseif command == "bindlocation" then
		local area = id and C_Map.GetAreaInfo(id)
		local bound = area ~= nil and area == GetBindLocation()
		if (tonumber(Args(element)[2]) or 0) % 2 == 1 then
			-- ",1": applies only when the hearthstone is set there.
			if not bound then return "skip" end
			return false
		end
		if bound then return "done" end
		return true, false
	elseif command == "abandon" then
		return true, not OnAny(ids)
	elseif command == "train" then
		if id then
			-- ",1": a check: skip once the spell is known. ",2": inverted.
			local flags = tonumber(Args(element)[2]) or 0
			local met = C_SpellBook.IsSpellKnown(id) ~= (flags % 4 >= 2)
			if flags % 2 == 1 then
				if met then return "skip" end
				return false
			end
			return true, met
		end
	elseif command == "fp" then
		-- Flight points are the route's to send for (Flights.lua): with it, never a step to wait on.
		return true, latched[number] == true or ns.Flights ~= nil or HasFlight(Args(element)[1])
	elseif command == "fly" and latched[number] ~= true and CanFly(step, Args(element)[1]) == false then
		-- A flight the character can't take (a point they don't have yet) is never a step to wait on: the
		-- way on is the route's, by the ways they have, and the flight point Flights.lua's to send for.
		return true, true, "grounded"
	elseif LATCH.once[command] then
		-- A .bindlocation in the step answers for .home.
		if command == "home" and Shape(step).binds then return false end
		-- When to use the stone, and where to set it, is the route's to say (Hearth.lua): with it,
		-- never a step to wait on.
		if (command == "hs" or command == "home") and ns.Hearth ~= nil and T.db.hearth and T.db.hearth.on then return true, true end
		return true, latched[number] == true
	elseif LATCH.onceIfSaid[command] and element.text then
		return true, latched[number] == true
	else
		local check = G.checks[command]
		if check then
			env.guide, env.step, env.number, env.latched, env.bare = guide, step, number, latched, latched == BARE
			return check(element, env)
		end
	end
	return false
end

-- Evaluates a step. Returns state, parts, total, hard, where parts[i] = { element, number, can,
-- done, dropped = step whose skip dropped its quest, soft = shown but not blocking, parent =
-- its task's element number } and parts.of[n] is the part for element n. States:
--   "skip"      doesn't apply to this player right now
--   "done"      by live state, or ticked off by the player
--   "skipped"   skipped by the player, or its quest was dropped and nothing else is left
--   "todo"
-- `bare`: live state only, ignoring ticks and latches.
local function Evaluate(guide, step, bare)
	local saved = Saved(guide)
	local index = step.index
	local latched = bare and BARE or saved.latched[index] or NOTHING
	local shape = Shape(step)
	local parts, total, finished, hard, said, dropped, over = { of = {} }, 0, 0, false, false, false, false
	for number, element in ipairs(step.elements) do
		if not element.cond or Applies(element.cond) then
			local by = Dropped(saved, element, index, guide)
			local part
			if by then
				dropped = true
				part = { element = element, number = number, can = false, done = false, dropped = by }
			else
				local can, done, how = Judge(guide, step, number, element, latched)
				if can == "skip" then return "skip", parts end
				if can == "done" then can, done, over = true, true, true end
				local soft = can and (shape.soft[number] or how == "soft") or false
				if can and not soft then
					total = total + 1
					if done then finished = finished + 1 end
					if LATCH.hard[element.command] then hard = true end
				end
				if can or element.text then said = true end
				part = { element = element, number = number, can = can and not soft, done = done and true or false,
					soft = soft or nil, parent = shape.parent[number], grounded = how == "grounded" or nil }
			end
			parts[#parts + 1] = part
			parts.of[number] = part
		end
	end
	if dropped and total == 0 then return "skipped", parts, 0, false end
	-- No task and no text (a bare label).
	if not said then return "skip", parts end
	-- Live state outranks a skip.
	if over or (total > 0 and finished == total) then return "done", parts, total, hard end
	local tick = not bare and saved.done[index]
	if tick == "skip" then return "skipped", parts, total, hard end
	if tick then return "done", parts, total, hard end
	return "todo", parts, total, hard
end

-- Choosing a guide

-- A guide this character could follow: the picker lists these, a careful route (the safer one) among them.
local function Listed(guide)
	return not guide.internal and AppliesAll(guide.cond) and (not guide.xprate or RateFits(guide.xprate))
end

-- ... and one picked for them unasked: a careful route only on the hardcore route.
local function Usable(guide)
	return Listed(guide) and (not guide.careful or T.db.guide.hardcore == true)
end

-- The guide a "next" names: in the same group, else any usable guide of that name.
local function Linked(guide, name)
	local found = byName[guide.group .. "\\" .. name]
	if found then return found end
	for _, other in ipairs(guides) do
		if other.name == name and other ~= guide and Usable(other) then return other end
	end
end

-- The map a guide's first step stands on.
local function FirstMap(guide)
	local raw = guide.raw[1]
	if type(raw) == "string" then return tonumber(raw:match("map=(%d+)")) end
	return type(raw) == "table" and type(raw.at) == "table" and tonumber(raw.at.map) or nil
end

-- Where a new character began, noted once at level 1: a race may start in another race's starting zone (the
-- character creation's choice of zone; Zephras Isle's quests are anyone's). Standing at level 1 in a world of its
-- own (not the Eastern Kingdoms or Kalimdor: nobody walks there), on the map where a starting guide of the
-- faction begins and none of its own race's, the character takes that guide's race as its home (facts.home):
-- those guides are its guides. Its own race's guides are the fallback.
local MAINLAND = { [0] = true, [1] = true }
function G.Began()
	if not ns.char or ns.char.began ~= nil or L.Level() > 1 or not W.Known() or not W.map or not guides then return end
	if MAINLAND[W.continent] then
		ns.char.began = false
		return
	end
	if not facts then ReadFacts() end
	local here = W.MapName(W.map)
	local own, other
	for _, guide in ipairs(guides) do
		local first = guide.default and guide.default ~= "" and not guide.careful and FirstMap(guide)
		if first and (first == W.map or (here and W.MapName(first) == here)) then
			if Applies(guide.default) then own = guide else other = other or guide end
		end
	end
	local home = false
	if not own and other then
		local alternative = other.default:match("^[^/]+")
		if alternative:find(facts.faction, 1, true) then
			for word in alternative:gmatch("%w+") do
				if word ~= facts.faction then
					home = word
					break
				end
			end
		end
	end
	ns.char.began = home
	if home then
		ReadFacts()
		ForgetApplies()
		G.chain = nil
	end
end

-- This character's guides in order: the default starting guide, then each "next".
function G.Chain()
	if G.chain then return G.chain end
	if not facts then ReadFacts() end
	G.Began()
	local chain, seen = {}, {}
	local start, rank
	for _, guide in ipairs(guides) do
		-- AoE routes are opt-in, never a starting guide.
		if Usable(guide) and guide.default and Applies(guide.default) and not guide.name:find("AoE", 1, true) and not guide.careful then
			-- Where the character began comes before its race's own start.
			local this = guide.low + ((facts.home and not guide.default:find(facts.home, 1, true)) and 1000 or 0)
			if not start or this < rank then start, rank = guide, this end
		end
	end
	local guide = start
	while guide and not seen[guide] do
		seen[guide] = true
		chain[#chain + 1] = guide
		local following
		for _, link in ipairs(guide.next) do
			local candidate = Linked(guide, link.name)
			if candidate and Usable(candidate) and (not link.cond or Applies(link.cond)) then
				following = candidate
				break
			end
		end
		guide = following
	end
	-- Not kept while where the character began is still to be noted (the map isn't known yet at login).
	if not ns.char or ns.char.began ~= nil or L.Level() > 1 then G.chain = chain end
	return chain
end

-- Fraction and count of a guide's quests this character has started. `given`: quests an earlier
-- guide gives, which say nothing of this one; this guide's are added to it.
local function Started(guide, given)
	local begun, all = 0, 0
	local own = {}
	for index = 1, #guide.raw do
		local step = Step(guide, index)
		if Wanted(step) then
			for _, element in ipairs(step.elements) do
				if element.command == "accept" and (not element.cond or Applies(element.cond)) then
					local id = tonumber(element.args:match("%d+"))
					if id and not given[id] then
						own[id] = true
						all = all + 1
						if L.Has(id) or L.Done(id) then begun = begun + 1 end
					end
				end
			end
		end
	end
	for id in pairs(own) do given[id] = true end
	return all > 0 and begun / all or 0, begun
end

-- Where to join a guide: after the last done quest step that has done steps around it (one
-- stray quest done far ahead doesn't count). Only the guide's own quests say where: a turn-in
-- of a quest an earlier guide gave was done there, however far on this guide puts it. Nor does a
-- quest an earlier guide of the chain takes as well (a guide several chains join has quests some of
-- them did on the way): taken and done there, it says nothing of how far along this one is, and the
-- quests of this guide's own still to do before it would be passed by.
local function Frontier(guide)
	local recent, frontier = {}, 0
	local given = Asks(guide).accept
	local earlier, before = {}, {}
	for _, each in ipairs(G.Chain()) do
		if each == guide then
			earlier = before
			break
		end
		for id in pairs(Asks(each).accept) do before[id] = true end
	end
	for index = 1, #guide.raw do
		local step = Step(guide, index)
		if Wanted(step) then
			local quest = false
			for _, element in ipairs(step.elements) do
				local command = element.command
				local id = Ids(element)[1]
				if command == "accept" then
					if not (id and earlier[id]) then quest = true end
				elseif command == "turnin" or command == "complete" then
					if id and given[id] and not earlier[id] then quest = true end
				end
			end
			if quest then
				local state = Evaluate(guide, step)
				if state == "done" or state == "todo" then
					local done = state == "done"
					local around = 0
					for _, was in ipairs(recent) do
						if was then around = around + 1 end
					end
					if done and (#recent < 3 or around * 2 >= #recent) then frontier = index end
					recent[#recent + 1] = done
					if #recent > 6 then table.remove(recent, 1) end
				end
			end
		end
	end
	return frontier
end

-- The last guide in the chain with a fair share of its quests started, else the one for the level.
local function Detect()
	local chain = G.Chain()
	local pick
	local given = {}
	for _, guide in ipairs(chain) do
		local share, begun = Started(guide, given)
		if begun >= 2 and share >= 0.25 then pick = guide end
	end
	if not pick then
		local level = L.Level()
		for _, guide in ipairs(chain) do
			if guide.high + 1 >= level then
				pick = guide
				break
			end
		end
	end
	return pick
end

-- Makes a guide current, resuming its saved place or starting at the Frontier.
local function Select(guide, picked)
	local state = ns.char.guide
	state.key = guide and Key(guide) or nil
	state.picked = picked or nil
	if guide then
		local saved = Saved(guide)
		if saved.start == nil then saved.start = Frontier(guide) + 1 end
	end
	-- Clear the old guide's live steps so nothing is latched against the new one before Refresh.
	if guide ~= G.current then G.active = {} end
	G.current = guide
end

-- The first "next" that fits.
local function Following(guide)
	for _, link in ipairs(guide.next) do
		local candidate = Linked(guide, link.name)
		if candidate and Usable(candidate) and (not link.cond or Applies(link.cond)) then return candidate end
	end
end

-- The guide whose "next" is this one, when there is only one.
local function Prior(guide)
	local found
	for _, other in ipairs(guides) do
		if Following(other) == guide then
			if found then return nil end
			found = other
		end
	end
	return found
end

-- Live steps

-- { step, parts, side = runs beside the main step, manual = only the player can tick it off,
--   ghosts = hidden steps lending their waypoints }
G.active = {}
G.waiting = nil    -- the main step, while it waits for a side step it requires
G.behind = {}      -- earlier steps that go before the place (First, Catchup); the first leads
G.offered = {}     -- catch-up steps that are off the way: marked on the map only

local function Tag(step, name)
	for _, tag in ipairs(step.tags) do
		if tag.name == name and (not tag.cond or Applies(tag.cond)) then return tag.value end
	end
end

local function Side(step)
	return Tag(step, "completewith") ~= nil or Tag(step, "sticky") ~= nil
end

local function Main()
	for _, entry in ipairs(G.active) do
		if not entry.side then return entry end
	end
	return G.waiting
end

-- The step the place is at: the main one, or the one waiting behind a side step.
local function Head()
	return Main() or G.waiting
end

-- True when everything still open is a manual task.
local function Manual(parts)
	for _, part in ipairs(parts) do
		if part.can and not part.done and part.element.command ~= "+" then return false end
	end
	return true
end

-- with = "next": the next step that applies to this character.
local function NextWanted(guide, index)
	for later = index + 1, #guide.raw do
		if Wanted(Step(guide, later)) then return later end
	end
	return index + 1
end

-- ".maxlevel 14,endOfTheGuide": past that level, jump to the label. Returns the target index, if any.
local function Leap(guide, step, labels)
	for _, element in ipairs(step.elements) do
		if element.command == "maxlevel" and (not element.cond or Applies(element.cond)) then
			local list = Args(element)
			local level, to = tonumber(list[1] and list[1]:match("%d+")), list[2] and labels[list[2]]
			if level and to and to > step.index and L.Level() > level then return to end
		end
	end
end

-- Waypoints

-- A step's places in order, each { at, part, passed, quiet = its task is done }. Leads() picks
-- the current one: the first not passed or quiet, the nearest of "nearest" ones, last resorts last.
local function Ways(parts, latched, into)
	local list = into or {}
	local first = #list + 1
	for _, part in ipairs(parts) do
		local command = part.element.command
		if (command == "goto" or command == "waypoint") and not part.dropped then
			local at = Place(part.element)
			if at then
				local owner = part.parent and parts.of[part.parent]
				local passed
				if at.task then passed = part.done else passed = at.reach ~= nil and latched[part.number] == true end
				list[#list + 1] = { at = at, part = part, passed = passed,
					quiet = owner ~= nil and (owner.done or owner.dropped ~= nil) or false }
			end
		end
	end
	return list, first
end

local function Leads(list)
	local nearest, least
	if W.Known() then
		for _, way in ipairs(list) do
			local at = way.at
			if at.nearest and at.arrow and not way.quiet and at.north and at.continent == W.continent then
				local yards = W.Between(W.north, W.west, at.north, at.west)
				if not least or yards < least then nearest, least = way, yards end
			end
		end
	end
	local resort
	for _, way in ipairs(list) do
		local at = way.at
		if at.arrow and not way.quiet and not way.passed then
			if at.low or (at.nearest and nearest and way ~= nearest) then
				resort = resort or way
			else
				return way
			end
		end
	end
	return resort
end

-- Prerequisite steps
-- Undone steps behind the place are normally left behind. But when a step just ahead needs one
-- (an objective of a quest never accepted, or a quest locked behind another's turn-in), the
-- earliest such step is shown first. Nothing before saved.left ("Carry on from here") is fetched.

local LOOK = {
	ahead = 12,  -- todo steps from the place on whose needs are checked
	reach = 80,  -- ... within this many steps
	guides = 4,  -- earlier guides in the chain WorkOnQuest searches
	lent = 40,   -- ... and Lent, for a quest an earlier guide took that you skipped: the whole chain back
	-- A needed step that doesn't apply yet (it waits on a skill, say) is unlocked by the step just
	-- before it: returns the nearest earlier step that live state says is still todo, clearing its tick.
	gate = 3,  -- applicable steps looked back over
}

-- True when the quest is in the log and still needs objectives before turn-in.
local function QuestOpen(id)
	if not id or not L.Has(id) or L.Done(id) or C_QuestLog.IsComplete(id) then return false end
	local entry = L.entries[id]
	return entry ~= nil and not entry.complete and not entry.failed
end

-- In the log, objectives done, not yet turned in.
local function ReadyHand(id)
	if not id or not L.Has(id) or L.Done(id) then return false end
	local entry = L.entries[id]
	return entry ~= nil and entry.complete and not entry.failed
end

-- A step put before the place: a catch-up (`catch` says why), or an earlier step a later one can't do
-- without (`needed`: the quest the later step is about; nil for a gate, the step just before the one
-- that waits on it).
local function InsertBefore(step, parts, catch, needed)
	return { step = step, parts = parts, manual = Manual(parts), first = true, catch = catch, needed = needed }
end

-- Appends to `found`, as { step, quest }, the steps before `limit` a quest needs first.
--   want "have"   the quest must be in the log
--   want "hand"   it must be ready to turn in
--   want "done"   it must be turned in
--   want "open"   it must be available
-- (The steps of `steps` before `limit`, from `left` on unless `anywhere`, into `found`: no function made a call.)
local function RootsAdd(found, steps, limit, left, quest, anywhere)
	for _, index in ipairs(steps or NOTHING) do
		if index < limit and (anywhere or index >= left) then found[#found + 1] = { index, quest } end
	end
end
local function Roots(guide, quest, limit, found, want, depth)
	if depth > CHAIN or L.Done(quest) then return end
	local asks = Asks(guide)
	local left = Saved(guide).left or 1
	local data = D.Quest(quest)
	if want == "done" or want == "hand" then
		-- Its unfinished objectives and collects.
		local entry = L.entries[quest]
		if entry and not entry.complete then RootsAdd(found, asks.complete[quest], limit, left, quest) end
		RootsAdd(found, asks.collect[quest], limit, left, quest)
		if want == "done" then RootsAdd(found, asks.turnin[quest], limit, left, quest) end
	end
	if want ~= "open" and not L.Holds(quest) then
		if data and data.minLevel > L.Level() then return end
		-- A failed quest is fetched even from before saved.left.
		RootsAdd(found, asks.accept[quest], limit, left, quest, L.Failed(quest))
	end
	if L.Has(quest) or not data then return end
	-- Prerequisites: all of preGroup, any one of preSingle.
	for _, before in ipairs(data.preGroup or NOTHING) do
		Roots(guide, before, limit, found, "done", depth + 1)
	end
	local open = data.preSingle == nil
	for _, before in ipairs(data.preSingle or NOTHING) do
		if L.Done(before) then open = true end
	end
	if not open then
		for _, before in ipairs(data.preSingle) do
			Roots(guide, before, limit, found, "done", depth + 1)
		end
	end
end

local function Gate(guide, index)
	local saved = Saved(guide)
	local seen, behind = 0, index - 1
	while behind >= (saved.left or 1) and seen < LOOK.gate do
		local step = Step(guide, behind)
		if Wanted(step) and not Side(step) then
			seen = seen + 1
			local state, _, _, hard = Evaluate(guide, step, true)
			if state == "todo" and hard then
				if saved.done[behind] then saved.done[behind] = nil end
				local now, parts = Evaluate(guide, step)
				if now == "todo" then return InsertBefore(step, parts) end
			end
		end
		behind = behind - 1
	end
end

-- The guide's step that finishes `quest` in the log (this guide or an earlier one in the chain).
-- Collect may stand after its hand-in in the file, or only in the guide before this one.
-- `far`: how many guides back to look (LOOK.guides when not given).
local function WorkOnQuest(home, quest, far)
	if not QuestOpen(quest) then return nil end
	local best
	local function Try(which)
		if not which then return end
		local asks = Asks(which)
		local left = Saved(which).left or 1
		-- A quest already picked up is not hidden by "carry on from here" on an earlier guide.
		local heedLeft = not L.Has(quest)
		for _, command in ipairs({ "complete", "collect" }) do
			for _, index in ipairs(asks[command][quest] or NOTHING) do
				if not heedLeft or index >= left then
					local step = Step(which, index)
					if Wanted(step) and not Side(step) then
						local state, parts = Evaluate(which, step)
						if state == "todo" then
							for _, part in ipairs(parts) do
								local cmd = part.element.command
								local list = Ids(part.element)
								local about = cmd == "collect" and list[3] or list[1]
								if about == quest and part.can and not part.done and not part.dropped
									and (cmd == "complete" or cmd == "collect") then
									local pick = not best or index < best.step.index
										or (index == best.step.index and which == home and best.guide ~= home)
									if pick then
										best = { step = step, parts = parts, manual = Manual(parts),
											guide = which ~= home and which or nil }
									end
								end
							end
						end
					end
				end
			end
		end
	end
	Try(home)
	local back = home
	for _ = 1, far or LOOK.guides do
		back = Prior(back)
		if not back then break end
		Try(back)
	end
	return best
end

-- Finish what is in the log before the saved place: objectives for a quest whose hand-in this
-- guide already passed, or whose hand-in is the place itself but the quest is not ready.
local function CarriedWork(guide, at)
	local saved = Saved(guide)
	if saved.held[at] and saved.start == at then return nil end
	if saved.held[at] then
		local held = Step(guide, at)
		local state, parts = Evaluate(guide, held)
		if state == "todo" and W.Known() then
			local travel = true
			for _, part in ipairs(parts) do
				if part.can and not part.done and part.element.command ~= "+" and part.element.command ~= "" then
					local cmd = part.element.command
					if cmd ~= "zone" and cmd ~= "goto" and cmd ~= "subzone" and cmd ~= "fly" and cmd ~= "hs" and cmd ~= "fp" and cmd ~= "home" then
						travel = false
					end
				end
			end
			if travel then return nil end
		end
	end
	local function Work(id)
		return QuestOpen(id) and WorkOnQuest(guide, id) or nil
	end
	-- A quest the player has outgrown is the catch-up's to offer, never the route's to lead.
	local function Owed(id)
		local data = D.Quest(id)
		return not (data and L.Outgrown(data))
	end
	-- Hand-ins at or before `limit`, the latest first.
	local function HandIns(which, limit)
		local hand = {}
		for id, indices in pairs(Asks(which).turnin) do
			for _, index in ipairs(indices) do
				if (not limit or index <= limit) and Owed(id) then hand[#hand + 1] = { id = id, index = index } end
			end
		end
		table.sort(hand, function(a, b)
			if a.index ~= b.index then return a.index > b.index end
			return a.id < b.id
		end)
		return hand
	end
	local asks = Asks(guide)
	for _, entry in ipairs(L.order) do
		if entry.failed and Owed(entry.id) then
			for _, index in ipairs(asks.accept[entry.id] or NOTHING) do
				if index < at and saved.done[index] ~= "skip" then
					local accept = Step(guide, index)
					if Wanted(accept) then
						local state, parts = Evaluate(guide, accept)
						if state == "todo" then
							return { step = accept, parts = parts, manual = Manual(parts), first = true, catch = "carried" }
						end
					end
				end
			end
		end
	end
	local step = Step(guide, at)
	if Wanted(step) and not Side(step) then
		local state, parts = Evaluate(guide, step)
		if state == "todo" then
			for _, part in ipairs(parts) do
				if part.can and not part.done and part.element.command == "turnin" then
					local work = Work(Ids(part.element)[1])
					if work then return work end
				end
			end
		end
	end
	local hand = HandIns(guide, at)
	for _, each in ipairs(hand) do
		local work = Work(each.id)
		if work then return work end
	end
	for _, each in ipairs(hand) do
		if ReadyHand(each.id) then
			local handStep = Step(guide, each.index)
			if Wanted(handStep) and not Side(handStep) then
				local state, parts = Evaluate(guide, handStep)
				if state == "todo" then
					return { step = handStep, parts = parts, manual = Manual(parts) }
				end
			end
		end
	end
	-- Hand-in may live only in an earlier guide in the chain (objectives there, turn-in here).
	local back = guide
	for _ = 1, LOOK.guides do
		back = Prior(back)
		if not back then break end
		for _, each in ipairs(HandIns(back)) do
			local id = each.id
			if QuestOpen(id) then
				local work = Work(id)
				if work then return work end
			end
			if ReadyHand(id) then
				local handStep = Step(back, each.index)
				if Wanted(handStep) and not Side(handStep) then
					local state, parts = Evaluate(back, handStep)
					if state == "todo" then
						return { step = handStep, parts = parts, manual = Manual(parts), guide = back ~= guide and back or nil }
					end
				end
			end
		end
	end
end

-- The place (`at`) takes a quest that waits on one this guide has no step for. Claws from the Deep comes
-- before Reclaiming Goods (28-30), but only the 20-22 guide takes it. If you skipped that, its steps there
-- are the way: take it, do it, hand it in. Returns that guide's step as a live entry, or nil.
-- (Only the place: a step further on gets its turn. Whether a chain is worth going back for is ChainGone's.)
local function Lent(guide, at)
	local step = Step(guide, at)
	if not (step and Wanted(step) and not Side(step)) then return nil end
	local state, parts = Evaluate(guide, step)
	if state ~= "todo" then return nil end
	local asks = Asks(guide)
	for _, part in ipairs(parts) do
		local id = part.element.command == "accept" and not part.done and not part.dropped and Ids(part.element)[1]
		local data = id and not L.Has(id) and D.Quest(id)
		local quest = data and L.Before(data)
		for _ = 1, CHAIN do
			-- (A quest this guide takes itself is First's.)
			if not quest or asks.accept[quest] or asks.turnin[quest] then break end
			local before = D.Quest(quest)
			if not before then break end
			local work = WorkOnQuest(guide, quest, LOOK.lent)
			if work then return work end
			local command = (L.Has(quest) and "turnin") or (Startable(before, guide) and "accept") or nil
			if command then
				local back = guide
				for _ = 1, LOOK.lent do
					back = Prior(back)
					if not back then break end
					for _, index in ipairs(Asks(back)[command][quest] or NOTHING) do
						local lent = Step(back, index)
						if Wanted(lent) and not Side(lent) then
							local now, theirs = Evaluate(back, lent)
							if now == "todo" then
								-- Only that quest's parts stay.
								for _, other in ipairs(theirs) do
									local about = QUEST[other.element.command] and Ids(other.element)[1]
									if about and about ~= quest then other.dropped, other.can, other.done = ABSENT, false, false end
								end
								local entry = InsertBefore(lent, theirs, nil, quest)
								entry.guide = back
								return entry
							end
						end
					end
				end
				break
			end
			quest = L.Before(before)
		end
	end
end

-- The prerequisite step to do before the place (`at`), as a live entry, or nil.
local function First(guide, at)
	local found = {}
	local seen, index = 0, at
	while index <= #guide.raw and index < at + LOOK.reach and seen < LOOK.ahead do
		local step = Step(guide, index)
		if Wanted(step) and not Side(step) then
			local state, parts = Evaluate(guide, step)
			if state == "todo" then
				seen = seen + 1
				for _, part in ipairs(parts) do
					local command = part.element.command
					-- Includes parts that can't be done yet: those are what need a prerequisite.
					local quest = QUEST[command] and not part.done and not part.dropped and Ids(part.element)[1]
					if quest then
						Roots(guide, quest, at, found, command == "accept" and "open" or command == "turnin" and "hand" or "have", 1)
					end
				end
			end
		end
		index = index + 1
	end
	table.sort(found, function(a, b) return a[1] < b[1] end)
	local saved = Saved(guide)
	for _, behind in ipairs(found) do
		local step = Step(guide, behind[1])
		if Wanted(step) and not Side(step) then
			local state, parts = Evaluate(guide, step)
			-- The accept step of a quest that has since failed: drop its tick.
			if state == "done" and saved.done[behind[1]] == true and L.Failed(behind[2]) and Evaluate(guide, step, true) == "todo" then
				saved.done[behind[1]] = nil
				state, parts = Evaluate(guide, step)
			end
			if state == "todo" then
				-- It must be todo because of that quest, not something else in the step.
				for _, part in ipairs(parts) do
					local list = Ids(part.element)
					local about = QUEST[part.element.command] and list[1] or part.element.command == "collect" and list[3]
					if about == behind[2] and not part.done and not part.dropped then
						if part.element.command == "turnin" then
							local entry = L.entries[behind[2]]
							if entry and not entry.complete then
								local work = WorkOnQuest(guide, behind[2])
								if work then return work end
								break
							end
							-- Ready to hand in: part of the quest line, not a skippable side quest.
							return { step = step, parts = parts, manual = Manual(parts) }
						elseif part.element.command == "accept" then
							local data = D.Quest(behind[2])
							if data and not Startable(data, guide) then break end
						end
						return InsertBefore(step, parts, nil, behind[2])
					end
				end
			elseif state == "skip" then
				local gate = Gate(guide, behind[1])
				if gate then return gate end
			end
		end
	end
	return Lent(guide, at)
end

-- A dungeon's step behind the place, still to do: one that came in after the guide passed its steps
-- (ticked, or reached at your level). It leads from there, and the place stays where it was.
local function DetourBehind(guide, at)
	if guide.far == nil then FarDetours(guide) end
	local saved = Saved(guide)
	local from = math.max(saved.start or 1, saved.left or 1)
	for _, index in ipairs(guide.detours or NOTHING) do
		if index >= at then return nil end
		local step = Step(guide, index)
		if index >= from and Wanted(step) and not Side(step) then
			local state, parts = Evaluate(guide, step)
			if state == "todo" then return InsertBefore(step, parts, "dungeon") end
		end
	end
end

-- What must lead before the saved place: finish open quests in the log, then optional inserts, then a
-- dungeon's steps left behind.
local function LeadBefore(guide, at)
	return CarriedWork(guide, at) or First(guide, at) or DetourBehind(guide, at)
end

-- Catch-up
-- Steps behind the place that are still worth doing, each for a reason:
--   carried   objectives or turn-in of a quest still in the log (unless outgrown)
--   ahead     something a later step, in this guide or the next few, can't do without
--   easy      a quest wholly before the place that is still available and worth the walk
-- One that is near and on the way goes before the place (the card leads with it); any other
-- within CATCH.far is only offered on the map. Skipped steps, quests with a skipped step,
-- steps before saved.left and other continents are excluded.
local CATCH = {
	reach = 1000,  -- yards: a step this near can be on the way...
	extra = 400,  -- ...if nearer than the guide's step, or adding no more than this to the walk
	near = 500,  -- ...or this near, when the guide's step has no position
	far = 5000,  -- yards within which an off-the-way step is offered on the map
	most = 12,  -- most steps offered
	stay = 1.3,  -- hysteresis for a step that was on the way
	rank = { carried = 1, ahead = 2, easy = 3 },
}
local LOOSE = { "complete", "collect", "turnin" }   -- commands that act on a carried quest
local caught = {}            -- step indexes that were on the way last time

-- Returns the quest a part is about, and whether it can be acted on now.
local function About(part, guide)
	local command = part.element.command
	local list = Ids(part.element)
	if command == "accept" then
		local quest = list[1]
		local data = quest and D.Quest(quest)
		return quest, quest ~= nil and not L.Holds(quest) and not L.Done(quest)
			and (data == nil or Startable(data, guide))
	end
	local quest = (command == "complete" or command == "turnin") and list[1] or command == "collect" and list[3]
	if quest and quest > 0 then
		-- A turn-in only counts once the quest is complete.
		local entry = L.entries[quest]
		return quest, entry ~= nil and not entry.failed and (command ~= "turnin" or entry.complete)
	end
end

-- Catch-up candidates before `at`: step -> { quest -> why }.
local function Behind(guide, at)
	local saved, asks = Saved(guide), Asks(guide)
	local left = saved.left or 1
	local wanted = {}
	local function Want(index, quest, why)
		if index >= at or index < left then return end
		local quests = wanted[index]
		if not quests then
			quests = {}
			wanted[index] = quests
		end
		if not quests[quest] or CATCH.rank[why] < CATCH.rank[quests[quest]] then quests[quest] = why end
	end
	-- Carried, less the quests of skipped steps.
	local gone = {}
	for index, tick in pairs(saved.done) do
		local skipped = tick == "skip" and type(index) == "number" and index < at and Step(guide, index)
		if skipped then
			for _, element in ipairs(skipped.elements) do
				local list = Ids(element)
				local quest = element.command ~= "accept" and asks[element.command] and list[element.command == "collect" and 3 or 1]
				if quest then gone[quest] = true end
			end
		end
	end
	for _, entry in ipairs(L.order) do
		local data = D.Quest(entry.id)
		if not gone[entry.id] and not (data and L.Outgrown(data)) then
			for _, command in ipairs(LOOSE) do
				for _, index in ipairs(asks[command][entry.id] or NOTHING) do
					-- Open quests are led by LeadBefore; don't offer their hand-in as optional catch-up.
					if command ~= "turnin" or not QuestOpen(entry.id) then
						Want(index, entry.id, "carried")
					end
				end
			end
			-- A failed quest: its accept step.
			for _, index in ipairs(entry.failed and asks.accept[entry.id] or NOTHING) do Want(index, entry.id, "carried") end
		end
	end
	-- Ahead: prerequisites (Roots) of every step from the place on. Each found step keeps what the
	-- search it came from wanted (found[k][3]).
	local found = {}
	local function Later(list, want)
		for quest, steps in pairs(list) do
			if steps[#steps] >= at and not L.Done(quest) and Wanted(Step(guide, steps[#steps])) then
				local from = #found
				Roots(guide, quest, at, found, want, 1)
				for k = from + 1, #found do found[k][3] = want end
			end
		end
	end
	Later(asks.accept, "open")
	Later(asks.complete, "have")
	Later(asks.collect, "have")
	Later(asks.turnin, "hand")
	local after, seen = Following(guide), 0
	while after and seen < 3 do
		local theirs = Asks(after)
		for _, list in ipairs({ theirs.complete, theirs.collect, theirs.turnin }) do
			for quest in pairs(list) do
				if not theirs.accept[quest] and not L.Done(quest) then Roots(guide, quest, at, found, "have", 1) end
			end
		end
		after, seen = Following(after), seen + 1
	end
	for _, each in ipairs(found) do
		-- (What a quest to take ahead needs first is offered only where it can be started now.)
		local data = D.Quest(each[2])
		if not (each[3] == "open" and data and not L.Has(each[2]) and not Startable(data, guide)) then
			Want(each[1], each[2], "ahead")
		end
	end
	-- Easy: quests whose steps all lie before the place.
	for quest, steps in pairs(asks.accept) do
		if steps[#steps] < at and not L.Has(quest) and not L.Done(quest) and not saved.dropped[quest] then
			local data = D.Quest(quest)
			if data and Startable(data, guide) and not L.Outgrown(data) and ns.Route.WorthOffer(data) then
				for _, index in ipairs(steps) do Want(index, quest, "easy") end
			end
		end
	end
	return wanted
end

-- Returns the entries that go before the place (`main`), in guide order, and the ones only
-- offered, nearest first. `needed`: the step First found, which always leads.
local function Catchup(guide, main, needed)
	local onWay, offered, now = {}, {}, {}
	if needed then onWay[1] = needed end
	if not W.Known() then
		caught = now
		return onWay, offered
	end
	local at = main.step.index
	local wanted = Behind(guide, at)
	local order = {}
	for index in pairs(wanted) do order[#order + 1] = index end
	table.sort(order)
	local lead = G.Describe(guide, main.step, main.parts)
	local leadYards = lead.north and lead.continent == W.continent and W.Between(W.north, W.west, lead.north, lead.west) or nil
	for _, index in ipairs(order) do
		local step = Step(guide, index)
		if not (needed and needed.step.index == index) and Wanted(step) and not Side(step) then
			local state, parts = Evaluate(guide, step)
			local why
			for _, part in ipairs(state == "todo" and parts or NOTHING) do
				local quest, open = About(part, guide)
				local reason = quest and open and part.can and not part.done and not part.dropped and wanted[index][quest]
				if reason and (not why or CATCH.rank[reason] < CATCH.rank[why]) then why = reason end
			end
			if why then
				-- Only the caught-up quest's parts stay; the step's other quest parts are dropped.
				for _, part in ipairs(parts) do
					local quest, open = About(part, guide)
					if quest and not part.dropped and not (open and wanted[index][quest]) then
						part.dropped, part.can, part.done = ABSENT, false, false
					end
				end
				local view = G.Describe(guide, step, parts)
				if view.north and view.continent == W.continent then
					local yards = W.Between(W.north, W.west, view.north, view.west)
					local hold = caught[index] and CATCH.stay or 1
					local near
					if leadYards then
						near = yards <= CATCH.reach * hold and (yards <= leadYards * hold
							or yards + W.Between(view.north, view.west, lead.north, lead.west) - leadYards <= CATCH.extra * hold)
					else
						near = yards <= CATCH.near * hold
					end
					local entry = InsertBefore(step, parts, why)
					entry.yards = yards
					local retake
					for _, part in ipairs(parts) do
						if part.element.command == "accept" and L.Failed(Ids(part.element)[1]) then retake = true end
					end
					if retake or near then
						now[index] = true
						onWay[#onWay + 1] = entry
					elseif yards <= CATCH.far then
						entry.first = nil
						offered[#offered + 1] = entry
					end
				end
			end
		end
	end
	caught = now
	table.sort(onWay, function(a, b) return a.step.index < b.step.index end)
	-- "easy" ones last: only CATCH.most are offered.
	table.sort(offered, function(a, b)
		if (a.catch == "easy") ~= (b.catch == "easy") then return b.catch == "easy" end
		if (a.yards or math.huge) ~= (b.yards or math.huge) then return (a.yards or math.huge) < (b.yards or math.huge) end
		return a.step.index < b.step.index
	end)
	for i = #offered, CATCH.most + 1, -1 do offered[i] = nil end
	return onWay, offered
end


-- Only travel and notes are auto-passed once the player is beyond them; a hearthstone to set, a
-- flight path to get, a vendor or trainer visit and manual tasks are not.
local TRAVEL = { ["goto"] = true, zone = true, subzone = true, fly = true, hs = true }
local function OnlyTravel(parts)
	for _, part in ipairs(parts) do
		if part.can and not part.done and not TRAVEL[part.element.command] then return false end
	end
	return true
end

-- For a few seconds after a loading screen, position and bags aren't reliable: nothing about
-- the place is saved until then (Scan).
local SETTLE = 3
local quietUntil = 0
local settled = true

local function Scan(guide)
	local saved = Saved(guide)
	local labels = Labels(guide)
	-- The start was lost with a removed step (Thaw): find it again.
	if saved.start == nil then saved.start = Frontier(guide) + 1 end
	local from = math.max(saved.start or 1, saved.floor or 1)
	local active, main, waiting = {}, nil, nil

	-- True when a later hard step is done before three are found todo.
	local function Passed(index)
		local seen = 0
		for later = index + 1, #guide.raw do
			local step = Step(guide, later)
			if Wanted(step) and not Side(step) then
				local state, _, _, hard = Evaluate(guide, step)
				if hard and (state == "done" or state == "todo") then
					if state == "done" then return true end
					seen = seen + 1
					if seen >= 3 then return false end
				end
			end
		end
		return false
	end

	-- A step's place: its first waypoint, in world yards. nil for one with none.
	local function At(step)
		for _, element in ipairs(step.elements) do
			local place = element.command == "goto" and Place(element)
			if place and place.north then return place end
		end
	end
	-- True when you're already where a run of travel steps takes you: in the zone of the first step after it
	-- with more than travel to do, and that step is nearer than this one. (Come by another way, they'd send you
	-- back the way you came.) Only being in its zone counts: a flight by a hub far off can still be the way on
	-- to a step that is nearer than the hub. A step with no place, like the guide's own hearth, is left to Passed.
	local function Arrived(index)
		if not W.Known() then return false end
		local here = At(Step(guide, index))
		if not here then return false end
		for later = index + 1, #guide.raw do
			local step = Step(guide, later)
			if Wanted(step) and not Side(step) then
				local state, parts = Evaluate(guide, step)
				if state == "todo" and not OnlyTravel(parts) then
					local there = At(step)
					if not there or there.map ~= W.map or there.continent ~= W.continent then return false end
					local toThere = W.Between(W.north, W.west, there.north, there.west)
					return here.continent ~= W.continent or toThere < W.Between(W.north, W.west, here.north, here.west)
				end
			end
		end
		return false
	end

	-- A flight that has lost its reason. The guide flies you somewhere for the steps after the flight. When every
	-- one of them fell away for you (a quest you never took, another class's), the flight is passed. So is the
	-- flight onward from a town you never flew to, unless you're in that zone anyway. The route then flies you from
	-- where you are. ("Fly to Lakeshire" then "fly to Stormwind" became one flight from Darkshire.)
	local function Flies(step)
		for _, element in ipairs(step.elements) do
			if element.command == "fly" and (not element.cond or Applies(element.cond)) then return true end
		end
		return false
	end
	-- Whether a step between two travel steps fell away: nil when it doesn't count (a side step), false when it
	-- is there for you (to do or done).
	local function FellAway(step)
		if Side(step) then return nil end
		if not Wanted(step) then return true end
		local state = Evaluate(guide, step)
		return state ~= "todo" and state ~= "done"
	end
	local function Idle(index)
		local step = Step(guide, index)
		if not Flies(step) then return false end
		-- What it flies you to: up to the next travel step, all of it gone.
		local gone = false
		for later = index + 1, #guide.raw do
			local after = Step(guide, later)
			local fell = FellAway(after)
			if fell == false then
				local state, parts = Evaluate(guide, after)
				if state == "todo" and OnlyTravel(parts) and gone then return true end
				break
			end
			gone = gone or fell == true
		end
		-- What would have flown you here: the flight before it. Passed without flying, and nothing left to do since,
		-- you were never brought to this flight master. Unless you're here anyway.
		local here = At(step)
		if not (W.Known() and here) or (here.map == W.map and here.continent == W.continent) then return false end
		for earlier = index - 1, 1, -1 do
			local before = Step(guide, earlier)
			if Wanted(before) and not Side(before) then
				local state = Evaluate(guide, before)
				if state == "todo" then return false end
				if Flies(before) then
					for number in pairs(saved.latched[earlier] or NOTHING) do
						local element = before.elements[number]
						if element and element.command == "fly" then return false end
					end
					return true
				end
			end
		end
		return false
	end

	-- A side step runs until its target step is behind `index`; if the target is itself a
	-- side step, for as long as that one runs.
	local function Lasts(entry, index, depth)
		local target = entry.target
		if not target or target >= index then return true end
		for _, other in ipairs(active) do
			if other.step.index == target then return (depth or 0) < 10 and Lasts(other, index, (depth or 0) + 1) end
		end
		return false
	end

	local function Running(label, index)
		local at = labels[label]
		if not at or at >= index then return false end
		for _, entry in ipairs(active) do
			if entry.step.index == at then return Lasts(entry, index) end
		end
		return false
	end

	local index = math.max(saved.start or 1, from - STICKY_REACH)
	while index <= #guide.raw do
		local step = Step(guide, index)
		local leap
		if Wanted(step) then
			local state, parts, total, hard = Evaluate(guide, step)
			-- Auto-pass a soft travel step once you're beyond it, unless the player went back to it (held).
			if state == "todo" and not hard and index >= from and not saved.held[index] and OnlyTravel(parts)
				and (Passed(index) or Arrived(index) or Idle(index)) then
				if settled then saved.done[index] = true end
				state = "done"
			end
			if state == "todo" then
				if Side(step) then
					local with = Tag(step, "completewith")
					local target
					if with then
						target = with == "next" and NextWanted(guide, index) or labels[with]
					else
						-- A sticky step ends with the step that requires it.
						local label = Tag(step, "label")
						target = label and guide.requiredBy[label] or nil
						if target and target <= index then target = nil end
					end
					local needs = Tag(step, "requires")
					active[#active + 1] = { step = step, parts = parts, side = true, target = target, manual = Manual(parts),
						needs = needs and labels[needs] or nil, ghost = Tag(step, "hidewindow") ~= nil }
				elseif index >= from then
					local needs = Tag(step, "requires")
					local entry = { step = step, parts = parts, manual = Manual(parts) }
					-- Waits while a side step it requires is still running.
					if needs and Running(needs, index) then waiting = entry else main = entry end
					break
				end
			elseif state == "skip" and index >= from and not Side(step) then
				leap = Leap(guide, step, labels)
			end
		end
		index = leap or index + 1
	end

	local live = {}
	local head = main or waiting
	-- Objectives for the log, optional inserts (First), and on-the-way catch-up (Catchup) before the place.
	local behind, offered = {}, {}
	if main then
		local needed = LeadBefore(guide, main.step.index)
		behind, offered = Catchup(guide, main, needed)
		live[1] = behind[1] or main
	end
	if head and settled then saved.floor = head.step.index end
	-- A hold lasts until the place has moved past the step.
	for held in pairs(saved.held) do
		if settled and (not head or held < head.step.index) then saved.held[held] = nil end
	end
	-- Side steps end with their target; one that requires another step waits for it.
	local ghosts = {}
	for _, entry in ipairs(active) do
		local ahead = not head or Lasts(entry, head.step.index)
		local held = false
		if entry.needs then
			local required = Step(guide, entry.needs)
			held = (main ~= nil and entry.needs == main.step.index)
				or (required ~= nil and Wanted(required) and Side(required) and Evaluate(guide, required) == "todo")
		end
		if ahead and not held and (not head or entry.step.index < head.step.index) then
			if entry.ghost then
				ghosts[#ghosts + 1] = entry
			elseif #live < 5 then
				live[#live + 1] = entry
			end
		end
	end
	-- Hidden steps lend their waypoints to the first live step.
	if live[1] and #ghosts > 0 then live[1].ghosts = ghosts end
	return live, main, waiting, behind, offered
end

-- A dungeon run (Run.lua) stands in for the guide while it lasts: ns.char.guide.run = { short, back (the key of the
-- guide it stands in for), picked }. Returns the run's guide, made current; nil when there is none, and when
-- there is nothing left to make one of (or the file that makes it isn't loaded), the guide it stood in for is back.
function G.RunGuide(state)
	local run = state.run
	if type(run) ~= "table" then return nil end
	local guide = ns.Run and ns.Run.Guide(run)
	if guide then
		state.key = Key(guide)
		local saved = Saved(guide)
		if saved.start == nil then saved.start = 1 end
		G.current = guide
		return guide
	end
	state.run, state.key, state.picked = nil, run.back, run.picked
end

-- A guide made while playing (a run's) joins the ones read from the data. `fresh`: its saved place starts over.
function G.Adopt(guide, fresh)
	local key = Key(guide)
	byName[key] = guide
	if fresh then
		ns.char.guides[key] = nil
		thawed[key] = nil
	end
	return key
end

function G.ByKey(key)
	return key and byName and byName[key] or nil
end

-- The run over, done (`say`) or stopped: its place is forgotten and the guide it stood in for is back, at its
-- place. `kept`: a guide picked by hand, which the card stays on (Run.lua's Ended puts it back in zone mode
-- otherwise, when the run began there). Returns that guide.
function G.EndRun(say, kept)
	local state = ns.char.guide
	local run, guide = state.run, G.current
	state.run = nil
	if ns.Run and ns.Run.Ended then ns.Run.Ended(run, kept) end
	if guide and guide.run then
		ns.char.guides[Key(guide)] = nil
		thawed[Key(guide)] = nil
		if say then
			T:Print(("|cffffffff%s|r are done. Back to your guide."):format(guide.name))
			G.Cheer(guide)
		end
	end
	G.current, G.active = nil, {}
	state.key, state.picked = nil, nil
	local back = type(run) == "table" and run.back and byName[run.back]
	if back and not Usable(back) then back = nil end
	back = back or Detect()
	if back then Select(back, type(run) == "table" and run.picked or nil) end
	return back
end

local function FindLive()
	if not facts then ReadFacts() end
	-- A guide that was live and ends now is announced.
	local playing = G.current ~= nil and (#G.active > 0 or G.waiting ~= nil)
	G.active, G.waiting, G.finished, G.behind, G.offered = {}, nil, nil, {}, {}
	canBack = nil
	settled = GetTime() >= quietUntil
	if not ns.Following() then
		G.current = nil
		return
	end
	local state = ns.char.guide
	local guide = G.current
	if not guide then guide = G.RunGuide(state) end
	if not guide then
		guide = state.key and byName[state.key]
		if guide and not Usable(guide) then guide = nil end
		if guide then G.current = guide else guide = Detect() end
		if guide and guide ~= G.current then Select(guide) end
	end
	-- A finished guide hands over to the next; at most four hops per call.
	for _ = 1, 4 do
		if not guide then return end
		local live, main, waiting, behind, offered = Scan(guide)
		if main or waiting then
			G.active, G.waiting, G.behind, G.offered = live, waiting, behind, offered
			return
		end
		-- An open sticky step keeps the guide current after its last main step.
		local open = {}
		for _, entry in ipairs(live) do
			if Tag(entry.step, "sticky") ~= nil then open[#open + 1] = entry end
		end
		if #open > 0 then
			G.active = open
			return
		end
		if guide.run then
			-- A dungeon run done: the guide it stood in for carries on.
			guide = G.EndRun(playing and settled)
			playing = false
		else
			local following = Following(guide)
			if not following then
				G.active = live
				-- The last guide: Route.lua suggests zones from here.
				G.finished = guide
				if playing and settled then
					T:Print(("|cffffffff%s|r is done. That was your last guide. The card now shows nearby quests and zones to try.")
						:format(guide.name))
					G.Cheer(guide)
				end
				return
			end
			if playing and settled then
				T:Print(("|cffffffff%s|r is done. Next: |cffffffff%s|r."):format(guide.name, following.name))
				G.Cheer(guide)
				playing = false
			end
			-- So Back at the start of the next guide can return to this one.
			Saved(following).after = Key(guide)
			guide = following
			Select(guide, state.picked)
		end
	end
end

-- A guide done: its name on the top's plate for a moment under the addon's mark, and the quest-list sound.
local CHEER = 8
function G.Cheer(guide)
	PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
	if Shy.Notices and Shy.Notices.Voice then
		Shy.Notices.Voice("shyquest-done", { priority = 5, hold = CHEER, icon = "Interface\\AddOns\\ShyQuest\\Media\\ShyQuest",
			title = guide.name, under = "Guide done" })
	end
end

-- fn() runs after every G.Refresh.
G.listeners = {}
function G.OnLive(fn)
	G.listeners[#G.listeners + 1] = fn
end

-- Recomputes the live steps. Called on every route rebuild.
function G.Refresh()
	FindLive()
	G.stamp = G.stamp + 1
	for _, fn in ipairs(G.listeners) do fn() end
end

-- Latches

-- Every live step, ghosts included.
local function EachLive(fn)
	for _, entry in ipairs(G.active) do
		fn(entry)
		if entry.ghosts then
			for _, ghost in ipairs(entry.ghosts) do fn(ghost) end
		end
	end
end

-- The items the live steps count in the bags (to collect, to have so many of, to destroy, to bank, to use or
-- wear), into `into`: a change in the bags of none of these is nothing to the guide.
G.ITEM_LINES = { collect = true, itemcount = true, destroy = true, bankdeposit = true, bankwithdraw = true, use = true, equip = true }
function G.ItemsNow(into)
	EachLive(function(entry)
		for _, part in ipairs(entry.parts or NOTHING) do
			local element = part.element
			if G.ITEM_LINES[element.command] then
				local list = Ids(element)
				-- (A collect line is the item, how many, the quest: only reaching that many, or falling
				-- back under it, changes the step. Any other line, every count.)
				local need = element.command == "collect" and tonumber(list[2]) or nil
				if element.command == "collect" then
					local id = list[1]
					if id and id > 0 and into[id] ~= true then into[id] = need or true end
				else
					for _, id in ipairs(list) do
						if id > 0 then into[id] = true end
					end
				end
			end
		end
	end)
	return into
end

local function Remember(saved, index, number)
	saved.latched[index] = saved.latched[index] or {}
	saved.latched[index][number] = true
end

-- Latches every open task of the live steps for which test(element, part, entry) is true.
local function Latch(test)
	local guide = G.current
	if not guide then return end
	local saved, changed = Saved(guide), false
	EachLive(function(entry)
		for _, part in ipairs(entry.parts) do
			if (part.can or part.soft) and not part.done and test(part.element, part, entry) then
				Remember(saved, entry.step.index, part.number)
				changed = true
			end
		end
	end)
	if changed then ns.Refresh() end
	return changed
end
G.Latch = Latch

function G.Happened(command)
	return Latch(function(element) return element.command == command end)
end

-- Whether the flight being flown (Shy.Way.Flight.Now) lands where a "fly" step says, by the flight point's
-- name or its zone ("Sentinel Hill" or "Westfall" for "Sentinel Hill, Westfall"): a flight elsewhere ticks
-- no step. True where the flight or the step says nothing of where.
local function FliesTo(wanted)
	wanted = strtrim(wanted or ""):lower()
	if wanted == "" then return true end
	local flight = Shy.Way.Flight and Shy.Way.Flight.Now and Shy.Way.Flight.Now()
	if not flight then return true end
	-- (The flight point's full name, with its zone, is the transit stop's; the flight itself keeps the name
	-- alone. A point the stops don't have: nothing is known of its zone, so the flight counts.)
	local full
	local last = tonumber((flight.key or ""):match("(%d+)$"))
	if last and Shy.Way.Stops then
		for _, stop in ipairs(Shy.Way.Stops()) do
			if stop.node == last and stop.name then
				full = stop.name
				break
			end
		end
	end
	if not full or full == "" then return true end
	for part in full:lower():gmatch("[^,]+") do
		local piece = strtrim(part)
		if piece ~= "" and (piece:find(wanted, 1, true) or wanted:find(piece, 1, true)) then return true end
	end
	return false
end

-- Whether you stand where a "fly" step would take you already: within FLY.there yards of a flight point its words
-- name (by its name or its zone, as FliesTo reads them). Got there another way (the stone, a boat, on foot), the
-- flight is no step to take: the route would send you to its flight master to fly back where you are.
local FLY = { there = 400 }
local function FlyThere(wanted)
	wanted = strtrim(wanted or ""):lower()
	if wanted == "" or not (Shy.Way.Stops and W.Known()) then return false end
	for _, stop in ipairs(Shy.Way.Stops()) do
		if stop.by == "flight" and stop.name and stop.world == W.continent and stop.north then
			local named = false
			for part in stop.name:lower():gmatch("[^,]+") do
				local piece = strtrim(part)
				if piece ~= "" and (piece:find(wanted, 1, true) or wanted:find(piece, 1, true)) then named = true end
			end
			if named and W.Between(W.north, W.west, stop.north, stop.west) <= FLY.there then return true end
		end
	end
	return false
end
G.FlyThere = FlyThere

function G.Flew()
	return Latch(function(element) return element.command == "fly" and FliesTo(element.args) end)
end

local INN = 60               -- yards from a step's place that count as being at its inn
local function BoundHere()
	local home = GetBindLocation()
	return home ~= nil and home ~= "" and (home == GetSubZoneText() or home == GetMinimapZoneText() or home == GetZoneText())
end

-- Called on the pulse: latches arrivals, passed waypoints and flights taken.
function G.Watch()
	local guide = G.current
	if not guide or #G.active == 0 or not W.Known() then return end
	-- (Standing still with the same live steps: nothing to arrive at that wasn't there last pulse.)
	local seen = G.watched or {}
	G.watched = seen
	if seen.north == W.north and seen.west == W.west and seen.active == G.active and seen.stamp == G.stamp
		and seen.guide == guide and not UnitOnTaxi("player") then
		return
	end
	seen.north, seen.west, seen.active, seen.stamp, seen.guide = W.north, W.west, G.active, G.stamp, guide
	local saved, changed = Saved(guide), false
	EachLive(function(entry)
		local index = entry.step.index
		local latched = saved.latched[index] or NOTHING
		local list = Ways(entry.parts, latched)
		for _, way in ipairs(list) do
			if way.at.task and way.part.can and not way.passed and Arrived(way.at) then
				Remember(saved, index, way.part.number)
				changed = true
			end
		end
		-- A .home step is done when the player stands at its inn and is already bound there
		-- (many such steps don't name the inn, so this can only be checked on site).
		for _, part in ipairs(entry.parts) do
			if part.element.command == "home" and part.can and not part.done and BoundHere() then
				for _, way in ipairs(list) do
					local at = way.at
					if at.north and (at.continent == nil or at.continent == W.continent)
						and W.Between(W.north, W.west, at.north, at.west) <= INN then
						Remember(saved, index, part.number)
						changed = true
						break
					end
				end
			end
		end
		-- A flight to where you stand already (G.FlyThere: you came another way) is done: no flying back to it.
		for _, part in ipairs(entry.parts) do
			if part.element.command == "fly" and part.can and not part.done and FlyThere(part.element.args) then
				Remember(saved, index, part.number)
				changed = true
			end
		end
		-- Waypoints are passed in order.
		local lead = Leads(list)
		if lead and not lead.at.task and Arrived(lead.at) then
			Remember(saved, index, lead.part.number)
			changed = true
		elseif not lead and Tag(entry.step, "loop") ~= nil then
			-- Loop step with every waypoint passed: start the round again.
			for _, way in ipairs(list) do
				if way.passed and not way.quiet and not way.at.task and saved.latched[index] then
					saved.latched[index][way.part.number] = nil
					changed = true
				end
			end
		end
	end)
	if changed then ns.Refresh() end
	if UnitOnTaxi("player") then G.Flew() end
end

-- Player controls

-- Applies a manual change at once, so a second click acts on the new state.
local function Moved()
	ns.Refresh()
	ns.Pulse()
end

-- tick: true (done), "skip" or nil. Clearing a skip restores the quests it dropped.
local function SetTick(saved, index, tick)
	if saved.done[index] == "skip" and tick ~= "skip" then
		for quest, by in pairs(saved.dropped) do
			if by == index then saved.dropped[quest] = nil end
		end
	end
	saved.done[index] = tick
	if tick then saved.held[index] = nil end
end

-- Reopens a step: clears its tick and latches and holds it so it isn't auto-passed again.
-- `place` is the live step: an earlier step becomes the place, a later one is only reopened.
local function Reopen(saved, index, place)
	SetTick(saved, index, nil)
	saved.latched[index] = nil
	saved.held[index] = true
	if saved.start and saved.start > index then saved.start = index end
	if saved.left and saved.left > index then saved.left = index end
	if not place or index < place then saved.floor = index end
end

function G.MarkDone(index, done, guide)
	if not done then return G.BackTo(index) end
	guide = guide or G.current
	if not guide then return end
	SetTick(Saved(guide), index, true)
	Moved()
end

-- Reopens a step, and moves to it if it is behind the live one.
function G.BackTo(index)
	local guide = G.current
	if not guide or not guide.raw[index] then return false end
	local main = Head()
	Reopen(Saved(guide), index, main and main.step.index)
	Moved()
	return true
end

-- Reopens a step of the current guide for the next build to come to: nothing is built now, so it can be asked
-- for while the route is being built (Stock.lua).
function G.Reopen(index)
	local guide = G.current
	if not guide or not guide.raw[index] then return false end
	local main = Head()
	Reopen(Saved(guide), index, main and main.step.index)
	ns.Refresh()
	return true
end

-- Continues from this step, leaving everything before it (saved.left: see First, Dropped).
function G.StartAt(index)
	if not G.current then return end
	local saved = Saved(G.current)
	saved.start, saved.floor = index, nil
	saved.left = index
	SetTick(saved, index, nil)
	saved.held[index] = true
	Moved()
end

-- Switches to a guide, resuming its saved place. A dungeon run ends.
function G.Pick(guide)
	if ns.char.guide.run then G.EndRun(false, true) end
	Select(guide, true)
	Moved()
end

-- A dungeon run's guide (Run.lua) made current at its first step, ns.char.guide.run already saying what it stands
-- in for; that guide keeps its place.
function G.Run(guide)
	G.Adopt(guide, true)
	Saved(guide).start = 1
	Select(guide, true)
	Moved()
end

-- Ends a dungeon run by hand (`kept`: the card stays on the guide). Returns the guide that is back.
function G.StopRun(kept)
	local back = G.EndRun(false, kept)
	Moved()
	return back
end

-- Re-detects the guide and place, dropping manual ticks, skips and holds. The guides after it
-- lose their places too, so handing on joins each where the quests say, not where it was left.
-- A dungeon run ends.
function G.Auto()
	if ns.char.guide.run then G.EndRun(false, true) end
	local state = ns.char.guide
	state.key, state.picked = nil, nil
	G.current, G.finished = nil, nil
	local guide = Detect()
	if guide then
		local saved = Saved(guide)
		saved.start, saved.floor, saved.left = nil, nil, nil
		wipe(saved.done)
		wipe(saved.dropped)
		wipe(saved.held)
		local after = false
		for _, later in ipairs(G.Chain()) do
			if after then
				local kept = Saved(later)
				kept.start, kept.floor, kept.left = nil, nil, nil
			end
			if later == guide then after = true end
		end
		Select(guide)
	end
	Moved()
end

-- Called on any settings change. The place stays: steps a change brings in behind it are caught up
-- on (Catchup), and a dungeon's lead from there (DetourBehind).
function G.Forget()
	ForgetApplies()
	G.chain = nil
	if guides then
		for _, guide in ipairs(guides) do guide.order = nil end
	end
	-- (A dungeon run's guide is none of those.)
	if G.current then G.current.order = nil end
end

function G.List()
	local list = {}
	for _, guide in ipairs(guides) do
		if Listed(guide) then list[#list + 1] = guide end
	end
	return list
end

-- Describing a step

local MARK = { accept = "pickup", turnin = "turnin", complete = "goal" }

-- Guide text uses color tags ("|cSHY_FRIENDLY_...|r"), mapped here to theme colors.
local TONES = { FRIENDLY = "good", ENEMY = "bad", LOOT = "hot", PICK = "head", WARN = "alert", BUY = "alert" }
local function Colored(text)
	local colors = Shy.UI.colors
	return (text:gsub("|cSHY_(%u+)_", function(name)
		return "|cff" .. Shy.UI.Hex(colors[TONES[name] or "text"])
	end))
end

local function QuestName(id)
	local quest = D.Quest(id)
	return (quest and quest.name) or C_QuestLog.GetTitleForQuestID(id) or ("quest " .. id)
end

-- May be uncached: it is requested, and the step re-rendered on GET_ITEM_INFO_RECEIVED.
local function ItemName(id)
	local name = C_Item.GetItemNameByID(id)
	if name then return name end
	C_Item.RequestLoadItemDataByID(id)
	local item = D.Item(id)
	return item and item.name ~= "" and item.name or nil
end

-- Commands whose text isn't shown: a macro's text is its body.
local UNSAID = { macro = true }

-- Why a quest to accept isn't available yet ("from level 14", "after The Coastal Menace").
-- Not for one the same step turns in first (handsIn, set by Describe).
local handsIn = NOTHING
local function NotYet(id)
	local data = D.Quest(id)
	if not data or L.Has(id) or L.Done(id) then return nil end
	if data.minLevel > L.Level() then return "from level " .. data.minLevel end
	local before = L.Before(data)
	if before and not handsIn[before] then return "after " .. QuestName(before) end
end

-- The text for one part of a step, or nil.
local function Words(part)
	local element = part.element
	local command, id = element.command, element.ids and element.ids[1]
	if UNSAID[command] then return nil end
	local said = element.text
	if command == "complete" and id then
		-- The quest log's objective text, with its live count.
		local info = (C_QuestLog.GetQuestObjectives(id) or {})[Objective(element)]
		if info and info.text and info.text ~= "" then return info.text end
		if not L.Has(id) and not L.Done(id) then return said or ("Needs " .. QuestName(id)) end
		return said or QuestName(id)
	end
	if command == "collect" then
		local need, have = element.need, element.have
		if need == nil and id then
			-- Not judged yet: use the plain count.
			need = element.ids[2] or 1
			have = math.min(need, C_Item.GetItemCount(id))
		end
		if not need or need <= 0 then return nil end
		if said then return ("%s (%d/%d)"):format(said, have, need) end
		-- Always a line, so a collect-only step has something to show.
		return id and ("%s: %d/%d"):format(ItemName(id) or "Item", have, need) or nil
	end
	if part.grounded then
		-- Before a flight master's map has opened, the guide doesn't know your flight paths yet.
		if not Shy.Way.FlightsRead() then return "Talk to a flight master once so the guide knows your flight paths" end
		local to = strtrim(element.args or "")
		return to ~= "" and ("You can't fly to %s from here yet"):format(to) or "You can't fly there from here yet"
	end
	if command == "accept" and id and part.can and not part.done then
		if L.Failed(id) then return "Failed: abandon and retake " .. QuestName(id) end
		local why = NotYet(id)
		if why then return ("%s (%s)"):format(said or ("Accept " .. QuestName(id)), why) end
	end
	if said then return said end
	if command == "accept" and id then return "Accept " .. QuestName(id) end
	if command == "turnin" and id then return "Turn in " .. QuestName(id) end
	if command == "xp" and part.can then return "Grind to level " .. (element.args:match("%d+") or "?") end
	if command == "goto" and part.can then
		local at = Place(element)
		return "Go to the mark" .. (at and W.MapName(at.map) and (" in " .. W.MapName(at.map)) or "")
	end
	if command == "destroy" and id then
		local name = ItemName(id)
		return name and ("Destroy " .. name) or nil
	end
	if command == "abandon" and id then return "Abandon " .. QuestName(id) end
	if command == "skill" and part.can then
		local list = Args(element)
		-- The client's name for the skill line ("First Aid"), not the guides' key ("firstaid").
		local line = list[1] and ns.data.routeInfo and ns.data.routeInfo.skills[list[1]:lower()]
		local info = line and C_SkillInfo.GetSkillLineInfoByID(line)
		local name = info and info.name or line and C_TradeSkillUI.GetTradeSkillDisplayName(line)
		if not name or name == "" then name = list[1] or "skill" end
		return ("Get your %s to %s"):format(name, (list[2] or "?"):match("%d+") or "?")
	end
end

-- The name of what a part counts (a collect's item, an objective's subject), for matching notes to it.
local function Counted(part)
	local element = part.element
	local id = element.ids and element.ids[1]
	if not (part.can or part.soft) or not id then return nil end
	if element.command == "collect" then return ItemName(id) end
	if element.command == "complete" then
		local info = (C_QuestLog.GetQuestObjectives(id) or {})[Objective(element)]
		local name = info and info.text and info.text:match("^(.-)%s*:%s*%d+%s*/%s*%d+") or nil
		if name then return (name:gsub(" slain$", "")) end
	end
end

-- "Name::1234;Other Name" of a .target, .mob or .unitscan, as { name, npc } each.
local function Named(element)
	local names = element.names
	if not names then
		names = {}
		for entry in element.args:gmatch("[^;]+") do
			local plain = strtrim(entry):gsub("^%+", "")
			local name, npc = plain:match("^(.-)::(%d+)$")
			name = strtrim(name or plain)
			if name ~= "" then names[#names + 1] = { name = name, npc = tonumber(npc) } end
		end
		element.names = names
	end
	return names
end

local RECALL = {
	hearthstone = 6948,
	astral = 556,  -- buttons for .hs
}

-- ".line Elwynn Forest,53.68,47.29,52.82,48.78,...": a path to draw on a map.
local function Trail(element)
	local trail = element.trail
	if trail == nil then
		trail = false
		local list = Args(element)
		local zone = list[1] and list[1]:gsub("^%+", "")
		local map = zone and MapOf(zone)
		if map then
			local points = {}
			for i = 2, #list - 1, 2 do
				local x, y = tonumber(list[i]), tonumber(list[i + 1])
				if x and y then
					points[#points + 1] = math.floor(x * 100 + 0.5)
					points[#points + 1] = math.floor(y * 100 + 0.5)
				end
			end
			if #points >= 4 then trail = { map = map, points = points } end
		end
		element.trail = trail
	end
	return trail or nil
end

local function Sells(npc, item)
	local record = D.Item(item)
	for _, source in ipairs(record and record.sources or NOTHING) do
		if source.kind == "v" and source.id == npc then return true end
	end
	return false
end

-- The step's subject: the first NPC or mob it names that isn't only mentioned in finished notes.
-- With `task`: one named for that task, else for the step as a whole, never for another task,
-- so the title matches where the arrow points.
function G.Who(view, task)
	local whole
	for _, named in ipairs(view.names or NOTHING) do
		if not task or named.task == nil or named.task == task then
			local name = named.name:lower()
			local spoken, open = 0, 0
			for _, line in ipairs(view.advice or NOTHING) do
				if line.plain:find(name, 1, true) then
					spoken = spoken + 1
					if not line.done then open = open + 1 end
				end
			end
			if spoken == 0 or open > 0 then
				if not task or named.task == task then return named.name end
				whole = whole or named.name
			end
		end
	end
	return whole
end

-- Builds the view of a step for the card, the list and the pins. Parts of dropped quests are
-- left out unless `whole`. `ghosts`: hidden steps lending their waypoints.
--   view.lines     the lines to show; view.actions: the quests involved
--   view.who       the step's subject (G.Who); view.led: the task its position is for
--   view.targets   { name, npc, kind = "target" | "mob" | "scan", of = the task it is named for, or nil }
--   view.sells     vendor ids still to visit (nil when none)
--   view.buys      ids of vendors to buy a quest item from (nil when none)
--   view.uses      { kind = "item" | "spell" | "macro", id, name, icon, body }
--   view.talk      { kind = "option", ids } | { kind = "first" } | { kind = "order", npc, picks }
--   view.fly       the flight's destination; view.binds: it sets a hearthstone
--   view.timers    { number, seconds, label }: countdown once part `number` is done
--   view.path      waypoints still ahead, each { map, x, y, continent, north, west }
--   view.trails    { map, points = { x, y, x, y, ... } }: paths to draw
--   view.links     { text, url }
-- The notes that only restate the task right under them ("Kill Verog the Dervish for Verog's Head"
-- over "Verog's Head: 0/1", an objective or an item to collect): line -> { who = "Kill Verog the
-- Dervish", verb, names, aside }, keyed by the task's line; the notes themselves in `skip`. A note that
-- says no more than the count's own name ("Loot Stolen Weapon" over "Stolen Weapon: 0/8") folds away
-- whole: { names, same = true }, with nobody to name.
function G.Folds(lines)
	local folds, skip = {}, {}
	for index, line in ipairs(lines) do
		local below = lines[index + 1]
		if line.command == "" and not line.can and line.of and below and below.number == line.of
			and (below.command == "complete" or below.command == "collect") then
			local plain = Shy.UI.PlainText(line.text)
			local verb, names, rest = plain:match("^(%a+) (.-) for (.+)$")
			if verb == "Kill" or verb == "Loot" then
				skip[line] = true
				folds[below] = { who = verb .. " " .. names, verb = verb, names = names, aside = rest:match("%((.-)%)%s*$") }
			else
				verb, names = plain:match("^(%a+) (.+)$")
				local counted = Shy.UI.PlainText(below.text):gsub("^%s*%d+/%d+%s+", ""):gsub("%s*:%s*%d+/%d+%s*$", "")
				if (verb == "Kill" or verb == "Loot") and names:lower() == counted:lower() then
					skip[line] = true
					folds[below] = { names = names, same = true }
				end
			end
		end
	end
	return folds, skip
end

-- A step's task by a name that stays the same from one build of the route to the next: what the card and the
-- step's buttons call the count a creature's chip stands under (Card.lua, GuideButtons.lua).
function G.TaskKey(view, number)
	return ("%s:%s:%s"):format(view.guide and view.guide.name or "", view.step and view.step.index or 0, number)
end

function G.Describe(guide, step, parts, whole, ghosts)
	local view = { guide = guide, step = step, lines = {}, actions = {}, gotos = {}, targets = {}, uses = {}, talk = {},
		timers = {}, path = {}, trails = {}, links = {} }
	local counted, who, used = {}, {}, {}
	local shape = Shape(step)
	handsIn = {}
	for _, part in ipairs(parts) do
		if part.element.command == "turnin" and not part.dropped then handsIn[Ids(part.element)[1] or 0] = true end
	end

	local function Use(kind, id, more)
		local key = kind .. ":" .. tostring(id)
		if used[key] then return end
		used[key] = true
		local use = more or {}
		use.kind, use.id = kind, id
		view.uses[#view.uses + 1] = use
	end

	-- Hide what is over for good: dropped parts, objectives of turned-in quests, and the note
	-- directly above such a task (matched by position, since its count no longer has a name).
	local gone, above, note = {}, {}, nil
	for _, part in ipairs(parts) do
		local element = part.element
		local command = element.command
		local quest = command == "complete" and Ids(element)[1] or command == "collect" and Ids(element)[3]
		if part.dropped or (quest and quest > 0 and L.Done(quest)) then gone[part] = true end
		if command == "" and element.text then
			note = part
		else
			if note and IsTask(element) then above[note] = part end
			note = nil
		end
	end

	local wanted             -- the item a shown line still collects, in small letters
	for _, part in ipairs(parts) do
		local element = part.element
		local command = element.command
		local ids = Ids(element)
		local task = above[part]
		local shown = whole or not (gone[part] or (task ~= nil and gone[task]))
		local owner = part.parent and parts.of[part.parent]
		-- Attached elements go quiet with their task.
		local quiet = owner ~= nil and (owner.done or owner.dropped ~= nil)
		local text = shown and Words(part)
		if command == "collect" and ids[1] and shown then
			wanted = not part.done and (ItemName(ids[1]) or ""):lower() or nil
		end
		-- "Accept X (use the item)" under the line for that item, still to get: "Use it to accept X".
		if text and command == "accept" and wanted then
			local quest, item = Shy.UI.PlainText(Colored(text)):match("^Accept (.-) %(use (.-)%)$")
			if item and item:lower() == wanted then text = "Use it to accept " .. quest end
		end
		if text then
			local line = { text = Colored(text), done = (part.can or part.soft) and part.done, can = part.can,
				soft = part.soft, mark = MARK[command], command = command, id = ids[1], spec = element.args, number = part.number,
				dropped = part.dropped, manual = command == "+" or nil,
				-- `of`: the task this line belongs to (for a note, the task below it).
				objective = command == "complete" and Objective(element) or nil,
				of = task and task.number or ((part.can or part.soft) and part.number) or nil }
			-- line.failed: the failed quest, which Card.lua lets a click abandon. The accept line
			-- says so in its own text.
			local broken = MARK[command] and not part.done and ids[1] and L.Failed(ids[1]) and ids[1] or nil
			if broken then
				line.failed = broken
				if command ~= "accept" or not part.can then
					line.text = line.text .. " " .. Shy.UI.Wrap(Shy.UI.colors.alert, "(failed: abandon and retake)")
				end
			end
			-- A turn-in while the quest is still open: hint only when the route has no objective step to lead.
			local entry = command == "turnin" and not part.done and not broken and ids[1] and L.entries[ids[1]]
			if entry and not entry.complete and QuestOpen(ids[1]) and not WorkOnQuest(guide, ids[1]) then
				for index, objective in ipairs(C_QuestLog.GetQuestObjectives(ids[1]) or NOTHING) do
					if not objective.finished and objective.text and objective.text ~= "" then
						local from = ns.Route and ns.Route.From and ns.Route.From(ids[1], index)
						line.text = line.text .. " " .. Shy.UI.Wrap(Shy.UI.colors.alert,
							"(first: " .. objective.text .. (from and (", " .. from:gsub("^%u", string.lower)) or "") .. ")")
						break
					end
				end
			end
			if command == "link" then
				line.url = strtrim(element.args)
				view.links[#view.links + 1] = { text = Shy.UI.PlainText(line.text), url = line.url }
			end
			view.lines[#view.lines + 1] = line
		end
		local name = shown and Counted(part)
		if name then counted[#counted + 1] = { name = name:lower(), done = part.done } end

		local open = shown and not quiet
		if command == "target" or command == "mob" or command == "unitscan" then
			if open then
				-- (A creature named for an item the game showed it doesn't drop is nobody to fight for it.)
				local wants = owner and owner.element.counts
				local item = wants and wants.kind == "i" and wants.id
				for _, named in ipairs(Named(element)) do
					-- (The game's own kill credits are nobody to target: D.Internal.)
					if not D.Internal(named.name) and not (item and named.npc and D.Dropless(named.npc, item)) then
						view.targets[#view.targets + 1] = { name = named.name, npc = named.npc,
							kind = command == "unitscan" and "scan" or command, of = part.parent }
						if command ~= "unitscan" then who[#who + 1] = { name = named.name, task = part.parent, kind = command } end
						-- A target named for a task that counts an item they sell is its vendor.
						local counts = command == "target" and named.npc and owner and not owner.done and owner.element.counts
						if counts and counts.kind == "i" and Sells(named.npc, counts.id) then
							view.buys = view.buys or {}
							view.buys[#view.buys + 1] = named.npc
						end
					end
				end
			end
		elseif command == "vendor" then
			-- Vendor by id, for the nameplate mark (Plates.lua).
			if open and ids[1] and not part.done then
				view.sells = view.sells or {}
				view.sells[#view.sells + 1] = ids[1]
			end
		elseif command == "use" or command == "usespell" then
			if open then
				for _, entry in ipairs(Args(element)) do
					local id, how = entry:match("^(%d+):?(%S*)")
					if id then Use(command == "use" and "item" or "spell", tonumber(id), { always = how == "p" or nil }) end
				end
			end
		elseif command == "macro" then
			if open and element.text then
				local list = Args(element)
				Use("macro", list[1] or "Macro", { name = list[1] or "Macro", icon = tonumber(list[2]), body = element.text })
			end
		elseif command == "hs" then
			if part.can and not part.done then
				Use("item", RECALL.hearthstone)
				Use("spell", RECALL.astral)
			end
		elseif command == "skipgossipid" then
			if open then
				local ids = {}
				for _, arg in ipairs(Args(element)) do ids[#ids + 1] = tonumber((arg:gsub("^%+", ""))) end
				if #ids > 0 then view.talk[#view.talk + 1] = { kind = "option", ids = ids, number = part.parent } end
			end
		elseif command == "gossipoption" then
			local id = ids[1]
			if id and shown and not part.done then
				view.talk[#view.talk + 1] = { kind = "option", ids = { id }, number = part.number, task = part.can }
			end
		elseif command == "skipgossip" then
			if open then
				local list = Args(element)
				if #list <= 1 then
					view.talk[#view.talk + 1] = { kind = "first", npc = tonumber(list[1]) }
				else
					local picks = {}
					for i = 2, #list do picks[#picks + 1] = tonumber(list[i]) end
					view.talk[#view.talk + 1] = { kind = "order", npc = tonumber(list[1]), picks = picks }
				end
			end
		elseif command == "fly" then
			if part.can and not part.done and element.args ~= "" then view.fly = strtrim(element.args) end
		elseif command == "home" then
			if shown and not part.done then view.binds = true end
		elseif command == "line" then
			local trail = open and Trail(element)
			if trail then view.trails[#view.trails + 1] = trail end
		elseif command == "collect" then
			-- An item that starts a quest gets a use button.
			local list = Args(element)
			local quest = tonumber(list[3])
			if open and ids[1] and quest and quest > 0 and (tonumber(list[4]) or 0) == 0 and not L.Has(quest) and not L.Done(quest) then
				Use("item", ids[1])
			end
		end
		local timer = shape.timer[part.number]
		if timer and part.can then
			view.timers[#view.timers + 1] = { number = part.number, seconds = timer[1], label = timer[2], done = part.done }
		end
		if MARK[command] and ids[1] and not part.dropped then
			local id = ids[1]
			view.actions[#view.actions + 1] = { kind = MARK[command], id = id, title = QuestName(id), done = part.done,
				level = (D.Quest(id) or L.entries[id] or {}).level or 0 }
		end
	end
	-- A note that names things the step counts is done once all of those are.
	local advice = {}
	for _, line in ipairs(view.lines) do
		if not line.can and not line.soft then
			local plain = Shy.UI.PlainText(line.text):lower()
			local named, open = 0, 0
			for _, thing in ipairs(counted) do
				if plain:find(thing.name, 1, true) then
					named = named + 1
					if not thing.done then open = open + 1 end
				end
			end
			if named > 0 and open == 0 then line.done = true end
			advice[#advice + 1] = { plain = plain, done = line.done }
		end
	end
	view.names, view.advice = who, advice

	-- Waypoints: the ghosts' first, then the step's own.
	local saved = Saved(guide)
	local ways = {}
	for _, ghost in ipairs(ghosts or NOTHING) do
		Ways(ghost.parts, saved.latched[ghost.step.index] or NOTHING, ways)
	end
	local _, own = Ways(parts, saved.latched[step.index] or NOTHING, ways)
	-- line.at: each task's own place (Route.lua, R.Aim).
	local places = {}
	for i = own, #ways do
		local task = ways[i].part.parent
		if task and not places[task] and ways[i].at.north then places[task] = ways[i].at end
	end
	for _, line in ipairs(view.lines) do line.at = places[line.number] end
	local lead = Leads(ways)
	local at = lead and lead.at
	-- view.led: the task the current waypoint belongs to.
	for i = own, #ways do
		if ways[i] == lead then view.led = lead.part.parent end
	end
	view.who = G.Who(view, view.led)
	for _, way in ipairs(ways) do
		view.gotos[#view.gotos + 1] = { at = way.at, reached = way.passed }
		if way.at.arrow and not way.quiet and not way.passed and way.at.x then
			view.path[#view.path + 1] = way.at
		end
		-- No current waypoint: fall back to the first place still open.
		if not lead and not at and not way.quiet and not way.passed then at = way.at end
	end
	-- All passed: the step is at its last place.
	at = at or (ways[#ways] and ways[#ways].at)
	if at then
		view.map, view.north, view.west, view.continent = at.map, at.north, at.west, at.continent
		view.x, view.y = at.x, at.y
	end
	-- A boat's step sits where you board the boat: on the end of the pier, at its height (the guide has the
	-- spot it halts at, in the sea beside it). If you're already across the water, the step moves to where
	-- the boat lands. You aren't sent to the far dock to sail back.
	local far = view.north and W.continent and view.continent ~= W.continent
	for _, line in ipairs(view.north and view.lines or NOTHING) do
		local landing, boarding
		if line.command == "zone" and line.can and not line.done then landing, boarding = G.RideInto(view, MapOf(strtrim(line.spec or ""))) end
		local onto = (far and landing and landing.world == W.continent and landing) or (not far and boarding)
		if onto and onto.x then
			-- (Boarded: on the step's own map still, a few yards from where the guide put it.)
			local x, y
			if onto == boarding then x, y = W.ToMap(view.map, onto.world, onto.north, onto.west) end
			if x then
				view.x, view.y = x, y
			else
				view.map, view.x, view.y = onto.map, math.floor(onto.x * UNITS + 0.5), math.floor(onto.y * UNITS + 0.5)
			end
			view.north, view.west, view.continent, view.up = onto.north, onto.west, onto.world, onto.up
			if line.at then
				local at = {}
				for key, value in pairs(line.at) do at[key] = value end
				at.map, at.x, at.y, at.continent, at.north, at.west, at.up = view.map, view.x, view.y, view.continent, view.north, view.west, view.up
				line.at = at
			end
			break
		end
	end
	return view
end

-- Where the ride from a step's place lands on a map, then where it is boarded. nil if your side has no ride
-- from there to that map.
local RIDE_NEAR = 60         -- yards. A step this close to a ride's start belongs to that ride.
function G.RideInto(view, map)
	if not (map and Shy.Way.Rides) then return nil end
	local side = (UnitFactionGroup("player") or ""):sub(1, 1)
	for _, ride in ipairs(Shy.Way.Rides()) do
		local from, to = ride.from, ride.to
		if to.map == map and to.x and from.world == view.continent and (ride.whose == "" or side == "" or ride.whose:find(side, 1, true))
			and (from.north - view.north) ^ 2 + (from.west - view.west) ^ 2 <= RIDE_NEAR * RIDE_NEAR then
			return to, from
		end
	end
end

-- The short name of the dungeon a step is for, or nil. `guide`: the step's own, where an earlier guide's leads.
function G.Dungeon(index, guide)
	guide = guide or G.current
	local step = guide and Step(guide, index)
	for _, element in ipairs(step and step.elements or {}) do
		if element.command == "dungeon" then return (element.args:match("^(%w+)")) end
	end
end

-- The short name of the dungeon a quest is for, or nil: the one whose own steps take it, in any guide.
-- Read once (the guides don't change while playing), as text first: only steps that name a dungeon are parsed.
do
	local taken
	function G.DungeonOf(id)
		if not guides then return nil end
		if not taken then
			taken = {}
			for _, guide in ipairs(guides) do
				for index, raw in ipairs(guide.raw) do
					if type(raw) ~= "string" or raw:find("dungeon=", 1, true) then
						local step = G.lib.Read(raw, index)
						local short
						for _, element in ipairs(step.elements) do
							if element.command == "dungeon" then short = element.args:match("^(%w+)") end
						end
						for _, element in ipairs(short and step.elements or NOTHING) do
							local quest = element.command == "accept" and Ids(element)[1]
							if quest then taken[quest] = short end
						end
					end
				end
			end
		end
		return taken[id]
	end
end

-- Returns view, state for any step of the current guide. view.number is its display number;
-- view.skipped is the step whose skip caused a "skipped" state.
function G.View(index)
	local guide = G.current
	local step = guide and Step(guide, index)
	if not step then return nil end
	if not Wanted(step) then return nil, "hidden" end
	local state, parts = Evaluate(guide, step)
	if state == "skip" then return nil, "skip" end
	local view = G.Describe(guide, step, parts, state == "skipped")
	view.number = G.Number(index)
	if state == "skipped" then
		view.skipped = index
		if Saved(guide).done[index] ~= "skip" then
			for _, part in ipairs(parts) do
				if part.dropped == ABSENT then
					-- Its quest isn't available through the guide: no step's skip caused this.
					view.absent = true
					break
				elseif part.dropped then
					view.skipped = part.dropped
					break
				end
			end
		end
	end
	return view, state
end

-- A step of the current guide still to do, as a live one is ({ guide, step, parts }): what the route leads to
-- when you take a step the guide isn't on (Route.lua, R.TakeStep). nil: no such step, or nothing to do there.
function G.Entry(index)
	local guide = G.current
	local step = guide and Step(guide, index)
	if not step or not Wanted(step) then return nil end
	local state, parts = Evaluate(guide, step)
	if state ~= "todo" then return nil end
	return { guide = guide, step = step, parts = parts }
end

-- What a step is kept by: the guide's key, and the step's id, which stays its own when the guide is updated.
-- StepOf: the index that id has now (nil: the step is gone).
function G.KeyOf(guide)
	return guide and Key(guide) or nil
end
function G.StepId(index, guide)
	guide = guide or G.current
	return guide and IdOf(guide, index) or nil
end
function G.StepOf(id, guide)
	guide = guide or G.current
	return guide and id ~= nil and Whereabouts(guide)[id] or nil
end

function G.Count()
	return G.current and #G.current.raw or 0
end

-- The next positioned steps, live one first, for the map. Worked out once for each count while the guide
-- stands as it was refreshed (G.stamp: a refresh, or anything said to change what it reads, ns.Refresh), as
-- its live steps are: a route built for a fight or an aura asks it again and gets the same (a list of its own).
G.stamp = 0
local upcoming = { stamp = -1 }
function G.Upcoming(count)
	if upcoming.stamp ~= G.stamp then
		upcoming = { stamp = G.stamp }
	end
	local kept = upcoming[count]
	if not kept then
		kept = G.Ahead(count)
		upcoming[count] = kept
	end
	local out = {}
	for i, view in ipairs(kept) do out[i] = view end
	return out
end
function G.Ahead(count)
	local out = {}
	local guide, main = G.current, G.active[1]
	if not guide or not main or main.side then return out end
	local from = main.step.index
	if main.first then
		-- Earlier steps (G.behind) first, then on from the place.
		for _, entry in ipairs(G.behind) do
			local view, state = G.View(entry.step.index)
			if view and state == "todo" and view.north and #view.lines > 0 and #out < count then out[#out + 1] = view end
		end
		from = Saved(guide).floor or from
	end
	for index = from, math.min(#guide.raw, from + 60) do
		local view, state = G.View(index)
		if view and state == "todo" and view.north and #view.lines > 0 then
			out[#out + 1] = view
			if #out >= count then break end
		end
	end
	return out
end

-- True when one of the next `count` steps has a place within `reach` yards of a point: the guide
-- comes that way again whatever is done there now. Counted: a step that waits on something (a
-- quest still to take), and a step still to do that is not among `seen` (step indexes the caller
-- has reckoned with already).
local COMES = { accept = 1, turnin = 1, complete = 1, collect = 3 }   -- command -> which number is the quest
function G.ComesBack(north, west, reach, count, seen)
	local guide, main = G.current, G.active[1]
	if not guide or not main or main.side then return false end
	local from = main.first and Saved(guide).floor or main.step.index
	for index = from + 1, math.min(#guide.raw, from + count) do
		local step = Step(guide, index)
		local state = Wanted(step) and not Side(step) and Evaluate(guide, step)
		if state == "skip" or (state == "todo" and not (seen and seen[index])) then
			-- Not a waiting step whose quests are all handed in: that one is over.
			local open, near = state == "todo", false
			for _, element in ipairs(step.elements) do
				local quest = COMES[element.command] and Ids(element)[COMES[element.command]]
				if quest and quest > 0 and not L.Done(quest) then open = true end
				local at = element.command == "goto" and Place(element)
				if at and at.north and at.continent == W.continent and W.Between(north, west, at.north, at.west) <= reach then near = true end
			end
			if open and near then return true end
		end
	end
	return false
end

-- Where the guide goes from the place on: for each of its next steps that this character will
-- do (still to do, or waiting on a quest not yet handed in) and that has a place, { index,
-- continent, north, west, tasks = what it has to kill or gather: { quest, objective } or
-- { item, need } each, carried = it flies or hearths on from there, so the way to the next is
-- not walked }; `count` of them at most. For whoever weighs travel ahead (Hearth.lua, Route.lua's
-- R.Passing).
function G.Places(count)
	local out = {}
	local guide, main = G.current, G.active[1]
	if not guide or not main or main.side then return out end
	local from = main.first and Saved(guide).floor or main.step.index
	for index = from, math.min(#guide.raw, from + count * 4) do
		local step = Step(guide, index)
		local state = Wanted(step) and not Side(step) and Evaluate(guide, step)
		if state == "todo" or state == "skip" then
			local open, at, tasks, carried = state == "todo", nil, {}, nil
			for _, element in ipairs(step.elements) do
				local quest = COMES[element.command] and Ids(element)[COMES[element.command]]
				if quest and quest > 0 and not L.Done(quest) then open = true end
				if element.command == "complete" and quest then
					tasks[#tasks + 1] = { quest = quest, objective = Objective(element) }
				elseif element.command == "collect" and Ids(element)[1] then
					tasks[#tasks + 1] = { item = Ids(element)[1], need = tonumber(Args(element)[2]) }
				elseif element.command == "fly" or element.command == "hs" then
					carried = true
				end
				local place = not at and element.command == "goto" and Place(element)
				if place and place.north then at = place end
			end
			if open and at then
				out[#out + 1] = { index = index, continent = at.continent, north = at.north, west = at.west, tasks = tasks, carried = carried }
				if #out >= count then break end
			end
		end
	end
	return out
end

-- Progress, skip and back

-- Commands that are tasks even without text.
local TASK = { accept = true, turnin = true, complete = true, collect = true, abandon = true, train = true,
	zone = true, subzone = true, bindlocation = true }

-- True when a step has a task or text for this character.
local function Says(step)
	for _, element in ipairs(step.elements) do
		if not element.cond or Applies(element.cond) then
			local command = element.command
			-- ".xp <12,1" is a check, ".xp 12" a task.
			if (element.text and not UNSAID[command]) or TASK[command] or LATCH.once[command]
				or (command == "xp" and not element.args:find(",", 1, true)) then
				return true
			end
		end
	end
	return false
end

-- Display numbers: only steps that apply to this character are counted ("step 37 of 212").
-- Cached until a setting or level changes.
local function Order(guide)
	local order = guide.order
	if not order then
		order = { number = {}, count = 0 }
		for index = 1, #guide.raw do
			local step = Step(guide, index)
			if Wanted(step) and Says(step) and Tag(step, "hidewindow") == nil then
				order.count = order.count + 1
				order.number[index] = order.count
			end
		end
		guide.order = order
	end
	return order
end

-- Returns a step's display number and the total. An uncounted step takes the number before it.
function G.Number(index, guide)
	guide = guide or G.current
	if not guide then return nil end
	local order = Order(guide)
	for at = math.min(index, #guide.raw), 1, -1 do
		if order.number[at] then return order.number[at], order.count end
	end
	return 1, order.count
end

-- Returns the live step's number, the total, and the fraction done; nil, total, 1 when finished.
function G.Progress()
	local guide = G.current
	if not guide then return nil end
	local total = Order(guide).count
	local main = Head()
	if not main then return nil, total, 1 end
	local at = G.Number(main.step.index, guide)
	return at, total, (at - 1) / math.max(1, total)
end

-- The saved place in any guide: step number (nil if never started or finished) and total.
function G.Place(guide)
	local order = Order(guide)
	local key = Key(guide)
	local saved = ns.char.guides[key]
	if type(saved) ~= "table" then return nil, order.count end
	-- A place still as it was saved (step ids, from a session before) is thawed first, as Saved does.
	if not thawed[key] and guide.raw then
		thawed[key] = true
		Thaw(guide, saved)
	end
	if not saved.start then return nil, order.count end
	for index = math.max(saved.start, saved.floor or 1), #guide.raw do
		if order.number[index] then return order.number[index], order.count end
	end
	return nil, order.count
end

-- Can Back land here: a main step that applies, has text, and isn't done by live state.
local function Returnable(guide, index)
	local step = Step(guide, index)
	if not step or not Wanted(step) or Side(step) then return false end
	local state, parts = Evaluate(guide, step, true)
	if state ~= "todo" then return false end
	for _, part in ipairs(parts) do
		if not part.dropped and Words(part) then return true end
	end
	return false
end

local function Earlier(guide, before)
	for index = math.min(before, #guide.raw + 1) - 1, 1, -1 do
		if Returnable(guide, index) then return index end
	end
end

-- Where Back goes: the nearest returnable step before the live one, else the last one of the previous guide.
local function Before()
	local guide = G.current
	if not guide then return nil end
	local main = Head()
	local index = Earlier(guide, main and main.step.index or #guide.raw + 1)
	if index then return guide, index end
	local after = Saved(guide).after
	local prior = after and byName[after]
	if prior and prior ~= guide and Usable(prior) then
		index = Earlier(prior, #prior.raw + 1)
		if index then return prior, index end
	end
end

function G.Returnable(index)
	return G.current ~= nil and Returnable(G.current, index)
end

function G.CanBack()
	if canBack == nil then canBack = Before() ~= nil end
	return canBack
end

function G.CanSkip()
	return G.active[1] ~= nil or G.waiting ~= nil
end

-- Skips a step (default: the one shown first) of `guide` (default: the shown step's, which can be an
-- earlier guide's). A quest it would have accepted is dropped from the rest of that guide (see Dropped),
-- so its later steps don't each need skipping.
function G.Skip(index, guide)
	local shown = G.active[1] or G.waiting
	if not index then
		index = shown and shown.step.index
		guide = guide or (shown and shown.guide)
	end
	guide = guide or G.current
	if not guide then return false end
	local step = index and Step(guide, index)
	if not step then return false end
	local saved = Saved(guide)
	SetTick(saved, index, "skip")
	for _, element in ipairs(step.elements) do
		if element.command == "accept" and (not element.cond or Applies(element.cond)) then
			local quest = Ids(element)[1]
			if quest and not saved.dropped[quest] and not L.Has(quest) and not L.Done(quest) then saved.dropped[quest] = index end
		end
	end
	Moved()
	return true
end

-- Goes back one step (see Before) and holds it until done or skipped.
function G.Back()
	local guide, index = Before()
	if not guide then return false end
	local main = guide == G.current and Head() or nil
	if guide ~= G.current then Select(guide, ns.char.guide.picked) end
	Reopen(Saved(guide), index, main and main.step.index)
	Moved()
	return true
end


-- True when the current guide or the next few use a quest. Class quests always count.
function G.Uses(id)
	local quest = D.Quest(id)
	if quest and quest.classes then return true end
	local guide, seen = G.current, 0
	while guide and seen < 4 do
		local asks = Asks(guide)
		if asks.accept[id] or asks.turnin[id] or asks.complete[id] or asks.collect[id] then return true end
		guide, seen = Following(guide), seen + 1
	end
	-- A live step about it, an earlier guide's among them (Lent): it's on the way, not a stray.
	for _, list in ipairs({ G.active, G.behind }) do
		for _, entry in ipairs(list) do
			for _, part in ipairs(entry.parts) do
				local command, ids = part.element.command, Ids(part.element)
				local about = (command == "collect" and ids[3]) or (QUEST[command] and ids[1])
				if about == id and not part.dropped then return true end
			end
		end
	end
	return false
end

-- True when a step still ahead, in this guide or the next few, turns a quest in; or a live one does, the
-- steps behind the place it goes back for (First, Catchup) among them.
function G.HandsIn(id)
	for _, list in ipairs({ G.active, G.behind }) do
		for _, entry in ipairs(list) do
			for _, part in ipairs(entry.parts) do
				if part.element.command == "turnin" and Ids(part.element)[1] == id and not part.done and not part.dropped then
					return true
				end
			end
		end
	end
	local guide, seen = G.current, 0
	while guide and seen < 4 do
		local saved = seen == 0 and Saved(guide) or nil
		local from = saved and math.max(saved.start or 1, saved.floor or 1) or 1
		for _, index in ipairs(Asks(guide).turnin[id] or NOTHING) do
			if index >= from and not (saved and saved.done[index]) and Wanted(Step(guide, index)) then return true end
		end
		guide, seen = Following(guide), seen + 1
	end
	return false
end

-- Shared with the other Guide*.lua files.
G.lib = { Args = Args, Ids = Ids, Objective = Objective, Applies = Applies, Reached = Reached, InZone = InZone, InArea = InArea, MapOf = MapOf,
	Place = Place, Shape = Shape, SkillLevel = SkillLevel, Named = Named, Saved = Saved, Step = Step,
	Parse = ReadStep, Read = ReadStep, Build = Build, Evaluate = Evaluate, Wanted = Wanted, Side = Side, Following = Following,
	Plain = function(on) PLAIN = on == true end }

function G.PartDone(index, number)
	local guide = G.current
	local step = guide and Step(guide, index)
	if not step then return false end
	local _, parts = Evaluate(guide, step)
	local part = parts.of and parts.of[number]
	return part ~= nil and part.done
end

function G.Setup()
	LoadGuides()
	ns.char.guide = ns.char.guide or {}
	ns.char.guides = ns.char.guides or {}

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "HEARTHSTONE_BOUND", "TAXIMAP_OPENED", "PLAYER_UNGHOST", "PLAYER_LEVEL_UP", "MERCHANT_CLOSED", "TRAINER_CLOSED",
		"ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED",
		"PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "PLAYER_LOGOUT", "PLAYER_XP_UPDATE", "GET_ITEM_INFO_RECEIVED",
		"MERCHANT_SHOW", "TRAINER_SHOW" }) do
		events:RegisterEvent(event)
	end
	local serving    -- NPC id of the open vendor or trainer window
	-- ".vendor 1234" needs that vendor; without an id any vendor counts.
	local function Served(command)
		Latch(function(element)
			if element.command ~= command then return false end
			local named = Ids(element)[1]
			return named == nil or serving == nil or named == serving
		end)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "MERCHANT_SHOW" or event == "TRAINER_SHOW" then
			local guid = UnitGUID("npc")
			serving = guid ~= nil and not issecretvalue(guid) and tonumber((guid:match("^[^-]+%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)"))) or nil
			return
		elseif event == "PLAYER_LOGOUT" then
			Freeze()
			return
		elseif event == "PLAYER_XP_UPDATE" then
			-- Fires on every kill: only refresh while a live step waits on XP.
			local waits = false
			EachLive(function(entry)
				for _, part in ipairs(entry.parts) do
					if part.element.command == "xp" then waits = true end
				end
			end)
			if not waits then return end
		elseif event == "GET_ITEM_INFO_RECEIVED" then
			-- An item name requested by ItemName may have arrived.
			if #G.active == 0 then return end
		elseif event == "BAG_UPDATE_DELAYED" then
			-- (ShyQuest.lua builds again for the bags, and asks the guide only when what it counts changed: G.ItemsNow.)
			return
		elseif event == "HEARTHSTONE_BOUND" then
			-- (Latch builds again when a step was ticked; the stone's errand reads the home.)
			G.Happened("home")
			ns.RefreshErrands()
			return
		elseif event == "MERCHANT_CLOSED" then
			-- On close, not on open: the step's text says what to buy. (Latch builds again when it ticked one.)
			Served("vendor")
			return
		elseif event == "TRAINER_CLOSED" then
			Served("trainer")
			return
		elseif event == "TAXIMAP_OPENED" then
			-- Latch only the flight path of this flight master.
			local here = {}
			for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID()) or NOTHING) do
				if node.state == Enum.FlightPathState.Current and node.name then here[#here + 1] = node.name:upper() end
			end
			Latch(function(element)
				if element.command ~= "fp" then return false end
				local name = Args(element)[1]
				-- No name: the one here.
				if not name or not name:find("%w") then return true end
				name = name:upper()
				for _, node in ipairs(here) do
					if node:find(name, 1, true) then return true end
				end
				return false
			end)
			-- (Opening the flight map changes nothing else here: Latch built again if a step was ticked.)
			return
		elseif event == "PLAYER_LEVEL_UP" then
			-- A new level changes which steps apply.
			ForgetApplies()
			for _, guide in ipairs(guides) do guide.order = nil end
			if G.current then G.current.order = nil end
		elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
			if event == "PLAYER_ENTERING_WORLD" then
				quietUntil = GetTime() + SETTLE
				C_Timer.After(SETTLE + 0.1, ns.Refresh)
			end
			-- Arriving at the bind location counts as the hearth.
			local home = GetBindLocation()
			if home and (home == GetSubZoneText() or home == GetMinimapZoneText() or home == GetZoneText()) then
				G.Happened("hs")
			end
		end
		ns.Refresh()
	end)
	-- The gold a live step weighs (".money > 5"). Only crossing it asks the guide again: every other sale and coin
	-- looted wakes nothing (Shy.MoneyEdges). Weighed again with each route, as the live steps change.
	local function Gold() ns.Refresh(nil, "gold") end
	ns.OnRoute(function(rebuilt)
		if not rebuilt then return end
		local weighs = Shy.MoneyEdges("ShyQuest guide", Gold)
		EachLive(function(entry)
			for _, part in ipairs(entry.parts) do
				local element = part.element
				local amount = element.command == "money" and tonumber((element.args or ""):match("^%s*[<>]%s*([%d.]+)"))
				if amount then weighs[#weighs + 1] = math.ceil(amount * 10000) end
			end
		end)
	end, true)
	-- A spell learned or lost (said only when the spellbook really changed): what a step asks may have changed.
	Shy:On("SHY_SPELLS", function() ns.Refresh(nil, "spells") end)
end
