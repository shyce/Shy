-- Why a quest isn't yours to take, in plain words, and a zone's quests by how they stand with you.
-- The rules are Log.lua's (L.Missing); this file only says them.

local ADDON, ns = ...
local D, W, L = ns.Data, ns.World, ns.Log
local UI = Shy.UI
local C = UI.colors

local Why = {}
ns.Why = Why

-- How a quest stands, by the rule it fails: a quest takes the first of these that any of its rules has.
--   skip      never yours (another side, race or class; not in the game; a raid's)
--   log, done
--   missed    no longer to be had (an exclusive one taken, its chain gone past, too high a level now)
--   yet       a level, a quest, a skill or a standing still to come
--   available nothing stands in the way but a setting or your own pick (soft)
local STANDS = {
	never = "skip", raid = "skip", side = "skip", race = "skip", class = "skip", log = "log", done = "done",
	maxLevel = "missed", instead = "missed", past = "missed", led = "missed", ["until"] = "missed", giver = "missed",
	repMax = "missed", learned = "missed", repeatable = "soft", hidden = "soft", outgrown = "soft",
}
local RANK = { log = 1, done = 2, skip = 3, missed = 4, yet = 5, available = 6 }
-- The reputation each standing starts at, Hated to Exalted (FACTION_STANDING_LABEL1 to 8).
local STANDINGS = { -42000, -6000, -3000, 0, 3000, 9000, 21000, 42000 }

local function Name(id)
	return D.Name("quests", id) or ("Quest " .. id)
end

-- "Orc or Troll": a list of names joined.
local function Either(names)
	if #names <= 1 then return names[1] or "" end
	return table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]
end

