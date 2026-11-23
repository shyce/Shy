-- Reverse index: for a creature, object or item, the quests in the log it matters to, as ties:
--
--   { id, title, level, kind, goal, index, item, chance, done }
--
--   kind   kill      the objective counts this creature
--          drop      the creature drops the objective's item
--          sells     the creature sells it
--          use       the objective counts this object
--          holds     the object contains the item
--          collect   the objective counts this item
--          needs     the quest needs the item without counting it
--          turnin    the quest is finished and is turned in here
--          pickup    an available quest that starts here (or, for an item, with it)
--   goal   the objective (L.Goals: text, have, need, finished); index is its position
--   item   the item's record, for drop, sells, holds, collect and needs
--   chance drop chance in percent, when known
--   done   the objective is finished
--
-- Creatures are keyed by ID (from the GUID). An object under the mouse exposes only its name,
-- so objects are keyed by lower-case name. Rebuilt per log scan (L.stamp); pickups are computed
-- on request and cached per L.version.

local ADDON, ns = ...
local D, L = ns.Data, ns.Log

local I = {}
ns.Index = I

local npcs, objects, items = {}, {}, {}
local stamp           -- L.stamp when the lists were built
local learned         -- D.dropsVersion then
local offers = {}     -- "n12" / "i12" / "o:name" -> pickups (cache)
local offered         -- L.version when that cache was built

