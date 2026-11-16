-- Quest items, the bank and the mailbox. A quest is handed in out of the bags alone, so an item is always one
-- of three things to your quests, and everything here goes by that one answer (Status):
--   now      to have with you: a quest in the log needs it, or the guide does before it is next by a bank
--   later    a quest will want it, and it can wait in the bank until then
--   over     no quest needs it any more
-- With a guide followed, when is read off its steps ahead (Way: LOOK of them, on into the guides after it,
-- once per place in the guide). With none, a quest in the log is now, one not taken that is worth doing is
-- later, and one handed in, let go of or outgrown is over (Index.lua). What a quest in the log gave to
-- carry (a powder to deliver: no objective counts it, no step names it) is now too, and known once it lies
-- in the bank or a letter (Given). From it:
--   take out   what is needed now, with too few in the bags and some in the bank or a letter. As the `bank`
--              and `mailbox` errands it goes first, and only then is a stop at all (Stop): at any distance
--              when what leads can't be done without it, or the road ahead needs it before the next bank and
--              it is found nowhere else; when getting it again would take longer than going for it (R.Travel
--              there and on, against R.EffortOf); when the player stands by the place and what leads is away
--              from it; and in passing. Otherwise it is no stop and no row (a route with no errand on it is
--              not built again for a fight): the hand-in's own row says where its things are, and "Take me
--              to" has the banker. What a quest of your own needs, that the guide never touches, makes no trip.
--   put away   what the bags hold that is needed later and only lies there till then (Stows): as an errand
--              only in passing a banker, never a trip.
--   clear out  what the bank holds that is over: quest items to take out and sell or drop.
-- Each is one move (Stash.Move), said in chat. The bank window has them as jobs to click (ShyBags; BankJobs);
-- as the bank opens, taking out is done for you and putting away only where asked for (settings; neither
-- with Shift held, as GuideBank.lua's lines, nor with the errand put away), tried again a moment on if the
-- game moved nothing. Putting in something needed now says so once. The bags are told how each item stands,
-- for their marks and their sort by type (Bags.lua), and an item's tooltip says where to take it out of.
--   What the bank holds: the game's own count, and what was seen in it at the last visit, kept for the
--     character (ns.char.banked: quest items only), since the game may not know the bank before it is
--     opened; until it has been read here once, what the bags window remembers of it. The mailbox the same
--     (ns.char.mailed, and the bags window's letters).
--   What it costs. The bank can't change while it is shut, so its counts are asked once per item and kept
--     until a bank event; only what is needed and in the bank (the ledger's `banked`, mostly nothing) is
--     counted again in the bags when they change. The way is read when the guide's place changes, the log's
--     needs when the log is read, an item's standing once until either changes, and the bags are walked for
--     what could be put away only by a banker. A walk asks nothing; with nothing of a quest's in the bank
--     the finder is a few comparisons.
--   /shyquest bank copies what it knows.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide
local UI = Shy.UI
local lib = G.lib
local Ids, Step, Wanted, Saved, Place, Applies = lib.Ids, lib.Step, lib.Wanted, lib.Saved, lib.Place, lib.Applies
local Side, Following = lib.Side, lib.Following

local Stash = {}
ns.Stash = Stash

T.defaults.stash = {
	take = true,             -- a banker as a stop for what a quest needs out of the bank
	away = true,             -- and, in passing one, for what the bags hold that can wait there
	auto = true,             -- as the bank opens, what this outing needs is taken out for you
	autoAway = false,        -- ... and what can wait is put away for you
}

local LOOK = 200             -- the guide's steps read ahead, at most
local HOPS = 3               -- guides after this one read on into
local BY_BANK = 500          -- yards: a step this near a banker has the guide by a bank
local AWHILE = 30            -- steps: nothing needed sooner than this is put away
local NEAR = 300             -- yards: this near a banker, what could be put away is offered
local WORTH = 400            -- yards of walk a banker may add, for what is to take out
local AGAIN = 30             -- seconds a weighing of the bank against gathering stands
local AT_BANK = 20           -- seconds the banker takes
local TOWN = { bank = 600, mail = 300, box = 250 }   -- yards: by a banker or a mailbox, as near as leaving it matters;
                             -- and how near a friendly innkeeper or banker a mailbox is one of your own towns'
local FAR = math.huge        -- needed farther on than the guide was read
local NONE = {}

-- Bankers

-- Every friendly banker's place: { npc, map, x, y, continent, north, west }; and the maps that have one.
local bankers, bankMaps, bankersFor
local stood = setmetatable({}, { __mode = "k" })   -- a guide's step -> where it stands (Stands)
local function Bankers()
	local side = L.Side()
	if bankersFor ~= side then
		bankers, bankMaps, bankersFor = {}, {}, side
		wipe(stood)
		for _, id in ipairs(D.Town("bank")) do
			local npc = D.Npc(id)
			for _, place in ipairs(npc and L.Friendly(npc) and npc.places or NONE) do
				for i = 1, place.dungeon and 0 or #place.points, 2 do
					local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
					if north then
						bankMaps[place.map] = true
						bankers[#bankers + 1] = { npc = npc, map = place.map, x = place.points[i], y = place.points[i + 1],
							continent = continent, north = north, west = west }
					end
				end
			end
		end
	end
	return bankers, bankMaps
end

-- Every mailbox in a town of your own side: { map, x, y, continent, north, west }. A mailbox is an object and
-- has no side, so it counts where a friendly innkeeper or banker stands within TOWN.box yards of it.
local boxes, boxesFor
local function Boxes()
	local side = L.Side()
	if boxesFor ~= side then
		boxes, boxesFor = {}, side
		local friends = {}
		for _, kind in ipairs({ "inn", "bank" }) do
			for _, id in ipairs(D.Town(kind)) do
				local npc = D.Npc(id)
				for _, place in ipairs(npc and L.Friendly(npc) and npc.places or NONE) do
					for i = 1, place.dungeon and 0 or #place.points, 2 do
						local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
						if north then friends[#friends + 1] = { continent, north, west } end
					end
				end
			end
		end
		for _, id in ipairs(D.Town("mail")) do
			local object = D.Object(id)
			for _, place in ipairs(object and object.places or NONE) do
				for i = 1, place.dungeon and 0 or #place.points, 2 do
					local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
					for _, friend in ipairs(north and friends or NONE) do
						if friend[1] == continent and W.Between(north, west, friend[2], friend[3]) <= TOWN.box then
							boxes[#boxes + 1] = { map = place.map, x = place.points[i], y = place.points[i + 1], continent = continent,
								north = north, west = west }
							break
						end
					end
				end
			end
		end
	end
	return boxes
end

-- The nearest of such a list on the player's continent, and how far (straight).
local function NearestOf(list)
	if not W.Known() then return nil end
	local best, least
	for _, at in ipairs(list) do
		if at.continent == W.continent then
			local yards = W.Between(W.north, W.west, at.north, at.west)
			if not least or yards < least then best, least = at, yards end
		end
	end
	return best, least
end

local function Nearest()
	return NearestOf(Bankers())
end
Stash.Banker = Nearest

-- The guide's way ahead

-- Where a step stands: by a bank, away from one, or nowhere (it has no place).
local BY, AWAY, NOWHERE = 1, 2, 3
local function Stands(step)
	local where = stood[step]
	if where then return where end
	where = NOWHERE
	for _, element in ipairs(step.elements) do
		local at = element.command == "goto" and Place(element)
		if at and at.north then
			where = AWAY
			for _, banker in ipairs(Bankers()) do
				if banker.continent == at.continent and W.Between(at.north, at.west, banker.north, banker.west) <= BY_BANK then
					stood[step] = BY
					return BY
				end
			end
		end
	end
	stood[step] = where
	return where
end

-- What a step asks to be in the bags: add(item, quest, count) for each. A quest's hand-in asks for all it
-- counts or carries; an objective for what it counts and what the quest carries; a collect line for its item.
local READ = { collect = true, complete = true, turnin = true }
local function Read(step, add)
	for _, element in ipairs(step.elements) do
		local command = element.command
		if READ[command] and (not element.cond or Applies(element.cond)) then
			local ids = Ids(element)
			if command == "collect" then
				if ids[1] and ids[1] > 0 then add(ids[1], ids[3] and ids[3] > 0 and ids[3] or nil, ids[2]) end
			elseif ids[1] and ids[1] > 0 then
				local quest = ids[1]
				local counts = command == "complete" and element.counts
				if counts and counts.kind == "i" then add(counts.id, quest) end
				local data = D.Quest(quest)
				for _, token in ipairs(data and data.goals or NONE) do
					if token.kind == "s" or (token.kind == "i" and command == "turnin") then add(token.id, quest) end
				end
			end
		end
	end
end

-- What a step is to the way, worked out once per step: { key, wanted, side, then three numbers a thing it
-- asks for: item, quest (false: none), count (false: not said) }. `key` says for whom: it moves on with the
-- character's level and the settings, which decide what of a step applies (Key).
local applied = 0
local facts = setmetatable({}, { __mode = "k" })
local function Key()
	return applied * 1000 + L.Level()
end
local function Facts(step, key)
	local fact = facts[step]
	if fact and fact.key == key then return fact end
	fact = { key = key, wanted = Wanted(step) }
	if fact.wanted then
		fact.side = Side(step) and true or false
		Read(step, function(item, quest, count)
			local n = #fact
			fact[n + 1], fact[n + 2], fact[n + 3] = item, quest or false, count or false
		end)
		-- (The quests it hands in: what one of them gave to carry is named by no objective.)
		for _, element in ipairs(step.elements) do
			local quest = element.command == "turnin" and (not element.cond or Applies(element.cond)) and Ids(element)[1]
			if quest and quest > 0 then
				fact.hands = fact.hands or {}
				fact.hands[#fact.hands + 1] = quest
			end
		end
	end
	facts[step] = fact
	return fact
end

-- The same for a live step, leaving out a quest that is handed in: add(item, quest, count) for each.
local function Asks(step, add)
	local fact = Facts(step, Key())
	for i = 1, #fact, 3 do
		local quest = fact[i + 1]
		if not (quest and L.Done(quest)) then add(fact[i], quest or nil, fact[i + 2] or nil) end
	end
end

-- The way: { needs = item -> { item, at = how many steps on it is first needed, quest = the quest that is
-- for, count = how many a collect line asks, quests }, bank = how many steps on the guide is next by a bank
-- (nil: not in what was read), steps, hands = quest -> whether the guide hands it in at all (as asked),
-- turnins = quest -> how many steps on the way hands it in }.
-- nil with no guide followed. Read again when the guide's place, the log's quests, the character's level
-- or a setting changes (a walk over what Facts keeps of each step); its needs are never changed after.
local way
local function Way()
	local guide, main = G.current, G.active and G.active[1]
	if not (ns.Following() and guide and main and not main.side and Side and Following) then
		way = nil
		return nil
	end
	local saved = Saved(guide)
	local from = main.first and saved.floor or main.step.index
	if way and way.guide == guide and way.from == from and way.version == L.version and way.applied == applied then return way end
	way = { guide = guide, from = from, version = L.version, applied = applied, needs = {}, hands = {}, turnins = {} }
	local needs, turnins, key = way.needs, way.turnins, Key()
	local done, dropped = saved.done, saved.dropped
	local ordinal, left, hops = 0, false, 0
	while guide and ordinal < LOOK do
		for index = from, #guide.raw do
			local step = Step(guide, index)
			local fact = step and Facts(step, key)
			if fact and fact.wanted and not (done and done[index]) then
				if not fact.side then
					-- (By a bank again once the way has left one: the bank the player may stand at now is no "next".)
					local where = Stands(step)
					if where == AWAY then
						left = true
					elseif where == BY and left and not way.bank then
						way.bank = ordinal
					end
				end
				for i = 1, #fact, 3 do
					local item, quest = fact[i], fact[i + 1]
					-- (The first step that asks for it says when; not for a quest handed in, or let go of in this guide.)
					if not needs[item] and not (quest and (L.Done(quest) or (dropped and dropped[quest]))) then
						needs[item] = { item = item, at = ordinal, quest = quest or nil, count = fact[i + 2] or nil,
							quests = quest and { [quest] = true } or NONE }
					end
				end
				for _, quest in ipairs(fact.hands or NONE) do
					turnins[quest] = turnins[quest] or ordinal
				end
				if not fact.side then
					ordinal = ordinal + 1
					if ordinal >= LOOK then break end
				end
			end
		end
		hops = hops + 1
		guide = hops <= HOPS and Following(guide) or nil
		done, dropped, from = nil, nil, 1
	end
	way.steps = ordinal
	return way
end

-- Needed before the guide is next by a bank (with no guide: now, as everything is).
local function Due(need, road)
	return need.at ~= FAR and (not (road and road.bank) or need.at < road.bank)
end

-- To have with you: due, or needed so soon after the next bank that putting it away is two moves for nothing.
-- What isn't can wait in the bank. One rule for the marks, what is taken out and what is put away.
local function With(need, road)
	return Due(need, road) or need.at < AWHILE
end

local function Sooner(a, b)
	if a.at ~= b.at then return a.at < b.at end
	return a.item < b.item
end

-- What is held

-- What the bank holds of an item: the game's count, or what was seen there at the last visit. Asked once
-- per item until a bank event (bankEpoch moves on); bagEpoch moves on whenever the bags change.
local banks, bankEpoch, bagEpoch = {}, 0, 0

-- What the bags window remembers of a place of this character's ("Banked", "Mailed"): item -> how many.
local function Seen(what)
	local bags = Shy.addons.Bags
	return bags and bags[what] and bags[what](bags) or NONE
end

-- (Until the bank has been read here once, what the bags window remembers of it stands in for that.)
local function Banked(item)
	local count = banks[item]
	if not count then
		local kept = ns.char.banked or Seen("Banked")
		count = math.max(C_Item.GetItemCount(item, true) - C_Item.GetItemCount(item), kept[item] or 0, 0)
		banks[item] = count
	end
	return count
end

-- The bank as it stands, while it is open: the quest items in it, kept for the character.
local function ReadBank()
	local kept = {}
	for _, tab in ipairs(C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character) or NONE) do
		for slot = 1, C_Container.GetContainerNumSlots(tab) or 0 do
			local id = C_Container.GetContainerItemID(tab, slot)
			if id and not issecretvalue(id) then
				local item = D.Item(id)
				if item and (item.asks or item.begins) then
					local info = C_Container.GetContainerItemInfo(tab, slot)
					kept[id] = (kept[id] or 0) + (info and info.stackCount or 1)
				end
			end
		end
	end
	ns.char.banked = kept
end

-- What the mailbox holds of an item: what was read in it when it was last open (ns.char.mailed), or what
-- the bags window remembers of it (letters another of your characters sent among them), whichever is more.
-- Kept with the bank's counts, until either changes.
local mails = {}
local function Mailed(item)
	local count = mails[item]
	if not count then
		count = math.max(ns.char.mailed and ns.char.mailed[item] or 0, Seen("Mailed")[item] or 0)
		mails[item] = count
	end
	return count
end

-- What the bank or the mailbox holds that a quest in the log gave you to carry: a powder to deliver, a note
-- to show. No objective counts it and no step names it, so nothing else here would know it is needed.
-- item -> the quest (false: none). Looked up again when the bank, the mailbox or the log's quests change.
local CARRIED = { held = true, ready = true, failed = true }
local given, givenAt, givenLog
local function Given()
	if givenAt == bankEpoch and givenLog == L.version then return given end
	given, givenAt, givenLog = {}, bankEpoch, L.version
	for _, held in ipairs({ ns.char.banked or Seen("Banked"), ns.char.mailed or NONE, Seen("Mailed") }) do
		for item in pairs(held) do
			if given[item] == nil then
				given[item] = false
				for _, quest in ipairs(ns.Index.Quests(item, true) or NONE) do
					if CARRIED[quest.state] then
						given[item] = quest.id
						break
					end
				end
			end
		end
	end
	return given
end

-- The inbox as it stands, while the mailbox is open: the quest items in its letters, kept for the character.
-- Not what a letter asks gold for.
local function ReadMail()
	local kept = {}
	for index = 1, GetInboxNumItems() or 0 do
		local _, _, _, _, _, cod, _, count = GetInboxHeaderInfo(index)
		if count and count > 0 and not (cod and cod > 0) then
			for slot = 1, ATTACHMENTS_MAX_RECEIVE do
				local _, id, _, stack = GetInboxItem(index, slot)
				if id and not issecretvalue(id) then
					local item = D.Item(id)
					if item and (item.asks or item.begins) then kept[id] = (kept[id] or 0) + (stack or 1) end
				end
			end
		end
	end
	ns.char.mailed = kept
end

-- What first aid is made of stays in the bags (Aid.lua weighs it).
local mats
local function Mat(item)
	if not mats then
		mats = {}
		for _, text in pairs(ns.data.aid or NONE) do
			for id in (text:match("[^%^]*$") or ""):gmatch("(%d+):%d+") do mats[tonumber(id)] = true end
		end
	end
	return mats[item] == true
end

-- The ledger

-- The way's needs to have with you that the bank or the mailbox holds, soonest first: until the way or either changes.
local function WayBanked(road)
	if road.bankedAt ~= bankEpoch then
		local banked = {}
		for item, need in pairs(road.needs) do
			if With(need, road) and (Banked(item) > 0 or Mailed(item) > 0) then banked[#banked + 1] = need end
		end
		table.sort(banked, Sooner)
		road.bankedAt, road.banked = bankEpoch, banked
	end
	return road.banked
end

-- (While a ledger is written: its own needs, and the way they lie over.)
local over, under

-- A need of the log's or of a live step, `at` steps on: over the way's need for the item, when it has one.
local function Merge(item, quest, count, at)
	local need = over[item]
	if not need then
		local base = under and under.needs[item]
		need = { item = item, at = base and base.at or at, quest = base and base.quest or quest, count = base and base.count, quests = {} }
		for known in pairs(base and base.quests or NONE) do need.quests[known] = true end
		over[item] = need
	end
	if at < need.at then need.at, need.quest = at, quest or need.quest end
	if count and count > (need.count or 0) then need.count = count end
	if quest then need.quests[quest] = true end
end

local function Now(item, quest, count)
	Merge(item, quest, count, 0)
end

-- The ledger: { way, over = item -> need for what the log's quests and the live steps ask (each over the
-- way's need for it), banked = the needs to have with you that the bank or the mailbox holds some of, soonest
-- first }. Written again when the log is read, the way or the live steps change, or the bank or the mailbox does. `wrote` counts the times
-- what is needed at all came out different (Stash.Stamp).
local ledger
local wrote = 0
local function Ledger()
	if ledger and ledger.stamp == L.stamp and ledger.guide == G.stamp and ledger.bank == bankEpoch and ledger.applied == applied then
		return ledger
	end
	local road = Way()
	local live = road and #G.active or 0
	if ledger and ledger.stamp == L.stamp and ledger.way == road and ledger.live == live and ledger.bank == bankEpoch
		and ledger.applied == applied then
		ledger.guide = G.stamp
		return ledger
	end
	over, under = {}, road
	-- (The live steps, a side step from before the place among them: needed now.)
	for _, entry in ipairs(road and G.active or NONE) do
		if entry.step then Asks(entry.step, Now) end
	end
	for _, entry in ipairs(L.order) do
		if not entry.failed then
			local far
			for _, goal in ipairs(L.Goals(entry.id)) do
				for _, token in ipairs(goal.tokens) do
					if token.kind == "i" or token.kind == "s" then
						-- (When the way is next about this quest's item; a quest it never touches: now, or far on
						-- where the guide hands it in past what was read.)
						local base = road and road.needs[token.id]
						local at = base and base.quests[entry.id] and base.at
						if not at then
							if far == nil and road then
								-- (Asked of the guide once per quest while the way stands.)
								far = road.hands[entry.id]
								if far == nil then
									far = G.HandsIn(entry.id)
									road.hands[entry.id] = far
								end
							end
							at = far and FAR or 0
						end
						Merge(token.id, entry.id, token.kind == "i" and goal.need or 1, at)
					end
				end
			end
		end
	end
	-- (What a quest in the log gave to carry, lying in the bank or the mailbox: needed now, as much as lies there.)
	for item, quest in pairs(Given()) do
		if quest and not over[item] then Merge(item, quest, nil, 0) end
	end
	local banked = {}
	for item, need in pairs(over) do
		if With(need, road) and (Banked(item) > 0 or Mailed(item) > 0) then banked[#banked + 1] = need end
	end
	for _, need in ipairs(road and WayBanked(road) or NONE) do
		if not over[need.item] then banked[#banked + 1] = need end
	end
	if #banked > 1 then table.sort(banked, Sooner) end
	-- (What is needed at all changed: another way, or another item among the log's.)
	local same = ledger ~= nil and ledger.way == road
	for item in pairs(same and over or NONE) do
		if not ledger.over[item] then same = false end
	end
	for item in pairs(same and ledger.over or NONE) do
		if not over[item] then same = false end
	end
	if not same then wrote = wrote + 1 end
	ledger = { stamp = L.stamp, guide = G.stamp, bank = bankEpoch, applied = applied, way = road, live = live, over = over,
		banked = banked }
	over, under = nil, nil
	return ledger
end

-- What to fetch: { take = rows { item, count, quest, at } out of the bank, soonest first; quests = quest ->
-- its rows; post, postQuests = the same out of the mailbox; way }. Each place offers what it holds of what
-- the bags are short of, so once one is taken from, the other's row shrinks or goes. Counted again in the
-- bags when they change, and only what the ledger has held elsewhere.
local plan
local function Plan()
	local book = Ledger()
	if plan and plan.ledger == book and plan.bags == bagEpoch then return plan end
	local take, quests, post, postQuests = NONE, NONE, NONE, NONE
	local function Row(need, count, rows, by)
		local row = { item = need.item, count = count, quest = need.quest, at = need.at }
		rows[#rows + 1] = row
		for quest in pairs(need.quests) do
			by[quest] = by[quest] or {}
			table.insert(by[quest], row)
		end
	end
	for _, need in ipairs(book.banked) do
		local bank, mail = Banked(need.item), Mailed(need.item)
		local short = need.count and need.count - C_Item.GetItemCount(need.item) or math.max(bank, mail)
		if short > 0 and bank > 0 then
			if take == NONE then take, quests = {}, {} end
			Row(need, math.min(short, bank), take, quests)
		end
		if short > 0 and mail > 0 then
			if post == NONE then post, postQuests = {}, {} end
			Row(need, math.min(short, mail), post, postQuests)
		end
	end
	if plan and take == NONE and post == NONE and plan.take == NONE and plan.post == NONE then
		plan.ledger, plan.bags, plan.way = book, bagEpoch, book.way
	else
		plan = { ledger = book, bags = bagEpoch, take = take, quests = quests, post = post, postQuests = postQuests, way = book.way }
	end
	return plan
end
Stash.Plan = Plan

-- Every need, the log's over the way's: item -> need. For what is seldom asked (the report).
local function Needs()
	local book = Ledger()
	local needs = {}
	for item, need in pairs(book.way and book.way.needs or NONE) do needs[item] = need end
	for item, need in pairs(book.over) do needs[item] = need end
	return needs, book
end
Stash.Needs = Needs

-- How an item stands
--   "now"     to have with you: a quest in the log needs it, or the guide does before it is next by a bank
--   "later"   a quest will want it and it can wait in the bank: the guide needs it after that, or (no step
--             of the way ahead asking) a quest not taken that is still worth doing does (Index.lua's
--             "open"; one the guide itself does counts though outgrown or levels off)
--   "over"    every quest it was for is handed in, let go of or not worth doing
--   nil       no quest's
-- The one answer the bags' marks, what they never offer to sell, and what is put away all go by. Worked
-- out once per item, until what is needed or the log's quests change. Second result: the quest it is for.
-- Third: how soon that quest comes, as one number to put things in order by (lower: sooner): the guide's
-- steps until then, the quest's level, then the quest itself, so one quest's things lie together.
local status, because, soon, statusAt = {}, {}, {}, {}
local SOON = { step = 2 ^ 28, level = 2 ^ 20, levels = 255 }

local function Soon(at, quest)
	local data = quest and D.Quest(quest)
	local level = math.max(0, math.min(data and data.level or 0, SOON.levels))
	return math.min(at or FAR, LOOK + 1) * SOON.step + level * SOON.level + (quest or 0) % SOON.level
end

local function Judge(item, book)
	local need = book.over[item] or (book.way and book.way.needs[item])
	if need then return With(need, book.way) and "now" or "later", need.quest, need.at end
	local quests, behind = ns.Index.Quests(item, true)
	local ahead
	for _, quest in ipairs(quests or NONE) do
		local state = quest.state
		-- (In the log, and no step or objective names the item: one the quest gave to carry. With you.)
		if CARRIED[state] then return "now", quest.id, 0 end
		if not ahead and (state == "open" or ((state == "outgrown" or state == "far") and book.way and G.Uses(quest.id))) then
			ahead = quest.id
		end
	end
	if ahead then return "later", ahead end
	if behind then return "over" end
end

local function Status(item)
	if not ns.char then return nil end
	local book = Ledger()
	if statusAt[1] ~= wrote or statusAt[2] ~= L.version or statusAt[3] ~= applied then
		wipe(status)
		wipe(because)
		wipe(soon)
		statusAt[1], statusAt[2], statusAt[3] = wrote, L.version, applied
	end
	local known = status[item]
	if known == nil then
		local quest, at
		known, quest, at = Judge(item, book)
		known = known or false
		status[item], because[item] = known, quest
		if known == "now" or known == "later" then soon[item] = Soon(at, quest) end
	end
	return known or nil, because[item], soon[item]
end
Stash.Status = Status

-- How many of an item there are to take out of the bank, and out of the mailbox: the plan's rows for it.
function Stash.Fetch(item)
	if not ns.char then return 0, 0 end
	local found = Plan()
	local bank, mail = 0, 0
	for _, row in ipairs(found.take) do
		if row.item == item then bank = row.count end
	end
	for _, row in ipairs(found.post) do
		if row.item == item then mail = row.count end
	end
	return bank, mail
end

-- Changes when an item's standing may have: the bags' marks are looked at again then (Bags.lua).
function Stash.Stamp()
	Ledger()
	return (wrote % 4096) * 16777216 + (L.version % 4096) * 4096 + applied % 4096
end

-- Containers walked: item -> how many, of what a test says yes to. Only at a banker.
local function Walk(containers, test)
	local found = {}
	for _, bag in ipairs(containers) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and not issecretvalue(id) and (found[id] or test(id, bag, slot)) then
				local info = C_Container.GetContainerItemInfo(bag, slot)
				found[id] = (found[id] or 0) + (info and info.stackCount or 1)
			end
		end
	end
	return found
end

local function Carried()
	local bags = {}
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do bags[#bags + 1] = bag end
	return bags
end

-- What moved or is to move, as rows { item, count, quest, at } in the order of their items.
local function Rows(found)
	local out = {}
	for item, count in pairs(found) do
		local _, quest = Status(item)
		out[#out + 1] = { item = item, count = count, quest = quest, at = 0 }
	end
	table.sort(out, Sooner)
	return out
end

-- What is put away is what only lies in the bags till its quest: a trade good, a quest item, an odd thing.
-- Never what the character uses meanwhile (food, potions, gear, ammunition, reagents), whatever quest wants
-- some of it later, nor first aid's makings.
local function Stows(item)
	local class = select(6, C_Item.GetItemInfoInstant(item))
	local kinds = Enum.ItemClass
	return (class == kinds.Tradegoods or class == kinds.Questitem or class == kinds.Miscellaneous or class == kinds.Gem) and not Mat(item)
end

-- What could be put away: what the bags hold that can wait in the bank (and Stows). Rows as Plan's. The
-- bags are walked for it, so it is asked only by a banker; kept until they or the standings change.
local later
local function Later()
	local stamp = Stash.Stamp()
	if later and later.stamp == stamp and later.bags == bagEpoch then return later.rows end
	local rows = Rows(Walk(Carried(), function(item)
		return Status(item) == "later" and Stows(item)
	end))
	later = { stamp = stamp, bags = bagEpoch, rows = rows }
	return rows
end
Stash.Later = Later

-- What the bank holds that is over: quest items (the game's word for them) no quest needs any more, to
-- take out and sell or drop. Rows as Plan's. Only while the bank is open.
local function Leftovers()
	return Rows(Walk(C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character) or NONE, function(item, bag, slot)
		if Status(item) ~= "over" then return false end
		local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
		return quest ~= nil and (quest.isQuestItem or quest.questID ~= nil) and true or false
	end))
end
Stash.Leftovers = Leftovers

-- Words

local function ItemName(id)
	return C_Item.GetItemNameByID(id) or D.Name("items", id) or "item"
end

local function QuestName(id)
	local entry, quest = L.entries[id], D.Quest(id)
	return entry and entry.title or quest and quest.name or "a quest"
end

local function Counted(row)
	return ("%d %s"):format(row.count, ItemName(row.item))
end

-- "4 Goretusk Liver, 3 Okra and 2 more"
local function Listed(rows, most)
	local out = {}
	for i = 1, math.min(#rows, most or 3) do out[i] = Counted(rows[i]) end
	local text = table.concat(out, ", ")
	if #rows > #out then text = ("%s and %d more"):format(text, #rows - #out) end
	return text
end

local function Them(rows)
	return (#rows == 1 and rows[1].count == 1) and "it" or "them"
end

-- The quest some rows are for by name, "3 quests" for several, nil for none (a collect line of no quest).
local function For(rows)
	local seen, count, one = {}, 0, nil
	for _, row in ipairs(rows) do
		if row.quest and not seen[row.quest] then seen[row.quest], count, one = true, count + 1, row.quest end
	end
	if count == 1 then return QuestName(one) end
	return count > 1 and ("%d quests"):format(count) or nil
end

-- A stop's title: the place, then what there is to do there, short enough for the card to show whole
-- (FITS letters): the one item by name where that fits, a count where it doesn't.
local FITS = 24
local SHOWN = { take = 3, put = 2 }   -- items the card's lead names of each list, before "and n more"
local function Title(name, take, put)
	if #take > 0 and #put > 0 then return ("%s: take %d, put away %d"):format(name, #take, #put) end
	local rows, verb, things = take, "", "quest item"
	if #take == 0 then rows, verb, things = put, "put away ", "" end
	local one = #rows == 1 and ("%s: %s%s"):format(name, verb, ItemName(rows[1].item))
	if one and #one <= FITS then return one end
	if things == "" then return ("%s: put away %d"):format(name, #rows) end
	return ("%s: %d %s%s"):format(name, #rows, things, #rows == 1 and "" or "s")
end

-- The errands

-- Nothing drops, sells or holds it: what is put by is all there is.
local function Unfound(item)
	local record = D.Item(item)
	return not record or (#record.sources == 0 and not record.more)
end

-- What leads can't be done without what a place holds (`rows`, and by quest `quests`): the quest it hands in
-- (or works on, for an item found nowhere else), true for a step that counts the item itself, nil when it can.
local function Blocked(lead, rows, quests)
	if not lead then return nil end
	for _, action in ipairs(lead.actions or NONE) do
		local its = quests[action.id]
		if its and action.kind == "turnin" then return action.id end
		for _, row in ipairs(action.kind == "goal" and its or NONE) do
			if Unfound(row.item) then return action.id end
		end
	end
	local step = lead.kind == "guide" and lead.view and lead.view.step
	for _, element in ipairs(step and step.elements or NONE) do
		if element.command == "collect" then
			local item = Ids(element)[1]
			for _, row in ipairs(rows) do
				if row.item == item then return row.quest or true end
			end
		end
	end
end

-- What a place holds that the road ahead can't do without, whatever leads now: the guide's way asks for the
-- item, or hands its quest in, before it is next by a bank.
local function Ahead(rows, road)
	local out = NONE
	for _, row in ipairs(road and rows or NONE) do
		local hand = row.quest and road.turnins[row.quest]
		if (road.needs[row.item] and Due(row, road)) or (hand and (not road.bank or hand < road.bank)) then
			if out == NONE then out = {} end
			out[#out + 1] = row
		end
	end
	return out
end

-- Something of them is found nowhere else: it is fetched, there is no weighing it.
local function Must(rows)
	for _, row in ipairs(rows) do
		if Unfound(row.item) then return true end
	end
	return false
end

-- What can be got again, of what leads gathers and of what the road ahead needs (`ahead`): whether going
-- for what the place holds now costs less than getting it again. Weighed once per lead and rows (kept in
-- the place's `weighed`), and again after AGAIN seconds; `busy` (a fight, a flight, dead): nothing is weighed, and
-- what was found of the same lead and rows stands, so a stop that led does not come and go with every pull.
local function Quicker(lead, quests, ahead, at, weighed, busy)
	if not (lead and lead.north and lead.continent == at.continent) then return false end
	local rows, key, seen = {}, nil, {}
	local function Add(row)
		if seen[row.item] then return end
		seen[row.item] = true
		rows[#rows + 1] = row
		key = (key or R.Ident(lead)) .. ":" .. row.item .. "x" .. row.count
	end
	for _, action in ipairs(lead.actions or NONE) do
		for _, row in ipairs(action.kind == "goal" and quests[action.id] or NONE) do Add(row) end
	end
	for _, row in ipairs(ahead) do Add(row) end
	if not key then return false end
	if weighed.key == key and (busy or GetTime() - weighed.at < AGAIN) then return weighed.yes end
	if busy then return false end
	local saved = 0
	for _, row in ipairs(rows) do saved = saved + R.EffortOf(row.item, row.count) end
	local there = R.Travel(W.continent, W.north, W.west, at.north, at.west)
	local on = R.Travel(at.continent, at.north, at.west, lead.north, lead.west)
	local straight = R.Travel(W.continent, W.north, W.west, lead.north, lead.west)
	weighed.key, weighed.at, weighed.yes = key, GetTime(), there + on - straight + AT_BANK < saved
	return weighed.yes
end

-- About to leave it behind: the player is by the place (within `town` yards of it) and what leads is not.
-- What is needed with you is fetched before that step, not found missing a zone on.
local function Leaving(lead, at, yards, town)
	if yards > town or not (lead and lead.north) then return false end
	return lead.continent ~= at.continent or W.Between(lead.north, lead.west, at.north, at.west) > town
end

local open = false           -- the bank is showing
local off = {}               -- "Not now": items left where they are until the bank or the mailbox is next opened

-- The rows not put off (all of them where `all`).
local function Still(rows, all)
	if all or next(off) == nil then return rows end
	local out = {}
	for _, row in ipairs(rows) do
		if not off[row.item] then out[#out + 1] = row end
	end
	return out
end

-- Where quest items are fetched from: the bank (its banker) and the mailbox.
local PLACES = {
	bank = { errand = "bank", mark = "bank", name = "Bank", held = "IN YOUR BANK", strip = "In your bank", note = "In your bank: %s",
		next = "bank", town = TOWN.bank, weighed = { at = 0, yes = false } },
	mail = { errand = "mailbox", mark = "mail", name = "Mailbox", held = "IN YOUR MAILBOX", strip = "In your mailbox",
		note = "In your mailbox: %s", next = "bank or mailbox", town = TOWN.mail, weighed = { at = 0, yes = false } },
}

-- The stop at a place (R.AddErrand's), or nil. rows, quests: what it holds that is needed with you; put: what
-- could be put away there (the bank alone); road: the guide's way (nil: none followed). It goes first, and
-- only then is a stop at all, for one of these, the first that holds:
--   blocked   what leads can't be done without it: at any distance, fight or no fight, and not put off
--   ahead     the road ahead needs it before it is next by a bank, and it is found nowhere else: the same
--   quicker   what leads gathers, or the road ahead needs, can be got again, and going here now costs less
--   leaving   the player stands by the place and what leads is away from it
--   passing   it is near or on the way (R.Passing), or was asked for
-- The card's words are short enough to show whole: the title a count or one name (Title), the heading what
-- it is, the lines what to take, why, and that the bank does it for you.
local function Stop(place, lead, at, yards, rows, quests, put, road)
	local blocked = #rows > 0 and Blocked(lead, rows, quests) or nil
	local take = Still(rows, blocked ~= nil)
	put = put and Still(put) or NONE
	if #take == 0 and #put == 0 then return nil end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	local why = blocked and "blocked" or nil
	if not why and #take > 0 then
		local ahead = Ahead(take, road)
		if Must(ahead) then
			why = "ahead"
		elseif Quicker(lead, quests, ahead, at, place.weighed, busy) then
			why = "quicker"
		elseif not busy and Leaving(lead, at, yards, place.town) then
			why = "leaving"
		end
	end
	local passing = why ~= nil or (not busy and R.Passing(place.errand, at.map, at.x, at.y, lead, nil, #take > 0 and WORTH or nil))
	-- (Neither on the way nor what leads waits on: no stop, and no row to stand among the errands meanwhile.)
	if not passing then return nil end

	local it = Them(take)
	local lines = {}
	local who = at.npc and (at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name) or nil
	lines[1] = who
	-- (`pressing`: why it can't wait, said in the card's warning color.)
	local caption, pressing
	if #take > 0 then
		local quest = For(take)
		lines[#lines + 1] = ("Take out %s"):format(Listed(take))
		if why == "blocked" then
			pressing = type(blocked) == "number" and ("You can't hand in %s without %s"):format(QuestName(blocked), it)
				or ("This step needs %s"):format(it)
		elseif why == "ahead" then
			pressing = ("You need %s before your next %s"):format(it, place.next)
		elseif why == "quicker" then
			pressing = ("Quicker than getting %s again"):format(it)
		end
		lines[#lines + 1] = pressing or (quest and ("For %s"):format(quest)) or nil
		if #put > 0 then lines[#lines + 1] = ("Put away %s"):format(Listed(put)) end
		caption = ("%s  \194\183  %s"):format(#take == 1 and "QUEST ITEM" or "QUEST ITEMS", place.held)
	else
		lines[#lines + 1] = ("Put away %s"):format(Listed(put))
		lines[#lines + 1] = ("You won't need %s for a while"):format(Them(put))
		caption = "PUT AWAY  \194\183  NOT NEEDED YET"
	end
	-- (At the banker it may be done for you: said where it is.)
	local db = T.db.stash
	local auto = place == PLACES.bank and ((#take > 0 and db.auto) or (#take == 0 and db.autoAway))
	local done = auto and "Open your bank and it's done for you. Hold Shift to do it yourself." or nil
	if auto then lines[#lines + 1] = "Open your bank and it's done for you" end
	-- The card's lead, laid out (Card.lua asks only then): who to see, quiet;
	-- a row an item beside its picture, on a line of its own (a name and a quest side by side wrap), what
	-- to put away marked so; and what can't wait, in the warning color. Which quest each is for is on the
	-- hover. No taller than the plain lines were.
	local rows
	local function Rows()
		if rows then return rows end
		local C = UI.colors
		rows = {}
		if who then rows[1] = { text = who, color = C.dim } end
		local function Items(list, most, right)
			for i = 1, math.min(#list, most) do
				local row = list[i]
				rows[#rows + 1] = { icon = C_Item.GetItemIconByID(row.item), text = Counted(row), right = right, rightColor = C.dim }
			end
			if #list > most then rows[#rows + 1] = { text = ("and %d more"):format(#list - most), color = C.dim } end
		end
		Items(take, SHOWN.take)
		Items(put, SHOWN.put, "can wait")
		if pressing then rows[#rows + 1] = { text = pressing, color = why == "quicker" and C.dim or C.alert } end
		return rows
	end

	return {
		title = Title(place.name, take, put),
		lines = lines,
		rows = Rows,
		caption = caption,
		strip = #take > 0 and place.strip or nil,
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc and at.npc.name or place.name,
		mark = place.mark,
		first = true,
		-- Its hover: what to take out a quest at a time, the quest's name heading its things (side by side on
		-- one line they wrap), then what to put away, and last, quiet, that the bank does it for you.
		hover = function()
			local sections = {}
			local function Section(title, list, said)
				local out = {}
				for i, row in ipairs(list) do
					out[i] = { icon = C_Item.GetItemIconByID(row.item), glyph = "bag", text = Counted(row) }
				end
				if said then out[#out + 1] = { quiet = true, indent = 2, text = said } end
				sections[#sections + 1] = { title = title, rows = out }
			end
			local order, by = {}, {}
			for _, row in ipairs(take) do
				local quest = row.quest or false
				if not by[quest] then
					by[quest] = {}
					order[#order + 1] = quest
				end
				table.insert(by[quest], row)
			end
			for _, quest in ipairs(order) do
				Section(quest and ("Take out for %s"):format(QuestName(quest)) or "Take out", by[quest])
			end
			if #put > 0 then Section("Put away", put, "You'll be by a bank again before you need them.") end
			if done then
				local last = sections[#sections].rows
				last[#last + 1] = { quiet = true, indent = 2, text = done }
			end
			return sections
		end,
		tip = function(tip)
			for _, row in ipairs(take) do tip:AddLine(("Take out %s"):format(Counted(row)), 1, 1, 1) end
			for _, row in ipairs(put) do tip:AddLine(("Put away %s"):format(Counted(row)), 1, 1, 1) end
			if done then tip:AddLine(done, 0.6, 0.6, 0.6, true) end
		end,
		menu = function(root)
			root:CreateButton("Not now", function()
				for _, row in ipairs(take) do off[row.item] = true end
				for _, row in ipairs(put) do off[row.item] = true end
				ns.Refresh()
			end)
		end,
	}
end

-- The banker as a route errand, or nil.
local function Find(lead)
	local db = T.db.stash
	if not ns.char or not (db.take or db.away) then return nil end
	local found = Plan()
	local wanted = db.take and found.take or NONE
	-- (Nothing of a quest's in the bank, and no banker on this map to put anything away at: most of the time.)
	local _, maps = Bankers()
	local by = db.away and (open or maps[W.map]) or false
	if #wanted == 0 and not by then return nil end
	local at, yards = Nearest()
	if not at then return nil end
	return Stop(PLACES.bank, lead, at, yards, wanted, found.quests, by and (open or yards <= NEAR) and Later() or nil, found.way)
end
Stash.Find = Find

-- The nearest mailbox of your own towns as a route errand, or nil: for what a letter holds that is needed
-- with you. Nothing is put away there.
local function FindMail(lead)
	if not ns.char or not T.db.stash.take then return nil end
	local found = Plan()
	if #found.post == 0 then return nil end
	local at, yards = NearestOf(Boxes())
	if not at then return nil end
	return Stop(PLACES.mail, lead, at, yards, found.post, found.postQuests, nil, found.way)
end
Stash.FindMail = FindMail

-- The card's note under a hand-in whose items are in the bank or the mailbox (ns.cardNotes), with the errand
-- off or not.
local function Note(stop)
	if stop.kind == "errand" or not ns.char or not T.db.stash.take then return nil end
	local found
	for _, action in ipairs(stop.view and stop.view.actions or stop.actions or NONE) do
		if not action.done and action.kind == "turnin" then
			found = found or Plan()
			local rows = found.quests[action.id]
			if rows then return PLACES.bank.note:format(Listed(rows)), nil, "bank" end
			rows = found.postQuests[action.id]
			if rows then return PLACES.mail.note:format(Listed(rows)), nil, "mail" end
		end
	end
end
Stash.Note = Note

-- How an item stands, for whoever draws it elsewhere (ShySkin's mailbox): Status's word, with "over" only for
-- what the game files as a quest item (water an outgrown quest once counted is still water).
function T:ItemStanding(item)
	if type(item) ~= "number" then return nil end
	local how, quest = Status(item)
	if how == "over" and select(6, C_Item.GetItemInfoInstant(item)) ~= Enum.ItemClass.Questitem then return nil end
	return how, quest
end

-- At the bank

local function Room()
	if ns.Bags and ns.Bags.Free then return (ns.Bags.Free()) end
	local free = 0
	for bag = Enum.BagIndex.Backpack, NUM_BAG_SLOTS do
		local slots, family = C_Container.GetContainerNumFreeSlots(bag)
		if family == 0 then free = free + (slots or 0) end
	end
	return free
end

-- Moves whole stacks of the rows' items out of the bank until each has its count, a free slot a stack.
-- Returns what moved (item -> count), and whether the bags ran out of room.
local function TakeOut(rows)
	local want, moved, full = {}, {}, false
	if #rows == 0 then return moved, full end
	for _, row in ipairs(rows) do want[row.item] = row.count end
	local room = Room()
	for _, tab in ipairs(C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character) or NONE) do
		for slot = 1, C_Container.GetContainerNumSlots(tab) or 0 do
			local id = C_Container.GetContainerItemID(tab, slot)
			if id and not issecretvalue(id) and (want[id] or 0) > 0 then
				local info = C_Container.GetContainerItemInfo(tab, slot)
				if room <= 0 then
					full = true
				elseif info and not info.isLocked then
					C_Container.UseContainerItem(tab, slot)
					want[id] = want[id] - (info.stackCount or 1)
					moved[id] = (moved[id] or 0) + (info.stackCount or 1)
					room = room - 1
				end
			end
		end
	end
	return moved, full
end

-- Moves every stack of the rows' items into the bank. Returns what moved (item -> count).
local function PutAway(rows)
	local want, moved = {}, {}
	if #rows == 0 then return moved end
	for _, row in ipairs(rows) do want[row.item] = true end
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and not issecretvalue(id) and want[id] then
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and not info.isLocked then
					C_Container.UseContainerItem(bag, slot, nil, Enum.BankType.Character)
					moved[id] = (moved[id] or 0) + (info.stackCount or 1)
				end
			end
		end
	end
	return moved
end

-- During a visit: how many of each thing to have with you the bags held when last looked. Fewer now, and it
-- is to take out: it was just put in, which is said once a visit (`say`).
local carried, warned = {}, {}

local function Watch(say)
	local needs, book = Needs()
	local now = {}
	for item, need in pairs(needs) do
		if With(need, book.way) then now[item] = C_Item.GetItemCount(item) end
	end
	for _, row in ipairs(say and Plan().take or NONE) do
		-- (Not looked at before: only now known to be needed, as what a quest gave to carry is once it lies here.)
		local was = carried[row.item]
		if now[row.item] and (was == nil or was > now[row.item]) and not warned[row.item] then
			warned[row.item] = true
			T:Print(("you'll need |cffffffff%s|r%s before you're next at a bank."):format(ItemName(row.item),
				row.quest and (" for " .. QuestName(row.quest)) or ""))
		end
	end
	carried = now
end

-- What the open bank holds that is over, kept until the bank or the standings change (Leftovers walks it).
local left
local function Left()
	local stamp = Stash.Stamp()
	if not (left and left.stamp == stamp and left.bank == bankEpoch) then
		left = { stamp = stamp, bank = bankEpoch, rows = open and Leftovers() or NONE }
	end
	return left.rows
end

-- One move at the open bank, in one go, said in chat: "take" out what to have with you, "put" away what
-- can wait, "clear" out what no quest needs any more. Returns what moved, as rows.
function Stash.Move(what)
	if not open then return NONE end
	local moved, full = NONE, false
	if what == "take" then
		moved, full = TakeOut(Plan().take)
		moved = Rows(moved)
		if #moved > 0 then
			T:Print(("took |cffffffff%s|r out of your bank for %s."):format(Listed(moved, 4), For(moved) or "this step"))
		end
		if full then T:Print("your bags are full: some of what your quests need is still in your bank.") end
	elseif what == "put" then
		moved = Rows(PutAway(Later()))
		if #moved > 0 then
			T:Print(("put |cffffffff%s|r in your bank: you won't need %s for a while."):format(Listed(moved, 4), Them(moved)))
		end
	elseif what == "clear" then
		moved, full = TakeOut(Left())
		moved = Rows(moved)
		if #moved > 0 then
			T:Print(("took |cffffffff%s|r out of your bank: no quest needs %s any more."):format(Listed(moved, 4), Them(moved)))
		end
		if full then T:Print("your bags are full: the rest is still in your bank.") end
	end
	-- (The counts settle a moment later: the route is built again then.)
	if #moved > 0 then C_Timer.After(0.5, function() ns.Refresh() end) end
	return moved, full
end

-- As the bank opens: what is done for you, by the two settings. Left to the player with Shift held, or
-- with the errand put away for good. The game may not have the bank's slots yet as it opens, or may let
-- nothing move within that moment: what was to move and didn't is tried again, a few times, while this
-- visit lasts (not once the bags are full, which is said once).
local RETRY = { after = 0.4, times = 3 }
local visit = 0
local function AtBank()
	Watch(false)
	visit = visit + 1
	if IsShiftKeyDown() or R.Hushed("bank") then return end
	local db = T.db.stash
	local this, tries = visit, 0
	local function Go()
		if not open or this ~= visit then return end
		tries = tries + 1
		local took, full = NONE, false
		if db.auto then took, full = Stash.Move("take") end
		local put = db.autoAway and Stash.Move("put") or NONE
		if #took > 0 or #put > 0 or full or tries >= RETRY.times then return end
		if (db.auto and #Plan().take > 0) or (db.autoAway and #Later() > 0) then C_Timer.After(RETRY.after, Go) end
	end
	Go()
end

-- The bank window's jobs (ShyBags' T:RegisterBankJob, handed over by Bags.lua): each a line of the window's
-- foot at a banker while it has something to move, a click doing it in one go. look() gives its words
-- (nil: nothing to do) and what its hover says: each item, how many, and the quest it is for.
local function Says(title, rows, said)
	-- (A quest at a time, its name heading its things: an item and a quest side by side on one line wrap.)
	local sections, by = {}, {}
	for _, row in ipairs(rows) do
		local quest = row.quest or false
		local section = by[quest]
		if not section then
			section = { title = quest and QuestName(quest) or nil, rows = {} }
			by[quest] = section
			sections[#sections + 1] = section
		end
		section.rows[#section.rows + 1] = { icon = C_Item.GetItemIconByID(row.item), text = Counted(row) }
	end
	return { title = title, text = said, sections = sections }
end

function Stash.BankJobs()
	local function Job(id, order, pin, words, title, said, rows, what)
		return { id = id, order = order, pin = pin,
			look = function()
				local list = rows()
				if #list == 0 then return nil end
				return words:format(#list), Says(title, list, said)
			end,
			run = function() Stash.Move(what) end }
	end
	return {
		Job("quest-take", 1, "quest", "Take out %d", "Take out", "Your quests need these with you.",
			function() return Plan().take end, "take"),
		Job("quest-put", 2, "ahead", "Put away %d", "Put away", "No quest needs these for a while. They can wait here.", Later, "put"),
		Job("quest-clear", 3, "over", "Clear out %d", "Clear out", "No quest needs these any more. Sell them or drop them.", Left, "clear"),
	}
end

local mailOpen, mailSaid = false, false   -- at a mailbox; and what it holds for a quest was said this visit

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED",
	"BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
	if not ns.char then return end
	if event == "MAIL_SHOW" or event == "MAIL_CLOSED" then
		mailOpen, mailSaid = event == "MAIL_SHOW", false
		if mailOpen then wipe(off) end
		return
	elseif event == "MAIL_INBOX_UPDATE" and not mailOpen then
		return
	end
	bagEpoch = bagEpoch + 1
	-- (The bags alone, the bank shut: what the bank holds stands. ShyQuest.lua builds the errands again for it.)
	if event == "BAG_UPDATE_DELAYED" and not open then return end
	wipe(banks)
	wipe(mails)
	bankEpoch = bankEpoch + 1
	if event == "MAIL_INBOX_UPDATE" then
		-- The inbox as it now is; what of it your quests need with you is said once a visit.
		ReadMail()
		local post = Plan().post
		if #post > 0 and not mailSaid and T.db.stash.take then
			mailSaid = true
			T:Print(("your mailbox has |cffffffff%s|r for %s."):format(Listed(post, 4), For(post) or "your guide"))
		end
		ns.RefreshErrands()
		return
	end
	if event == "BANKFRAME_OPENED" then
		open = true
		wipe(off)
		wipe(warned)
		ReadBank()
		AtBank()
	elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_ENTERING_WORLD" then
		open = false
	elseif open then
		ReadBank()
		Watch(true)
	end
	if event ~= "BAG_UPDATE_DELAYED" and event ~= "PLAYER_ENTERING_WORLD" then ns.RefreshErrands() end
	-- (The bank window may have asked its jobs before this was heard: it asks again.)
	local shy = Shy.addons.Bags
	if shy and shy.RefreshBank then shy:RefreshBank() end
end)

ns.OnApply(function()
	applied = applied + 1
end)

-- The bags window read this character's mailbox again (it reads a moment after the inbox changes): what it
-- remembers of it is asked again.
Shy:On("SHY_BAGS_SCANNED", function(guid, source)
	if not ns.char or guid ~= UnitGUID("player") then return end
	-- (Its bank only until the bank has been read here: after that the bank's own events say all of it.)
	if source ~= "mail" and source ~= "sent" and not (source == "bank" and not ns.char.banked) then return end
	wipe(banks)
	wipe(mails)
	bankEpoch = bankEpoch + 1
	ns.RefreshErrands()
end)

-- What it knows, for /shyquest bank.
function Stash.Report()
	local out = {}
	local needs, book = Needs()
	local road = book.way
	if road then
		out[#out + 1] = ("guide: %d steps read ahead from step %d; next by a bank: %s"):format(road.steps, road.from,
			road.bank and (road.bank .. (road.bank == 1 and " step on" or " steps on")) or "not in them")
	else
		out[#out + 1] = "no guide followed: the quest log alone"
	end
	local at, yards = Nearest()
	out[#out + 1] = at and ("nearest banker: %s, %d yards"):format(at.npc.name, math.floor(yards + 0.5)) or "no banker known on this continent"
	local list = {}
	for _, need in pairs(needs) do list[#list + 1] = need end
	table.sort(list, Sooner)
	out[#out + 1] = ("%d items needed:"):format(#list)
	for _, need in ipairs(list) do
		out[#out + 1] = ("  %s (%d): %s%s, %s; bags %d, bank %d, mailbox %d"):format(ItemName(need.item), need.item,
			need.at == FAR and "farther on than was read" or need.at == 0 and "now" or (need.at .. (need.at == 1 and " step on" or " steps on")),
			need.count and (", " .. need.count .. " of them") or "", need.quest and QuestName(need.quest) or "no quest",
			C_Item.GetItemCount(need.item), Banked(need.item), Mailed(need.item))
	end
	local take, put, clear, post = Plan().take, Later(), Left(), Plan().post
	out[#out + 1] = "take out: " .. (#take > 0 and Listed(take, 99) or "nothing")
	out[#out + 1] = "out of the mailbox: " .. (#post > 0 and Listed(post, 99) or "nothing")
	out[#out + 1] = "put away: " .. (#put > 0 and Listed(put, 99) or "nothing")
	out[#out + 1] = "clear out: " .. (open and (#clear > 0 and Listed(clear, 99) or "nothing") or "only known with the bank open")
	return table.concat(out, "\n")
end

ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, Note)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Fetch quest items from bank and mailbox", function() return T.db.stash.take end, function()
		T.db.stash.take = not T.db.stash.take
		ns.Apply()
	end)
	root:CreateCheckbox("Put away what quests need later", function() return T.db.stash.away end, function()
		T.db.stash.away = not T.db.stash.away
		ns.Apply()
	end)
end, true)

R.AddErrand("bank", Find, "Quest items in your bank")
R.AddErrand("mailbox", FindMail, "Quest items in your mailbox")
-- To ask for: the banker, while the bank holds what a quest needs.
R.AddOffer("bank", function()
	if not (ns.char and T.db.stash.take and W.Known()) then return {} end
	local take = Plan().take
	return #take > 0 and { { text = "Banker: " .. (#take == 1 and ItemName(take[1].item) or "quest items") } } or {}
end)
R.AddOffer("mailbox", function()
	if not (ns.char and T.db.stash.take and W.Known()) then return {} end
	local post = Plan().post
	return #post > 0 and { { text = "Mailbox: " .. (#post == 1 and ItemName(post[1].item) or "quest items") } } or {}
end)