local function Races(side)
	local names = {}
	for race in side:gmatch("%d+") do
		local info = C_CreatureInfo.GetRaceInfo(tonumber(race))
		if info and info.raceName then names[#names + 1] = info.raceName end
	end
	return Either(names)
end

local function Classes(mask)
	local names, class, bit = {}, 1, 1
	while bit <= mask do
		if math.floor(mask / bit) % 2 == 1 then
			local info = C_CreatureInfo.GetClassInfo(class)
			if info and info.className then names[#names + 1] = info.className end
		end
		class, bit = class + 1, bit * 2
	end
	return Either(names)
end

local function Standing(value)
	local at = 1
	for i, from in ipairs(STANDINGS) do
		if value >= from then at = i end
	end
	return _G["FACTION_STANDING_LABEL" .. at] or ""
end

local function Faction(id)
	local info = C_Reputation.GetFactionDataByID(id)
	return info and info.name or "a faction"
end

-- A skill's name, and your points in it (nil when not learned).
local function SkillName(id)
	local info = C_SkillInfo.GetSkillLineInfoByID(id)
	if info and info.name and info.name ~= "" then return info.name, info.rank end
	local name = C_TradeSkillUI.GetTradeSkillDisplayName(id)
	return name ~= "" and name or nil, nil
end

-- Who a giver mark ("n240") names.
local function Giver(key)
	local kind, id = tostring(key or ""):match("^(%a)(%d+)$")
	local thing = kind and D.Thing(kind, tonumber(id))
	return thing and thing.name or "Its giver"
end

local function Said(text, short, glyph, more)
	local said = more or {}
	said.text, said.short, said.glyph = text, short or text, glyph or "note"
	return said
end

-- A rule failed, in words: { text (a line of its own), short (after a comma in a list's row), glyph,
-- right (what you have), quest (the quest it waits on), quests (one of these) }.
function Why.Say(reason)
	local what, id, value = reason.what, reason.id, reason.value
	if what == "never" then return Said("Not offered in this game", "not in this game") end
	if what == "raid" then return Said("Raid quest", "raid quest", "kill") end
	if what == "log" then return Said("In your log", "in your log") end
	if what == "done" then return Said("Done", "done", "check") end
	if what == "repeatable" then return Said("Repeatable quests are hidden", "repeatable") end
	if what == "hidden" then return Said("Hidden by you", "hidden by you") end
	if what == "outgrown" then return Said("Low-level quests are hidden", "too low to list") end
	if what == "unoffered" then return Said(Giver(value) .. " didn't offer it", nil, "talk") end
	if what == "level" then
		return Said("Level " .. value, "needs level " .. value, "up", { right = ("%d to go"):format(value - L.Level()) })
	end
	if what == "maxLevel" then return Said("Only to level " .. value, "only to level " .. value, "up") end
	if what == "side" then return Said((value == "A" and FACTION_ALLIANCE or FACTION_HORDE) .. " only") end
	if what == "race" then return Said(Races(value) .. " only") end
	if what == "class" then return Said(Classes(value) .. " only") end
	if what == "oneOf" then
		local first = value[1] and Name(value[1]) or "another quest"
		return Said(first, "needs " .. first .. (#value > 1 and " or another" or ""), "note", { quests = value })
	end
	if what == "before" then return Said(Name(id), "needs " .. Name(id), "note", { quest = id }) end
	if what == "instead" then return Said("Took " .. Name(id) .. " instead", "took " .. Name(id) .. " instead", "note", { quest = id }) end
	if what == "past" then return Said("Already on to " .. Name(id), "already on to " .. Name(id), "note", { quest = id }) end
	if what == "led" then return Said("Only leads to " .. Name(id), "only leads to " .. Name(id), "go", { quest = id }) end
	if what == "crumb" then return Said("Hand in " .. Name(id) .. " first", "hand in " .. Name(id) .. " first", "note", { quest = id }) end
	if what == "parent" then return Said("Comes with " .. Name(id), "comes with " .. Name(id), "note", { quest = id }) end
	if what == "until" then return Said("Not after " .. Name(id), "not after " .. Name(id), "note", { quest = id }) end
	if what == "disabled" then return Said("Not while you have " .. Name(id), "not while you have " .. Name(id), "note", { quest = id }) end
	if what == "spec" then return Said("A profession specialty", "needs a specialty", "book") end
	if what == "giver" then return Said("Nobody offers it to you", "nobody offers it to you", "talk") end
	if what == "learned" then
		local name = C_Spell.GetSpellName(value) or "what it teaches"
		return Said("You know " .. name .. " already", "you know " .. name, "check")
	end
	if what == "carry" then
		-- One item: named. Several (any book the library takes): too many to name.
		local item = #value == 1 and D.Item(value[1])
		if item then return Said("Needs " .. item.name .. " in your bags", "needs " .. item.name, "bag") end
		return Said("Needs an item you don't have", "needs an item you don't have", "bag")
	end
	if what == "skill" then
		-- (A skill asked at 1 is the skill learned at all.)
		local name, rank = SkillName(id)
		local words = (name or "A skill") .. (value > 1 and (" " .. value) or "")
		return Said(words, "needs " .. (name and words or words:lower()), "book",
			{ right = rank and ("you have %d"):format(rank) or "not learned" })
	end
	if what == "rep" then
		local data = C_Reputation.GetFactionDataByID(id)
		local words = ("%s with %s"):format(Standing(value), Faction(id))
		return Said(words, "needs " .. words, "star", { right = data and data.currentStanding and Standing(data.currentStanding) or nil })
	end
	if what == "repMax" then
		local words = ("Below %s with %s"):format(Standing(value), Faction(id))
		return Said(words, "below " .. words:sub(7), "star")
	end
	return Said(what)
end

-- How a quest stands with you: state (as STANDS, "yet" or "available"), the reasons (L.Missing), and the
-- one that decided it.
function Why.Standing(quest)
	local reasons = L.Missing(quest)
	local state, decided = "available", nil
	for _, reason in ipairs(reasons) do
		local stands = STANDS[reason.what] or "yet"
		if stands ~= "soft" and RANK[stands] < RANK[state] then state, decided = stands, reason end
	end
	return state, reasons, decided
end

-- How a quest stands, in a few words for a list's row ("needs level 12", "ready to turn in"), and its state.
function Why.Line(quest)
	local state, reasons, decided = Why.Standing(quest)
	if state == "available" then return reasons[1] and Why.Say(reasons[1]).short or "available", state end
	if state == "log" then
		local entry = L.entries[quest.id]
		return entry and entry.complete and "ready to turn in" or "in your log", state
	end
	return Why.Say(decided).short, state
end

-- Where a quest is picked up: { thing, name, map, x, y, yards } for the nearest friendly giver, or
-- { name, item } for the item it starts from; nil when neither.
function Why.Starts(quest)
	local best, item
	for _, token in ipairs(quest.starts) do
		if token.kind == "i" then
			local record = D.Item(token.id)
			item = item or { name = record and record.name or C_Item.GetItemNameByID(token.id) or "an item", item = token.id }
		else
			local thing = D.Thing(token.kind, token.id)
			if thing and (token.kind == "o" or L.Friendly(thing)) then
				for _, place in ipairs(thing.places) do
					for i = 1, place.dungeon and 0 or #place.points, 2 do
						local yards = W.Distance(place.map, place.points[i], place.points[i + 1])
						-- Measured beats unmeasured (another continent), and nearer beats farther.
						if not best or (yards and (not best.yards or yards < best.yards)) then
							best = { thing = thing, name = thing.name, map = place.map, x = place.points[i], y = place.points[i + 1], yards = yards }
						end
					end
				end
				best = best or { thing = thing, name = thing.name }
			end
		end
	end
	return best or item
end

-- "Marshal Dughan, Elwynn Forest" (the map only when it is too far to measure), or "From the Torn Scroll".
function Why.StartsWords(start)
	if start.item then return "From " .. start.name end
	local where = start.map and not start.yards and W.MapName(start.map)
	return start.name .. (where and (", " .. where) or "")
end

-- A quest's mark in a row or a hover: pickup when it can be taken, the log's while it is held, else none.
function Why.MarkOf(quest, state)
	if state == "log" then
		local entry = L.entries[quest.id]
		return entry and entry.complete and "turnin" or "goal"
	end
	if state == "available" then return "pickup" end
end

-- A quest a reason waits on, as rows: its name, its mark and how far its giver is; under it, quiet, what
-- it waits on in turn, or where it starts.
local function QuestRows(rows, id)
	local quest = D.Quest(id)
	if not quest then
		rows[#rows + 1] = { glyph = "note", text = Name(id) }
		return
	end
	local state, _, decided = Why.Standing(quest)
	local mark, start = Why.MarkOf(quest, state), Why.Starts(quest)
	local row = { text = quest.name, right = start and W.Yards(start.yards) or nil, rightColor = C.hot }
	if mark then row.seat = ns.MarkSeat(mark) else row.glyph = "note" end
	rows[#rows + 1] = row
	local under
	if state == "yet" or state == "missed" then
		local said = Why.Say(decided)
		under = said.short:sub(1, 1):upper() .. said.short:sub(2)
	elseif state ~= "log" and start then
		under = Why.StartsWords(start)
	end
	if under then rows[#rows + 1] = { quiet = true, indent = 1, text = under } end
end

-- Hover content for a quest you don't hold: what it is, what stands in the way, and where it starts.
--   hints: the caller's mouse hints.
function Why.Content(id, hints)
	local quest = D.Quest(id)
	if not quest then return nil end
	local state, reasons = Why.Standing(quest)
	local sections = {}
	local content = { strip = "Quest", title = quest.name, sections = sections, hints = hints }
	local mark = Why.MarkOf(quest, state)
	if mark then content.seat = ns.MarkSeat(mark) end
	local color = GetQuestDifficultyColor(quest.level > 0 and quest.level or L.Level())
	content.titleColor = { color.r, color.g, color.b }
	local sub = {}
	if quest.level > 0 then sub[#sub + 1] = "Level " .. quest.level end
	local pays = L.Pays(quest)
	if pays and pays > 0 then sub[#sub + 1] = BreakUpLargeNumbers(pays) .. " XP" end
	if state == "done" then sub[#sub + 1] = "Done" end
	content.sub = table.concat(sub, "  \194\183  ")

	-- What stands in the way: what is still to come under "Needs", what is gone under "Missed", your own
	-- settings and what was never yours quiet after them.
	local needs, missed, quiet, oneOf = {}, {}, {}, false
	for _, reason in ipairs(reasons) do
		local stands = STANDS[reason.what] or "yet"
		local said = Why.Say(reason)
		if stands == "yet" or stands == "missed" then
			local into = stands == "yet" and needs or missed
			if said.quests then
				-- Any one will do: each name once (a quest is often one per race or side), and only those
				-- that can be yours.
				local listed, count = {}, 0
				for _, before in ipairs(said.quests) do
					local other = D.Quest(before)
					local name = other and other.name or Name(before)
					if not listed[name] and not (other and Why.Standing(other) == "skip") then
						listed[name], count = true, count + 1
						QuestRows(into, before)
					end
				end
				if count == 0 then QuestRows(into, said.quests[1]) end
				oneOf = count > 1
			elseif reason.what == "before" then
				QuestRows(into, reason.id)
			else
				into[#into + 1] = { glyph = said.glyph, text = said.text, right = said.right, rightColor = C.dim }
			end
		elseif stands == "soft" or stands == "skip" then
			quiet[#quiet + 1] = { glyph = said.glyph, quiet = true, text = said.text }
		end
	end
	if #needs > 0 then sections[#sections + 1] = { title = oneOf and "Needs one of" or "Needs", rows = needs } end
	if #missed > 0 then sections[#sections + 1] = { title = "Missed", rows = missed } end
	if #quiet > 0 then sections[#sections + 1] = { rows = quiet } end

	local start = state ~= "done" and state ~= "skip" and Why.Starts(quest)
	if start then
		local rows = { { glyph = start.item and "loot" or "talk", text = start.name, right = W.Yards(start.yards), rightColor = C.hot } }
		local where = start.map and not start.yards and W.MapName(start.map)
		if where then rows[2] = { quiet = true, indent = 1, text = where } end
		-- A long-shot drop is no stop on the route (Route.lua): say why, and to watch for it.
		if start.item and D.LongShot(start.item) then
			rows[#rows + 1] = { quiet = true, indent = 1, text = "A rare drop: watch for it as you go" }
		end
		sections[#sections + 1] = { title = "Starts with", rows = rows }
	end
	return content
end

-- A zone's quests (those picked up on `map`) by how they stand with you: { log, available, yet, missed,
-- done }, each a list of { quest, line, state } in level order, and sig (the whole of it as a string).
-- Quests never yours are left out. Kept until the log, the level or the map changes.
local zone, zoneMap, zoneAt
function Why.Zone(map)
	local at = L.version .. ":" .. L.stamp
	if zone and zoneMap == map and zoneAt == at then return zone end
	zone = { log = {}, available = {}, yet = {}, missed = {}, done = {} }
	zoneMap, zoneAt = map, at
	for _, id in ipairs(D.StartsOnMap(map)) do
		local quest = D.Quest(id)
		if quest then
			local line, state = Why.Line(quest)
			local into = zone[state]
			if into then into[#into + 1] = { quest = quest, line = line, state = state } end
		end
	end
	local function Order(a, b)
		local la = a.quest.level > 0 and a.quest.level or a.quest.minLevel
		local lb = b.quest.level > 0 and b.quest.level or b.quest.minLevel
		if la ~= lb then return la < lb end
		return a.quest.id < b.quest.id
	end
	local sig = {}
	for _, key in ipairs({ "log", "available", "yet", "missed", "done" }) do
		table.sort(zone[key], Order)
		for _, each in ipairs(zone[key]) do sig[#sig + 1] = each.quest.id .. key .. each.line end
	end
	-- What the list says, in one string: a list made again from the same answers is the same list.
	zone.sig = table.concat(sig, ",")
	return zone
end

-- Every map quests are picked up on, by continent: { { name, maps = { { map, name } } } }, in name order.
local zones
function Why.Zones()
	if zones then return zones end
	zones = {}
	local by = {}
	for _, map in ipairs(D.StartMaps()) do
		local info = C_Map.GetMapInfo(map)
		if info and info.name and info.name ~= "" then
			local top, steps = info, 0
			while top and top.mapType ~= Enum.UIMapType.Continent and top.parentMapID and top.parentMapID ~= 0 and steps < 8 do
				top, steps = C_Map.GetMapInfo(top.parentMapID), steps + 1
			end
			local key = top and top.mapType == Enum.UIMapType.Continent and top.name or "Elsewhere"
			local group = by[key]
			if not group then
				group = { name = key, maps = {} }
				by[key] = group
				zones[#zones + 1] = group
			end
			group.maps[#group.maps + 1] = { map = map, name = info.name }
		end
	end
	table.sort(zones, function(a, b) return a.name < b.name end)
	for _, group in ipairs(zones) do
		table.sort(group.maps, function(a, b)
			if a.name ~= b.name then return a.name < b.name end
			return a.map < b.map
		end)
	end
	return zones
end