local function Add(list, key, tie)
	local ties = list[key]
	if not ties then
		ties = {}
		list[key] = ties
	end
	ties[#ties + 1] = tie
end

local function Tie(entry, kind, goal, index, item, chance)
	return { id = entry.id, title = entry.title, level = entry.level or 0, kind = kind, goal = goal, index = index,
		item = item, chance = chance, done = goal ~= nil and goal.finished or false }
end

local function ObjectKey(id)
	local name = D.Name("objects", id)
	return name and name ~= "" and name:lower() or nil
end

-- Adds a tie for everything that drops, sells or contains the item.
local function Sources(entry, goal, index, item)
	for _, source in ipairs(item.sources) do
		if source.kind == "n" then
			if not D.Dropless(source.id, item.id) then Add(npcs, source.id, Tie(entry, "drop", goal, index, item, source.chance)) end
		elseif source.kind == "v" then
			Add(npcs, source.id, Tie(entry, "sells", goal, index, item))
		elseif source.kind == "o" then
			local key = ObjectKey(source.id)
			if key then Add(objects, key, Tie(entry, "holds", goal, index, item)) end
		end
	end
	for _, id in ipairs(item.more or {}) do
		if not D.Dropless(id, item.id) then Add(npcs, id, Tie(entry, "drop", goal, index, item)) end
	end
end

local function Build()
	if stamp == L.stamp and learned == D.dropsVersion then return end
	stamp, learned = L.stamp, D.dropsVersion
	wipe(npcs)
	wipe(objects)
	wipe(items)
	for _, entry in ipairs(L.order) do
		local quest = D.Quest(entry.id)
		if quest and entry.complete then
			for _, token in ipairs(quest.ends) do
				if token.kind == "n" then
					Add(npcs, token.id, Tie(entry, "turnin"))
				elseif token.kind == "o" then
					local key = ObjectKey(token.id)
					if key then Add(objects, key, Tie(entry, "turnin")) end
				end
			end
		elseif quest and not entry.failed then
			for index, goal in ipairs(L.Goals(entry.id)) do
				for _, token in ipairs(goal.tokens) do
					if token.kind == "c" then
						Add(npcs, token.id, Tie(entry, "kill", goal, index))
					elseif token.kind == "k" then
						for _, id in ipairs(token.ids) do Add(npcs, id, Tie(entry, "kill", goal, index)) end
					elseif token.kind == "o" then
						local key = ObjectKey(token.id)
						if key then Add(objects, key, Tie(entry, "use", goal, index)) end
					else
						local item = D.Item(token.id)
						if item then
							Add(items, token.id, Tie(entry, token.kind == "s" and "needs" or "collect", goal, index, item))
							Sources(entry, goal, index, item)
						end
					end
				end
			end
		end
	end
end

-- The available quests among `ids`, as ties. inHand: they start from an item (L.CanStart).
local function Pickups(key, ids, inHand)
	if offered ~= L.version then
		offered = L.version
		wipe(offers)
	end
	local list = offers[key]
	if not list then
		list = {}
		for _, id in ipairs(ids or {}) do
			local quest = D.Quest(id)
			if quest and L.CanStart(quest, inHand) then
				list[#list + 1] = { id = id, title = quest.name, level = quest.level, kind = "pickup", quest = quest, done = false }
			end
		end
		offers[key] = list
	end
	return list
end

-- Creatures that drop or sell a quest-starting item (D.StartItem):
-- creature -> { { item, quests, from, chance } }. Built once.
local carriers
local function Carriers(id)
	if not carriers then
		carriers = {}
		for _, item in ipairs(D.StartItems()) do
			local start = D.StartItem(item)
			for _, source in ipairs(start.sources) do
				if source.kind ~= "o" then
					carriers[source.id] = carriers[source.id] or {}
					table.insert(carriers[source.id], { item = item, quests = start.quests, from = source.kind, chance = source.chance })
				end
			end
		end
	end
	return carriers[id]
end

-- Ties and pickups as one list, turn-ins first.
local ORDER = { turnin = 1, kill = 2, use = 2, drop = 3, holds = 3, collect = 3, needs = 4, sells = 5, pickup = 6 }
local function Joined(ties, pickups)
	if not ties and #pickups == 0 then return nil end
	local out = {}
	for _, tie in ipairs(ties or {}) do out[#out + 1] = tie end
	for _, tie in ipairs(pickups) do out[#out + 1] = tie end
	local place = {}
	for i, tie in ipairs(out) do place[tie] = i end
	table.sort(out, function(a, b)
		if ORDER[a.kind] ~= ORDER[b.kind] then return ORDER[a.kind] < ORDER[b.kind] end
		return place[a] < place[b]
	end)
	return out
end

function I.Npc(id)
	Build()
	local npc = D.Npc(id)
	local pickups = (npc and npc.gives and L.Friendly(npc)) and Pickups("n" .. id, npc.gives) or {}
	-- Quests starting from an item it drops or sells: pickups with item, from and chance set.
	local carries = Carriers(id)
	if carries then
		local all = {}
		for _, tie in ipairs(pickups) do all[#all + 1] = tie end
		for _, carry in ipairs(carries) do
			for _, tie in ipairs(Pickups("d" .. id .. ":" .. carry.item, carry.quests)) do
				tie.item, tie.from, tie.chance = D.Item(carry.item), carry.from, carry.chance
				all[#all + 1] = tie
			end
		end
		pickups = all
	end
	return Joined(npcs[id], pickups)
end

-- An object's ties, by its displayed name.
function I.Object(name)
	Build()
	local key = name:lower()
	local map = ns.World.map
	local here = "o:" .. (map or 0) .. ":" .. key
	if offered ~= L.version or not offers[here] then
		-- A name can match several objects: every one that starts a quest on this map counts.
		local ids = {}
		for _, quest in ipairs(map and L.StartsOn(map) or {}) do
			for _, token in ipairs(quest.starts) do
				if token.kind == "o" and ObjectKey(token.id) == key then ids[#ids + 1] = quest.id end
			end
		end
		Pickups(here, ids)
	end
	return Joined(objects[key], offers[here])
end

function I.Item(id)
	Build()
	local item = D.Item(id)
	local pickups = (item and item.begins) and Pickups("i" .. id, item.begins, true) or {}
	return Joined(items[id], pickups)
end

-- I.Quests(id, known): every quest the data ties a quest item to (counts it, needs it, gives
-- it to carry, or starts from it), with its state for this character:
--
--   { id, title, level, state, starts = true for the quest it starts, behind = true for one that is over
--     for you (done, dropped or outgrown) }
--
--   state  held      in the log               ready    in the log and finished
--          failed    in the log and failed
--          done      turned in              dropped  abandoned (L.Left)
--          open      none of those: not accepted yet, and worth doing
--          outgrown  not accepted, and it pays too little by now to be worth doing (L.Outgrown;
--                    never with low-level quests asked for)
--          far       not accepted, and more than REACH levels above the character (its own level, or
--                    the level it is given from)
--
-- Second result: true when every such quest is done, dropped or outgrown, so the item is a
-- leftover. A repeatable quest is never done. Only for items of class Questitem or that start a
-- quest, or when the caller already knows it is a quest item (`known`). Quests this character
-- can't do (faction, class, never offered, excluded by a done quest) are left out.
local BEHIND = { done = true, dropped = true, outgrown = true }
local REACH = 10   -- levels: a quest that far up is no reason to carry its item about yet

local function Standing(id)
	local entry, quest = L.entries[id], D.Quest(id)
	if entry then return (entry.complete and "ready") or (entry.failed and "failed") or "held", entry.title, entry.level end
	if not quest then return nil end
	local state
	if L.Done(id) and not quest.flags:find("r", 1, true) then
		state = "done"
	elseif L.Dropped(id) then
		state = "dropped"
	else
		if quest.flags:find("h", 1, true) or not L.ForMe(quest) then return nil end
		for _, other in ipairs(quest.exclusive or {}) do
			if L.Done(other) then return nil end
		end
		state = "open"
		if not ns.T.db.lowLevel and L.Outgrown(quest) then
			state = "outgrown"
		elseif math.max(quest.minLevel, quest.level) > L.Level() + REACH then
			state = "far"
		end
	end
	return state, quest.name, quest.level
end

function I.Quests(id, known)
	local item = D.Item(id)
	if not item or not (item.asks or item.begins) then return nil end
	if not known and not item.begins and select(6, C_Item.GetItemInfoInstant(id)) ~= Enum.ItemClass.Questitem then return nil end
	local out, seen, behind = {}, {}, true
	-- The quests it starts go first; they are usually in asks too.
	for pass = 1, 2 do
		local list = item.asks
		if pass == 1 then list = item.begins end
		for _, quest in ipairs(list or {}) do
			if not seen[quest] then
				seen[quest] = true
				local state, title, level = Standing(quest)
				if state then
					out[#out + 1] = { id = quest, title = title, level = level or 0, state = state, starts = pass == 1 or nil,
						behind = BEHIND[state] == true }
					behind = behind and BEHIND[state] == true
				end
			end
		end
	end
	if #out == 0 then return nil end
	return out, behind
end

-- The mark for a creature: "turnin", "goal" (an unfinished objective), "pickup", false when
-- its objectives are all finished, nil when no quest involves it.
function I.Mark(id)
	local ties = I.Npc(id)
	if not ties then return nil end
	local mark = false
	for _, tie in ipairs(ties) do
		if tie.kind == "turnin" then return "turnin" end
		if tie.kind == "pickup" then
			-- Not for a creature that only drops or sells a quest-starting item.
			if not tie.from then mark = mark or "pickup" end
		elseif not tie.done and tie.kind ~= "sells" then
			mark = "goal"
		end
	end
	return mark
end

-- Shared spawns: spots the server fills with one creature of a set or another (D.Npc's shares). Killing
-- one that nothing asks for makes room there for one that is asked for.

-- The tie of an open objective that counts or loots this creature, or nil.
local function Open(id)
	for _, tie in ipairs(I.Npc(id) or {}) do
		if not tie.done and (tie.kind == "kill" or tie.kind == "drop") then return tie end
	end
end

-- For a creature nothing open asks for: one it takes turns with that an open objective wants, and that
-- objective's tie. nil otherwise.
function I.Blocks(id)
	local npc = D.Npc(id)
	if not (npc and npc.shares) or Open(id) then return nil end
	for _, other in ipairs(npc.shares) do
		local tie = Open(other)
		local wanted = tie and D.Npc(other)
		if wanted then return wanted, tie end
	end
end

-- For a creature: those it takes turns with that nothing open asks for, or nil.
function I.Rivals(id)
	local npc = D.Npc(id)
	if not (npc and npc.shares) then return nil end
	local out
	for _, other in ipairs(npc.shares) do
		local rival = not Open(other) and D.Npc(other)
		if rival then
			out = out or {}
			out[#out + 1] = rival
		end
	end
	return out
end

-- Creatures by kind, as a line says them: "Stranglethorn Tigresses", "Skullsplitter Axe Throwers and Mystics"
-- (words the first one has are said once), "Blackrock Scouts, Sentries and others".
local KINDS = 2              -- kinds named before "and others"
function I.Kinds(npcs)
	local first = npcs[1] and npcs[1].name or ""
	local words = {}
	for word in first:gmatch("%S+") do words[#words + 1] = word end
	local out = {}
	for i = 1, math.min(#npcs, KINDS) do
		local name = npcs[i].name
		if i > 1 then
			-- (Not the whole name: a kind always keeps its last word.)
			local n = 1
			for word in name:gmatch("%S+") do
				if word ~= words[n] then break end
				n = n + 1
			end
			local rest = {}
			for word in name:gmatch("%S+") do rest[#rest + 1] = word end
			name = table.concat(rest, " ", math.min(n, #rest))
		end
		out[#out + 1] = Shy.Plural(name)
	end
	if #npcs > KINDS then return table.concat(out, ", ") .. " and others" end
	return table.concat(out, " and ")
end

-- The name of an item this vendor sells that a quest in the log still needs, or nil (Plates.lua).
function I.Sells(id)
	Build()
	for _, tie in ipairs(npcs[id] or {}) do
		if tie.kind == "sells" and not tie.done then return tie.item and tie.item.name or true end
	end
	return nil
end

-- Public, via Shy.addons.Quest: for the first unfinished objective that needs the item,
-- returns missing, quest title, have, need. nil when no quest in the log still needs it.
-- An uncounted item (kind "needs") reports 1 missing while none is in the bags.
function ns.T:Wanted(itemID)
	if type(itemID) ~= "number" then return nil end
	Build()
	for _, tie in ipairs(items[itemID] or {}) do
		if not tie.done then
			if tie.kind == "needs" then
				return 1, tie.title, 0, 1
			elseif tie.kind == "collect" then
				local goal = tie.goal
				local have, need = goal and goal.have or 0, goal and goal.need or 1
				if need > have then return need - have, tie.title, have, need end
			end
		end
	end
	return nil
end
