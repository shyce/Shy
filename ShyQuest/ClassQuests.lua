-- Your class's own quests as a row of their own: the ones that teach a spell, a stance, a form. They matter more
-- than their XP, so they never fall away with the guide's place, nor for paying little.
--   Which: every quest for your class you can take now (L.Missing: every rule but paying little), and not a pet's
--     (Pets.lua has those), a dungeon's or a raid's. One in the log is the route's own, like any quest.
--   Where and when: by the road ahead, not by where you stand. The road is you, then the guide's next places
--     (G.Places; with no guide, you alone). Taking a quest is two stops, who gives it and who takes it back, and
--     each is fitted where on the road it adds the least walk (Fit), a little more for each place it waits past
--     (LATER: a spell sooner is worth a few yards). Of a quest's versions, one from each town, the one that adds
--     least is the one: Divine Grace is handed in to Laurena in Stormwind, so hers costs one stop, and
--     Josetta's in Goldshire two, unless the road goes by Josetta and not by Laurena.
--   The row: the class quest that fits the road best, what it teaches, who gives it. Its hover lists the rest.
--   When it leads: when the road's best place for it is now, on the way to the guide's next place, and the pickup
--     adds no more than WORTH yards (more for a spell; the hand-in, once it's in your log, is the route's). Best done now but dearer, it waits among the errands. Best
--     done later, on the road's next SOON places, the row says where you'll pick it up. Otherwise "Take me to".
--     Of those best done now, what teaches a spell comes first.
--     (All by straight lines: every giver of every quest is weighed, and the ground's searches are the route's.)
--   The guide: its own steps to take a class quest count as done while this is on (Guide.lua). The row is where
--     you take them, so you're never sent two ways to one quest.

local ADDON, ns = ...
local T = ns.T
local D, L, W, R = ns.Data, ns.Log, ns.World, ns.Route
local UI = Shy.UI
local C = UI.colors

local Class = {}
ns.ClassQuests = Class

T.defaults.classQuests = { on = true }   -- your class's quests as a row on the card

-- Yards of walk added that a class quest is worth now (it leads), and at most for a row while it's best done now.
-- One that teaches a spell is worth more: a few minutes for a spell (Stormwind's cathedral off the road from the
-- trade district to Lakeshire adds some 1,100).
local WORTH = { spell = 1500, plain = 900 }
local LISTED = { spell = 2500, plain = 1500 }
local LATER = 40             -- yards a place it waits past is worth: the spell sooner
local ROAD = 12              -- the guide's next places the road is made of
local SOON = 6               -- of those, a quest best taken by one of the first SOON has a row saying so
local MOST_SHOWN = 5         -- quests listed in the hover

local stale, open = true, nil

-- Your class's bit in a quest's `classes`.
local function Bit()
	local id = select(3, UnitClass("player"))
	return id and 2 ^ (id - 1) or nil
end

local function ForMe(quest, bit)
	return quest.classes ~= nil and bit ~= nil and math.floor(quest.classes / bit) % 2 == 1
end

-- A quest's class field, read from its record's text without reading the rest.
local function ClassField(text)
	return tonumber(text:match("^[^%^]*%^[^%^]*%^[^%^]*%^[^%^]*%^[^%^]*%^(%d*)")) or 0
end

