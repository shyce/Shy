-- Weapon skills as part of the route. A weapon master nearby or on the way is a stop when they can
-- teach a weapon the character's class may use and hasn't learned. A weapon asked for by name (the
-- card's "Take me to" menu) is a stop wherever on the continent it is taught.
--   What a class of a race can be taught: Data/Supplies.lua (ns.data.weapons). What the character
--     has: the game's skills window (C_SkillInfo).
--   Who teaches what: the old world's masters come from Data/Supplies.lua (ns.data.masters). The
--     game's own word, read from a master's window and saved for the class (T.db.masters),
--     overrides that and has the prices. A master with neither may teach any of it, and is worth
--     a look.
--   A master's list names a weapon its own way ("One-Handed Swords" for the skill "Swords"). An
--     entry stands for the skill whose name it ends in (Line).
--   Masters standing together are one stop. Each one needed to learn all they teach between them
--     has a line and a nameplate mark. One standing there who isn't needed is named ("Sayoc, not
--     Hanashi").
-- Nothing is bought for you.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R = ns.Data, ns.World, ns.Log, ns.Route
local UI = Shy.UI

local Weapons = {}
ns.Weapons = Weapons

T.defaults.weapons = { on = true }    -- weapon masters as stops on the card
T.defaults.masters = {}               -- what each teaches a class: [class][npc] = { ["Swords"] = { level, copper } }
T.keep.masters = true                 -- read from the game: per account, not per profile

local TITLE = "Weapon Master"         -- what they are called (Data/Town.lua)
local LISTED = 800                    -- yards: one this near gets a row though it is off the way
local WORTH = 600                     -- yards of walk a new weapon is worth, off the way (R.Passing)
local UNSEEN = 1000                   -- copper to have before going to one whose prices were never read
local MOST_NAMED = 3                  -- weapons named in a line
local TOGETHER = 20                   -- yards: masters this near one another are one stop

-- This character's: { known = { [a master's entry] = true }, skip }.
local function Mine()
	local mine = ns.char.weapons
	if not mine then
		mine = { known = {} }
		ns.char.weapons = mine
	end
	return mine
end