-- Every quest of your class, read once.
local mine, mineFor = nil, nil
local function Mine()
	local bit = Bit()
	if mineFor == bit then return mine end
	mine, mineFor = {}, bit
	if not bit then return mine end
	for id, text in pairs(ns.data.quests or {}) do
		local field = ClassField(text)
		if field > 0 and math.floor(field / bit) % 2 == 1 then mine[#mine + 1] = id end
	end
	table.sort(mine)
	return mine
end

-- Whether a quest can be taken now: every rule met, or only paying little against it.
local function Takeable(quest)
	if L.CanStart(quest) then return true end
	local missing = L.Missing(quest)
	if #missing == 0 then return false end
	for _, why in ipairs(missing) do
		if why.what ~= "outgrown" then return false end
	end
	return true
end

-- Whether it is a class quest this row takes: yours, not a pet's, a dungeon's or a raid's.
function Class.Ours(id)
	local quest = D.Quest(id)
	if not quest or not ForMe(quest, Bit()) then return false end
	if quest.flags:find("[dg]") then return false end
	if ns.Pets and ns.Pets.Quest and ns.Pets.Quest(id) then return false end
	return true
end

-- Whether the guide hands its step for this quest to the row (Guide.lua).
function Class.Takes(id)
	return T.db.classQuests.on == true and ns.char ~= nil and ns.Levelling() and Class.Ours(id)
end

-- What a quest teaches: the spell's name and icon, or nil.
local function Teaches(id)
	local offer = D.Offer(id)
	local spell = offer and offer.spell
	local name = spell and C_Spell.GetSpellName(spell)
	if not name then return nil end
	return { id = spell, name = name, icon = C_Spell.GetSpellTexture(spell) }
end

-- An NPC's places on your continent: { map, x, y, north, west } each.
local function Spots(npc)
	local out = {}
	for _, place in ipairs(npc and npc.places or {}) do
		if not place.dungeon then
			for i = 1, #place.points - 1, 2 do
				local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
				if continent == W.continent and north then
					out[#out + 1] = { map = place.map, x = place.points[i], y = place.points[i + 1], north = north, west = west }
				end
			end
		end
	end
	return out
end

-- The road ahead: where you stand, then the guide's next places on this continent, in order. A place you fly or
-- hearth on from is `carried`: what is fitted after it is walked to and back.
local function Road()
	local road = { { north = W.north, west = W.west } }
	local G = ns.Guide
	for _, place in ipairs(G and G.Places and G.Places(ROAD) or {}) do
		if place.continent ~= W.continent then break end
		road[#road + 1] = place
	end
	return road
end

local function Apart(a, b)
	return W.Between(a.north, a.west, b.north, b.west)
end

-- What fitting one spot after road place i adds: there and on to the next, less the way it saves; from the last,
-- there; from a place you're carried on from, there and back.
local function After(road, i, spot)
	local here, nextOne = road[i], road[i + 1]
	if not nextOne then return Apart(here, spot) end
	if here.carried then return 2 * Apart(here, spot) end
	return Apart(here, spot) + Apart(spot, nextOne) - Apart(here, nextOne)
end

-- Two spots fitted after one place, in order.
local function Both(road, i, first, second)
	local here, nextOne = road[i], road[i + 1]
	local between = Apart(first, second)
	if not nextOne then return Apart(here, first) + between end
	if here.carried then return Apart(here, first) + between + Apart(second, here) end
	return Apart(here, first) + between + Apart(second, nextOne) - Apart(here, nextOne)
end

-- The least a pickup and its hand-in (nil: handed in where it's taken) add to the road, a place's wait counted
-- (LATER): yards, and after which road place the pickup goes (1: now, before the guide's next place).
local function Fit(road, give, take)
	local best, at
	for i = 1, #road do
		local wait = LATER * (i - 1)
		if not take then
			local cost = After(road, i, give) + wait
			if not best or cost < best then best, at = cost, i end
		else
			local cost = Both(road, i, give, take) + wait
			if not best or cost < best then best, at = cost, i end
			local first = After(road, i, give)
			for j = i + 1, #road do
				cost = first + After(road, j, take) + wait
				if cost < best then best, at = cost, i end
			end
		end
	end
	return best, at
end

-- Who takes a quest back: its NPCs' spots (none: no word in the data, and only the pickup is weighed).
local function Takers(quest)
	local out = {}
	for _, token in ipairs(quest.ends) do
		local npc = token.kind == "n" and D.Npc(token.id)
		for _, spot in ipairs(Spots(npc)) do
			spot.npc = token.id
			out[#out + 1] = spot
		end
	end
	return out
end

-- The class quests you can take now, each at the giver that fits the road best, the best first:
-- { quest, npc, map, x, y, cost (yards added), at (after which road place: 1 now), teaches }.
local function Work()
	stale = false
	open = {}
	if not ns.char or not W.Known() or not W.north then return open end
	local road = Road()
	for _, id in ipairs(Mine()) do
		local quest = Class.Ours(id) and D.Quest(id)
		if quest and not L.Has(id) and Takeable(quest) then
			local takers, best = Takers(quest), nil
			for _, token in ipairs(quest.starts) do
				local npc = token.kind == "n" and D.Npc(token.id)
				if npc and L.Friendly(npc) then
					for _, spot in ipairs(Spots(npc)) do
						-- (Handed in to whoever takes it nearest this giver; to the giver, nothing more.)
						local take
						for _, taker in ipairs(takers) do
							if taker.npc ~= token.id and (not take or Apart(spot, taker) < Apart(spot, take)) then take = taker end
						end
						local same = false
						for _, taker in ipairs(takers) do
							if taker.npc == token.id then same = true end
						end
						local cost, at = Fit(road, spot, not same and take or nil)
						if cost and (not best or cost < best.cost) then
							-- (`pick`: what the pickup alone adds where it goes. Once it's in your log, the hand-in is
							-- the route's to fit, as any quest's.)
							best = { quest = quest, npc = npc, map = spot.map, x = spot.x, y = spot.y, cost = cost, at = at,
								pick = After(road, at, spot) }
						end
					end
				end
			end
			if best then open[#open + 1] = best end
		end
	end
	-- Of a quest's versions (one from each town), the one that adds least alone.
	local kept, shut = {}, {}
	table.sort(open, function(a, b)
		if a.cost ~= b.cost then return a.cost < b.cost end
		return a.quest.id < b.quest.id
	end)
	for _, entry in ipairs(open) do
		if not shut[entry.quest.id] then
			kept[#kept + 1] = entry
			entry.teaches = Teaches(entry.quest.id)
			for _, other in ipairs(entry.quest.exclusive or {}) do shut[other] = true end
		end
	end
	-- Then what is best done now first; of those, what teaches a spell (a robe at 24 is no reason to go), then the
	-- cheapest.
	table.sort(kept, function(a, b)
		if (a.at == 1) ~= (b.at == 1) then return a.at == 1 end
		if (a.teaches ~= nil) ~= (b.teaches ~= nil) then return a.teaches ~= nil end
		if a.cost ~= b.cost then return a.cost < b.cost end
		return a.quest.id < b.quest.id
	end)
	open = kept
	return open
end

-- The class quests open now, as Work has them. (Worked out again when the guide's road changes, and after a walk
-- of MOVED yards: the road begins where you stand.)
local MOVED = 200
local workedAt, workedStamp
function Class.Open()
	local G = ns.Guide
	if not stale and workedAt and W.north and W.Between(workedAt[1], workedAt[2], W.north, W.west) > MOVED then stale = true end
	if G and G.stamp ~= workedStamp then stale = true end
	if stale then
		Work()
		workedAt, workedStamp = W.north and { W.north, W.west } or nil, G and G.stamp
	end
	return open or {}
end

-- Whether the row has a quest, this version or another town's: the map's pickups leave it to the row.
function Class.Covers(id)
	if not Class.Takes(id) then return false end
	for _, entry in ipairs(Class.Open()) do
		if entry.quest.id == id then return true end
		for _, other in ipairs(entry.quest.exclusive or {}) do
			if other == id then return true end
		end
	end
	return false
end

local function Busy()
	return InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
end

-- Whether the route has a stop to take it already (a class quest right here is picked up in passing).
local function Taken(id)
	for _, stop in ipairs(R.stops or {}) do
		for _, action in ipairs(stop.actions or {}) do
			if action.kind == "pickup" and action.id == id then return true end
		end
	end
	return false
end

-- A quest's line: its name, and what it teaches when that is another name.
local function Line(entry)
	local teaches = entry.teaches
	if teaches and teaches.name ~= entry.quest.name then return ("%s: learn %s"):format(entry.quest.name, teaches.name) end
	if teaches then return ("%s: learn it"):format(entry.quest.name) end
	return entry.quest.name
end

-- The class quest as a route errand (R.AddErrand), or nil.
local function Find(lead)
	if not T.db.classQuests.on or Busy() then return nil end
	local list = Class.Open()
	local entry = list[1]
	-- (The row is a giver's: of what they have for you, what teaches a spell is named first.)
	for i = 2, #list do
		if entry and not entry.teaches and list[i].npc == entry.npc and list[i].teaches then entry = list[i] end
	end
	-- (Picked up from the route already: in the log, or a stop of its own when the row doesn't cover it.)
	if not entry or Taken(entry.quest.id) then return nil end
	local quest, npc = entry.quest, entry.npc
	-- Best done now: a row while it adds no more than LISTED, leading while it adds no more than WORTH. Best done
	-- on the road's next SOON places: a row saying where. Otherwise none: "Take me to" has it.
	-- (By what the pickup adds: the hand-in, once it's in your log, is the route's.)
	local now, kind = entry.at == 1, entry.teaches and "spell" or "plain"
	if now and entry.pick > LISTED[kind] then return nil end
	if not now and (entry.at > SOON + 1 or entry.pick > WORTH[kind]) then return nil end
	local leads = now and entry.pick <= WORTH[kind]
	local teaches = entry.teaches
	-- What else this giver has for your class.
	local also = 0
	for _, each in ipairs(list) do
		if each ~= entry and each.npc == npc then also = also + 1 end
	end
	local more = also > 0 and ("And %d more here"):format(also) or nil
	-- (Best taken later: where, so the row is no call to go now.)
	local later = not now and ("Later, on your way through %s"):format(W.MapName(entry.map) or "town") or nil
	local rows = function()
		local out = { { text = npc.title and ("%s, %s"):format(npc.name, npc.title) or npc.name, color = C.dim } }
		if teaches then out[#out + 1] = { icon = teaches.icon, text = "Learn " .. teaches.name } end
		if more then out[#out + 1] = { text = more, color = C.dim } end
		if later then out[#out + 1] = { text = later, color = C.dim } end
		return out
	end
	local lines = { npc.name }
	if teaches then lines[#lines + 1] = "Learn " .. teaches.name end
	if more then lines[#lines + 1] = more end
	if later then lines[#lines + 1] = later end
	return {
		title = "Class quest: " .. quest.name,
		lines = lines,
		rows = rows,
		caption = ("LEVEL %d  \194\183  YOUR CLASS"):format(UnitLevel("player")),
		map = entry.map, x = entry.x, y = entry.y, thing = npc, who = npc.name,
		mark = "pickup",       -- (A quest to pick up: a quest giver's gold mark, on the card, the maps and the plate.)
		first = leads or nil,
		route = leads or nil,  -- (Best done now, and hardly off the road: part of the way. Its hand-in is the route's.)
		hover = function()
			local out = {}
			for i = 1, math.min(MOST_SHOWN, #list) do
				local each = list[i]
				out[i] = { icon = each.teaches and each.teaches.icon or nil, glyph = "book", text = Line(each),
					right = W.MapName(each.map), rightColor = C.dim }
			end
			if #list > MOST_SHOWN then out[#out + 1] = { glyph = "note", quiet = true, text = ("and %d more"):format(#list - MOST_SHOWN) } end
			return { { title = #list == 1 and "Your class quest" or "Your class quests", rows = out } }
		end,
		tip = function(tip)
			tip:AddLine("Class quests teach what your class can't learn at a trainer.", 0.6, 0.6, 0.6, true)
		end,
	}
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED",
	"ZONE_CHANGED_NEW_AREA" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
	stale = true
	if ns.char then ns.RefreshErrands() end
end)
-- A spell learned: one quest's lesson may be known now.
Shy:On("SHY_SPELLS", function()
	stale = true
	if ns.char then ns.RefreshErrands() end
end)
ns.OnApply(function() stale = true end)

ns.CardSwitch("route", function(root)
	root:CreateCheckbox("Your class quests", function() return T.db.classQuests.on end, function()
		T.db.classQuests.on = not T.db.classQuests.on
		ns.Apply()
	end)
end)

R.AddErrand("classquest", Find, "Class quests")
-- To ask for: the nearest class quest, wherever it is.
R.AddOffer("classquest", function()
	local entry = T.db.classQuests.on and ns.char and Class.Open()[1]
	return entry and { { text = "Class quest: " .. entry.quest.name } } or {}
end)