-- The character's weapon skills: `lacks`, the names of those it can be taught now and has not;
-- `has`, the names of those it has; `all`, the name of every one its class can be taught, also by
-- skill line.
local function Skills()
	local class = UnitClassBase("player")
	local _, _, race = UnitRace("player")
	local level, lacks, has, all = UnitLevel("player"), {}, {}, {}
	for digits, from in ((ns.data.weapons or {})[tostring(class) .. ":" .. tostring(race)] or ""):gmatch("(%d+):?(%d*)") do
		local skill = tonumber(digits)
		local info = C_SkillInfo.GetSkillLineInfoByID(skill)
		local name = info and info.name or C_TradeSkillUI.GetTradeSkillDisplayName(skill)
		if name and name ~= "" then
			all[#all + 1], all[skill] = name, name
			if info and ((info.rank or 0) > 0 or (info.maxRank or 0) > 0) then
				has[name] = true
			elseif (tonumber(from) or 0) <= level then
				lacks[#lacks + 1] = name
			end
		end
	end
	table.sort(lacks)
	for _, name in ipairs(lacks) do lacks[name] = true end
	return lacks, has, all, class
end

-- The skill an entry on a master's list stands for: the one of that name, else the longest whose
-- name it ends in.
local function Line(entry, all)
	local best
	for _, name in ipairs(all) do
		if entry == name then return name end
		if #entry > #name and entry:sub(-#name - 1) == " " .. name and (not best or #name > #best) then best = name end
	end
	return best
end

-- What a master whose list is known would teach now: { { name, cost }, ... } and the gold for it.
--   want: only the entry for that skill.
local function Teaches(list, has, all, want)
	local mine, level, due, cost = Mine(), UnitLevel("player"), {}, 0
	for name, entry in pairs(list) do
		local line = Line(name, all)
		if not has[line or name] and not mine.known[name] and entry[1] <= level and (not want or line == want) then
			due[#due + 1] = { name = name, cost = entry[2] }
			cost = cost + entry[2]
		end
	end
	table.sort(due, function(a, b) return a.name < b.name end)
	return due, cost
end

-- The same for a master known by the data alone: no prices.
local function Told(id, lacks, all, want)
	local due = {}
	for skill in ((ns.data.masters or {})[id] or ""):gmatch("%d+") do
		local name = all[tonumber(skill)]
		if name and lacks[name] and (not want or name == want) then due[#due + 1] = { name = name, cost = 0 } end
	end
	table.sort(due, function(a, b) return a.name < b.name end)
	return due, 0
end

-- "Bows, Fist Weapons, Staves and 1 more".
local function Names(due)
	local names = {}
	for i = 1, math.min(MOST_NAMED, #due) do names[i] = due[i].name end
	return table.concat(names, ", ") .. (#due > MOST_NAMED and (" and %d more"):format(#due - MOST_NAMED) or "")
end

-- Whether an NPC stands within TOGETHER yards of a world position.
local function Near(npc, continent, north, west)
	for _, place in ipairs(npc.places) do
		for i = 1, #place.points - 1, 2 do
			local there, n, w = W.ToWorld(place.map, place.points[i], place.points[i + 1])
			if there == continent and not place.dungeon and W.Between(north, west, n, w) <= TOGETHER then return true end
		end
	end
	return false
end

-- Who to speak to among the masters standing with `at` (others[id] = { npc, teaches, worth }) to
-- learn all they teach between them, fewest first: whoever teaches the most of it, then whoever
-- teaches the most of what is left. { { npc, due, cost }, ... }, and, when one will do, another
-- standing there who would not teach all of it.
local function Speak(at, others, all)
	local continent, north, west = W.ToWorld(at.map, at.x, at.y)
	local here = {}
	for _, other in pairs(others) do
		if other.npc == at.npc or (continent and other.teaches and Near(other.npc, continent, north, west)) then
			here[#here + 1] = other
		end
	end
	-- The nearest first, so it is the one spoken to when two would do as well.
	table.sort(here, function(a, b)
		if (a.npc == at.npc) ~= (b.npc == at.npc) then return a.npc == at.npc end
		return a.npc.id < b.npc.id
	end)
	local function Key(each) return Line(each.name, all) or each.name end
	local left = {}
	for _, other in ipairs(here) do
		for _, each in ipairs(other.worth and other.teaches or {}) do left[Key(each)] = true end
	end
	local spoken, used = {}, {}
	while next(left) do
		local best, most = nil, 0
		for _, other in ipairs(here) do
			local count = 0
			for _, each in ipairs(not used[other] and other.worth and other.teaches or {}) do
				if left[Key(each)] then count = count + 1 end
			end
			if count > most then best, most = other, count end
		end
		if not best then break end
		used[best] = true
		local due, cost = {}, 0
		for _, each in ipairs(best.teaches) do
			if left[Key(each)] then
				left[Key(each)] = nil
				due[#due + 1] = each
				cost = cost + each.cost
			end
		end
		spoken[#spoken + 1] = { npc = best.npc, due = due, cost = cost }
	end
	if #spoken ~= 1 then return spoken end
	for _, other in ipairs(here) do
		if not used[other] then
			local covers = {}
			for _, each in ipairs(other.teaches) do covers[Key(each)] = true end
			for _, each in ipairs(spoken[1].due) do
				if not covers[Key(each)] then return spoken, other.npc end
			end
		end
	end
	return spoken
end

-- The weapon master as a route errand (R.AddErrand), or nil.
local function Find(lead)
	local weighs = ns.Weighed("weapons")
	if not T.db.weapons.on or not ns.char or not W.Known() then return nil end
	local level = UnitLevel("player")
	local lacks, has, all, class = Skills()
	-- A weapon asked for by name, until it is learned.
	local asked = R.Asked("weapons")
	local want = type(asked) == "string" and asked or nil
	if want and has[want] then
		ns.char.asked.weapons = nil
		asked, want = nil, nil
	end
	if #lacks == 0 or (not asked and (Mine().skip or 0) >= level) then return nil end
	-- (The gold to spare: what the class trainer will want soon is kept for it, Train.Reserve.)
	local keep = ns.Train and ns.Train.Reserve and ns.Train.Reserve() or 0
	local lists, money = T.db.masters[class] or {}, math.max(0, Shy.Money() - keep)
	-- (Each price held against the gold to spare: crossing one is what changes this row.)
	local function Weigh(price) weighs[#weighs + 1] = keep + price end
	local told, ids = ns.data.masters or {}, {}
	for _, id in ipairs(D.Town(nil, TITLE)) do ids[id] = true end
	for id in pairs(lists) do ids[id] = true end
	-- The nearest who has something to teach: by their list, or for all anyone knows. `far`: one
	-- across the sea who would do for the weapon asked for.
	local at, due, far
	local others = {}
	for id in pairs(ids) do
		local npc = D.Npc(id)
		if npc and L.Friendly(npc) then
			local teaches, price
			if lists[id] then
				teaches, price = Teaches(lists[id], has, all, want)
			elseif told[id] then
				teaches, price = Told(id, lacks, all, want)
			end
			-- Prices not read yet: enough for one weapon is enough to go.
			local worth
			if lists[id] then
				worth = #teaches > 0 and price <= money
				if #teaches > 0 then Weigh(price) end
			else
				worth = (not teaches or #teaches > 0) and money >= UNSEEN
				Weigh(UNSEEN)
			end
			local map, x, y, yards, dungeon = W.Nearest(npc.places)
			local place = map and yards and not dungeon and { npc = npc, map = map, x = x, y = y, yards = yards } or nil
			others[id] = { npc = npc, teaches = teaches, worth = worth, place = place }
			if worth and place and (not at or yards < at.yards) then
				at, due = place, teaches
			elseif worth and map and not yards and (not far or (teaches and not far.sure)) then
				-- (No distance: W.Nearest's place for somebody on another continent.)
				far = { npc = npc, map = map, sure = teaches ~= nil }
			end
		end
	end
	if not at then
		if not want or not far then return nil end
		return {
			title = "Learn " .. want,
			lines = { far.npc.title and ("%s, %s"):format(far.npc.name, far.npc.title) or far.npc.name,
				("In %s%s"):format(W.MapName(far.map) or "another land", far.sure and "" or ": they may teach it") },
			caption = "WEAPON MASTER  \194\183  ACROSS THE SEA",
			mark = "weapon",
		}
	end
	-- Who of the masters standing there to speak to, and for what.
	local spoken, aside = {}, nil
	if due then spoken, aside = Speak(at, others, all) end
	if #spoken > 0 then at = others[spoken[1].npc.id].place or at end
	local cost = 0
	if #spoken > 0 then
		due = {}
		for _, each in ipairs(spoken) do
			for _, skill in ipairs(each.due) do due[#due + 1] = skill end
			cost = cost + each.cost
		end
		-- Only what the gold to spare pays for, the cheapest first (a price never read: UNSEEN each). The
		-- title counts those, not every weapon the class could learn.
		table.sort(due, function(a, b)
			local pa, pb = a.cost > 0 and a.cost or UNSEEN, b.cost > 0 and b.cost or UNSEEN
			if pa ~= pb then return pa < pb end
			return a.name < b.name
		end)
		local kept, spent = {}, 0
		cost = 0
		for _, skill in ipairs(due) do
			local price = skill.cost > 0 and skill.cost or UNSEEN
			Weigh(spent + price)
			if spent + price <= money then
				kept[#kept + 1] = skill
				spent, cost = spent + price, cost + skill.cost
			end
		end
		if #kept == 0 then return nil end
		due = kept
		table.sort(due, function(a, b) return a.name < b.name end)
	end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	local passing = not busy and R.Passing("weapons", at.map, at.x, at.y, lead, nil, WORTH)
	if not passing and at.yards > LISTED then return nil end
	local title, lines
	if not due then
		title = want and ("Learn " .. want) or "See the weapon master"
		lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name,
			want and "They may teach it" or #lacks == 1 and "A weapon your class can learn" or ("%d weapons your class can learn"):format(#lacks) }
	else
		title = #due == 1 and ("Learn " .. due[1].name) or ("Learn %d weapon skills"):format(#due)
		if #spoken > 1 then
			lines = {}
			for i, each in ipairs(spoken) do lines[i] = ("%s: %s"):format(each.npc.name, Names(each.due)) end
		else
			lines = { aside and ("%s, not %s"):format(at.npc.name, aside.name)
				or at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name, Names(due) }
		end
	end
	local with = {}
	for i = 2, #spoken do with[#with + 1] = spoken[i].npc end
	return {
		title = title,
		lines = lines,
		caption = "WEAPON MASTER  \194\183  NEW WEAPONS",
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		with = #with > 0 and with or nil,
		mark = "weapon",
		first = passing or nil,
		hover = function()
			local sections = {}
			for _, each in ipairs(#spoken > 0 and spoken or { { due = due or {} } }) do
				local rows = {}
				for i, skill in ipairs(each.due) do
					rows[i] = { glyph = "book", text = skill.name, right = skill.cost > 0 and UI.Money(skill.cost, false, 11) or nil }
				end
				if #rows == 0 then rows[1] = { glyph = "note", quiet = true, text = "Talk to them to see what they teach" } end
				sections[#sections + 1] = { title = #spoken > 1 and each.npc.name or "To learn", rows = rows }
			end
			if due and cost > 0 then
				sections[#sections + 1] = { title = "Costs", rows = { { glyph = "coin", tint = UI.colors.alert, text = UI.Money(cost, false, 11),
					right = "of your " .. UI.Money(GetMoney(), false, 11), rightColor = UI.colors.dim } } }
			end
			return sections
		end,
		tip = function(tip)
			for _, each in ipairs(due or {}) do tip:AddLine(each.name, 1, 1, 1) end
		end,
		menu = function(root)
			root:CreateButton("Ask me next level", function()
				Mine().skip = UnitLevel("player")
				if R.Asked("weapons") then R.Ask("weapons", nil) else ns.Refresh() end
			end)
			root:CreateButton("Stop asking about weapon skills", function()
				T.db.weapons.on = false
				ns.Apply()
			end):SetSub("Turn it back on under Errands")
		end,
	}
end

-- A weapon master's window: what they teach this class, and what of it has been learned since.
local function Read()
	if IsTradeskillTrainer() then return end
	local guid = UnitGUID("npc")
	local kind, id = nil, nil
	if guid and not issecretvalue(guid) then kind, id = guid:match("^(%a+)%-.-%-.-%-.-%-.-%-(%d+)") end
	id = kind == "Creature" and tonumber(id) or nil
	local npc = id and D.Npc(id)
	if not npc or npc.title ~= TITLE then return end
	local class = UnitClassBase("player")
	if not class then return end
	T.db.masters[class] = T.db.masters[class] or {}
	local list = T.db.masters[class][id] or {}
	T.db.masters[class][id] = list
	local mine, shown = Mine(), {}
	for index = 1, GetNumTrainerServices() do
		local name, state, _, level = GetTrainerServiceInfo(index)
		if name and (state == "available" or state == "unavailable" or state == "used") then
			if state ~= "used" or not list[name] then list[name] = { level or 0, GetTrainerServiceCost(index) or 0 } end
			mine.known[name] = state == "used" or nil
			shown[name] = true
		end
	end
	-- What they listed before and list no more was learned.
	if GetTrainerServiceTypeFilter("available") and GetTrainerServiceTypeFilter("unavailable") then
		for name in pairs(list) do
			if not shown[name] then mine.known[name] = true end
		end
	end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "TRAINER_SHOW", "TRAINER_UPDATE" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
	if not ns.char then return end
	if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then Read() end
	-- (A master's list is the weapon errand's alone: the errands are fitted again, not the route.)
	ns.RefreshErrands()
end)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Weapon master for new weapons", function() return T.db.weapons.on end, function()
		T.db.weapons.on = not T.db.weapons.on
		ns.Apply()
	end)
end)

R.AddErrand("weapons", Find, "Weapon trainer")
-- To ask for: each weapon the character can be taught now.
R.AddOffer("weapons", function()
	local list = {}
	if not T.db.weapons.on or not ns.char then return list end
	for i, name in ipairs((Skills())) do list[i] = { text = "Weapon master: " .. name, what = name } end
	return list
end)
