-- The quests you could take at a giver, so the trip there can be weighed before it is made. A pin's hover names
-- them, each on a line with what it pays; a click on the pin keeps the hover and it says the rest (CardHover.lua,
-- with these blocks), with what to do about it at its foot:
--   the head     who gives them, how far; then how many quests, their XP together (and how much of your level
--                that is) and whether anything in them is an upgrade
--   each quest   its name in the color of its difficulty and its level; what it asks for, in its own
--                sentence (Data/Offers.lua, the server's word), else each thing the data has it ask for;
--                what it pays: XP as you would be paid it now, money, what it costs; the items it gives and
--                the ones to choose from, each with what it is and what ShyGear makes of it for you (the mouse
--                on one shows the game's own tooltip, a held key links it); a spell it teaches; who takes it
--                back where that isn't its giver; the quest it leads to; and, in gold, why the route leaves it
--                or what your guide does with it
--
--   ns.Offer.Quests(stop) -> { { id, action, who } }   the quests picked up at a stop, in its order (who: their
--                                                 giver, on a pin of several); empty for none
--   ns.Offer.Content(stop) -> content or nil      what is said of them (the tests read it)
--   ns.Offer.Tally(content) -> words              the line under the head's name
--   ns.Offer.Blocks(content) -> { block, ... }    the quests as Shy.Hover card blocks
--   ns.Offer.ItemRow({ item, count }) -> row      an item a quest gives, as a hover row (icon, name, what it is to you)

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide
local UI = Shy.UI
local C = UI.colors

local Offer = {}
ns.Offer = Offer

local P = {
	late = 0.15,                   -- seconds from an item coming in to the hover being filled again
	most = 8,                      -- quests said at one giver; the rest are counted
	short = 2,                     -- more quests than this: each is said short (Offer.Blocks)
	shortMost = 5,                 -- ... and no more of them than this
}
local VERDICT = { later = "Later", same = "About the same", worse = "Worse than yours", cant = "Can't use" }
local DOT = "  \194\183  "

local asked = {}             -- items the kept hover waits to hear of
local waiting = false

local function Gear()
	local gear = Shy.addons.Gear
	return gear and gear.Judge and gear or nil
end

-- What is said of them ------------------------------------------------------------------------------

-- The quests picked up at a stop, each once, in the stop's order: a giver's pick-ups, those of every giver
-- of a pin that stands for several (each with who gives it), or a guide step's open accept lines.
function Offer.Quests(stop)
	local out, seen = {}, {}
	if not stop then return out end
	local function Add(id, action, who)
		if id and not seen[id] and D.Quest(id) and not L.Has(id) then
			seen[id] = true
			out[#out + 1] = { id = id, action = action, who = who }
		end
	end
	if stop.kind == "guide" then
		for _, view in ipairs(stop.views or { stop.view }) do
			for _, line in ipairs(view and view.lines or {}) do
				if not line.done and line.mark == "pickup" then Add(line.id) end
			end
		end
		return out
	end
	for _, member in ipairs(stop.members or { stop }) do
		for _, action in ipairs(member.actions or {}) do
			if action.kind == "pickup" then Add(action.id, action, stop.members and member.who or nil) end
		end
	end
	return out
end

-- What a quest asks for where it has no sentence: each thing the data has it kill, collect or use.
local function Asks(quest)
	local lines = {}
	for _, token in ipairs(quest.goals or {}) do
		if token.kind == "c" or token.kind == "k" then
			local names = {}
			for _, npc in ipairs(token.ids or { token.id }) do
				local record = D.Npc(npc)
				if record then names[#names + 1] = record.name end
			end
			if #names > 0 then lines[#lines + 1] = "Kill " .. table.concat(names, " or ") end
		elseif token.kind == "i" then
			local item = D.Item(token.id)
			if item then lines[#lines + 1] = "Collect " .. item.name end
		elseif token.kind == "o" then
			local object = D.Object(token.id)
			if object then lines[#lines + 1] = "Use " .. object.name end
		end
	end
	return lines
end

-- Who takes a quest back, where that is someone other than who gives it here: "Deputy Rainer, Elwynn
-- Forest" (the zone only where it is another).
local function Back(quest, stop)
	local ender = R.Usable(quest.ends)
	if not ender then return nil end
	for _, start in ipairs(quest.starts) do
		if start.kind == ender.kind and start.id == ender.id then return nil end
	end
	local thing = D.Thing(ender.kind, ender.id)
	if not thing then return nil end
	local place = thing.places and thing.places[1]
	local zone = place and place.map ~= stop.map and W.MapName(place.map)
	return thing.name, zone or nil
end

-- What the route or the guide makes of a quest, where that is worth saying: in gold.
local function Standing(quest, action)
	if action and action.failed then return "Failed: abandon it and accept it again" end
	if R.offGuide then
		-- (A quest for the player's class always counts as the guide's: G.Uses.)
		if quest.classes then return "For your class: worth taking" end
		return G.Uses(quest.id) and "Your guide picks this up later" or "Not in your guide"
	end
	-- (Too high a level says so by itself; the rest is the trip, which is what is being weighed.)
	local worth, why, what = R.WorthOffer(quest)
	if not worth and why then return what == "level" and why or ("Off your route: " .. why:sub(1, 1):lower() .. why:sub(2)) end
end

-- How a quest that starts from an item is come by, for the line under its name.
local function From(stop, action)   -- stop: the giver's own (a pin of several: that member)
	if not (action and action.item) then return nil end
	local name = C_Item.GetItemNameByID(action.item) or (D.Item(action.item) or {}).name or "an item"
	if action.held then return ("Starts from %s in your bags"):format(name) end
	local who = stop.who
	local how = action.from == "o" and "Found in" or action.from == "v" and "Sold by" or "Dropped by"
	local chance = action.chance and D.OneIn(action.chance, true)
	return ("Starts from %s%s%s"):format(name, who and (", " .. how:lower() .. " " .. who) or "", chance and (" (" .. chance .. ")") or "")
end

-- The stop's place in words, for the line under its name: its part of the zone, else the zone.
local function Where(stop)
	local _, _, where = R.Describe(stop)
	return where or (stop.map and W.MapName(stop.map)) or nil
end

-- content = { title, kind ("pickup" | "guide" ...: the head's mark), tone, where, far,
--             quests = { { id, name, level, color = { r, g, b }, tags, giver (on a pin of several givers), from,
--                          says | asks = { line }, xp, share,
--                          money, cost, items, choices ({ item, count } each), spell, back, zone, opens, note } },
--             more (quests past P.most), xp (all of them together) }
function Offer.Content(stop)
	local quests = Offer.Quests(stop)
	if #quests == 0 then return nil end
	local title = R.Describe(stop)
	-- A pin that stands for several givers says how many; each quest then says whose it is.
	local givers, named = 0, {}
	for _, one in ipairs(quests) do
		if one.who and not named[one.who] then
			named[one.who] = true
			givers = givers + 1
		end
	end
	if givers > 1 then title = ("%d quest givers"):format(givers) end
	local content = { title = title or stop.who or "Quests", kind = ns.StopMark(stop), tone = ns.StopTone(stop),
		where = Where(stop), far = stop.yards and W.Far(stop) or nil, quests = {}, xp = 0, more = 0 }
	for _, one in ipairs(quests) do
		local quest, offer = D.Quest(one.id), D.Offer(one.id) or {}
		local level = quest.level > 0 and quest.level or L.Level()
		local color = GetQuestDifficultyColor(level)
		local xp, share = L.Pays(quest), L.Share(quest.level)
		content.xp = content.xp + (xp or 0)
		if #content.quests >= P.most then
			content.more = content.more + 1
		else
			local tags = {}
			if quest.flags:find("d", 1, true) then tags[#tags + 1] = "Dungeon" end
			if quest.flags:find("g", 1, true) then tags[#tags + 1] = "Raid" end
			if quest.flags:find("r", 1, true) then tags[#tags + 1] = "Repeatable" end
			if quest.classes then tags[#tags + 1] = "For your class" end
			local says = D.Says(offer.says)
			local back, zone = Back(quest, stop)
			local after = L.Opens(quest)
			local money = offer.money or 0
			content.quests[#content.quests + 1] = {
				id = one.id, name = quest.name, level = quest.level, color = { color.r, color.g, color.b },
				tags = #tags > 0 and table.concat(tags, DOT) or nil,
				giver = givers > 1 and one.who or nil,
				from = From(one.who and { who = one.who } or stop, one.action),
				says = says, asks = not says and Asks(quest) or nil,
				xp = xp and xp > 0 and xp or nil, share = share < 1 and math.floor(share * 100 + 0.5) or nil,
				money = money > 0 and money or nil, cost = money < 0 and -money or nil,
				items = offer.items or {}, choices = offer.choices or {}, spell = offer.spell,
				back = back, zone = zone, opens = after and after.name or nil,
				note = Standing(quest, one.action),
			}
		end
	end
	return content
end

-- ShyGear's verdict on an item, or nil (none of it loaded yet, or nothing to say).
local function Verdict(item)
	local gear = Gear()
	if not gear then return nil end
	local _, link = C_Item.GetItemInfo(item)
	if not link then return nil end
	return gear:Judge(link) or nil
end

-- The line under the head's name: how many quests, what they pay together, and whether any of it is an
-- upgrade for you.
function Offer.Tally(content)
	local parts, count = {}, #content.quests + content.more
	parts[1] = count == 1 and "1 quest" or (count .. " quests")
	if content.xp > 0 then
		local most = UnitXPMax("player") or 0
		local share = most > 0 and math.floor(content.xp / most * 100 + 0.5) or 0
		parts[#parts + 1] = BreakUpLargeNumbers(content.xp) .. " XP" .. (share >= 1 and (" (" .. share .. "% of your level)") or "")
	end
	local upgrades = 0
	for _, quest in ipairs(content.quests) do
		-- (One of a choice is taken: a quest counts once however many of its choices are upgrades.)
		local chosen = false
		for _, each in ipairs(quest.choices) do
			local v = Verdict(each.item)
			if v and v.kind == "upgrade" then chosen = true end
		end
		if chosen then upgrades = upgrades + 1 end
		for _, each in ipairs(quest.items) do
			local v = Verdict(each.item)
			if v and v.kind == "upgrade" then upgrades = upgrades + 1 end
		end
	end
	if upgrades > 0 then parts[#parts + 1] = UI.Wrap(C.good, upgrades == 1 and "an upgrade" or (upgrades .. " upgrades")) end
	return table.concat(parts, DOT)
end

-- The kept hover's blocks ----------------------------------------------------------------------------------

-- What an item is, in a line: where it is worn and its kind ("Chest  ·  Mail"), or its kind alone.
local function What(kind, subKind, where)
	local slot = where and where ~= "" and _G[where] or nil
	if slot == "" then slot = nil end
	local what = subKind and subKind ~= "" and subKind ~= OTHER and subKind or nil
	if slot and what and what ~= slot then return slot .. DOT .. what end
	return slot or what or kind or ""
end

-- An item a quest gives, as a hover row: its icon, its name in its quality's color and how many, and on the right
-- what it is to you (ShyGear's word: what an upgrade gains, a quiet word for the rest), else what it is. The mouse
-- on it shows the game's own tooltip (Shy.Hover's row.item). One the game hasn't told of yet is asked for.
local function ItemRow(each)
	local item = each.item
	local name, link, quality, _, _, kind, subKind, _, where, icon = C_Item.GetItemInfo(item)
	local times = (each.count or 1) > 1 and UI.Wrap(C.dim, "  x" .. each.count) or ""
	if not name then
		asked[item] = true
		C_Item.RequestLoadItemDataByID(item)
		return { icon = C_Item.GetItemIconByID(item), text = ((D.Item(item) or {}).name or "") .. times, color = C.head, item = item }
	end
	local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
	local row = { icon = icon, text = name .. times, color = { color.r, color.g, color.b }, item = item, link = link,
		right = What(kind, subKind, where), rightColor = C.dim, wrap = false }
	local v = Verdict(item)
	if v and v.kind == "upgrade" then
		local gear = Gear()
		local words = gear.Words and gear:Words(v) or ""
		row.right, row.rightColor = words ~= "" and words or "Upgrade", C.good
	elseif v and VERDICT[v.kind] then
		row.right, row.rightColor = VERDICT[v.kind], v.kind == "later" and C.alert or C.dim
		if v.kind == "cant" then row.color = C.dim end
	end
	return row
end

Offer.ItemRow = ItemRow   -- (the Quests window's quest page has the same rows: LogRows.lua)

-- The quests of Offer.Content as Shy.Hover card blocks, for a pin's kept hover (CardHover.lua): for each quest
-- its name (in its difficulty's color, its level after it, what it pays at the right), whose it is on a pin of
-- several givers, where it starts from, what it asks for in its own sentence, the money it gives or costs, the
-- items (to choose from, or given) and a spell it teaches, then who takes it back, the quest it leads to and what
-- the route or the guide makes of it. Every block after the first stands under a hairline. More quests than
-- P.short are each said short, so the hover stays a hover: only the items that are an upgrade for you, the rest
-- counted on a line, nothing of where it goes after, and no more than P.shortMost quests, the rest counted.
function Offer.Blocks(content)
	local blocks = {}
	local giver
	local short = #content.quests > P.short
	local more = content.more
	for index, quest in ipairs(content.quests) do
		if short and index > P.shortMost then
			more = more + 1
		else
			-- (Several givers: a heading at each one's first quest; else a bare hairline between two.)
			local title = (quest.giver and quest.giver ~= giver and quest.giver) or (index > 1 and "") or nil
			giver = quest.giver
			local level = quest.level > 0 and UI.Wrap(C.dim, "  " .. quest.level) or ""
			local rows = { { seat = ns.MarkSeat("pickup"), text = quest.name .. level, color = quest.color,
				right = quest.xp and ("+%s XP"):format(BreakUpLargeNumbers(quest.xp)) or nil, rightColor = C.alert } }
			if quest.tags then rows[#rows + 1] = { text = quest.tags, quiet = true } end
			if quest.from then rows[#rows + 1] = { text = quest.from, color = C.alert } end
			if quest.says then
				rows[#rows + 1] = { text = quest.says }
			else
				for _, words in ipairs(quest.asks or {}) do rows[#rows + 1] = { text = words } end
			end
			local pays = {}
			if quest.money then pays[#pays + 1] = UI.Money(quest.money, false, 11) end
			if quest.share and quest.xp then pays[#pays + 1] = UI.Wrap(C.dim, ("%d%% of its XP at your level"):format(quest.share)) end
			if #pays > 0 then rows[#rows + 1] = { text = table.concat(pays, DOT) } end
			if quest.cost then rows[#rows + 1] = { text = "Costs " .. UI.Money(quest.cost, false, 11), color = C.alert } end
			blocks[#blocks + 1] = { title = title, rows = rows }
			-- (Said short: only what is an upgrade for you, under its heading; the rest a quiet line under the quest.)
			local function Things(heading, list, choose)
				if #list == 0 then return end
				local things, rest = {}, 0
				for _, each in ipairs(list) do
					local row = ItemRow(each)
					if short and row.rightColor ~= C.good then rest = rest + 1 else things[#things + 1] = row end
				end
				if #things > 0 then
					if rest > 0 then things[#things + 1] = { quiet = true, text = ("and %d more"):format(rest) } end
					blocks[#blocks + 1] = { title = heading, rows = things }
				elseif rest > 0 then
					rows[#rows + 1] = { quiet = true, text = choose and ("A choice of %d rewards"):format(rest)
						or (rest == 1 and "A reward" or ("%d rewards"):format(rest)) }
				end
			end
			Things(#quest.choices > 1 and "Choose one" or "You get", quest.choices, #quest.choices > 1)
			Things(#quest.choices > 1 and "And you get" or "You get", quest.items)
			if quest.spell then
				blocks[#blocks + 1] = { title = "Teaches", rows = { { icon = C_Spell.GetSpellTexture(quest.spell),
					text = C_Spell.GetSpellName(quest.spell) or "A spell", spell = quest.spell, right = "You learn it", rightColor = C.dim } } }
			end
			-- Where it goes from here, and what your route or guide makes of it.
			local onward = {}
			if quest.back and not short then
				onward[#onward + 1] = { quiet = true, text = "Hand in to " .. UI.Wrap(C.text, quest.back) .. (quest.zone and (", " .. quest.zone) or "") }
			end
			if quest.opens and not short then onward[#onward + 1] = { quiet = true, text = "Leads to " .. UI.Wrap(C.text, quest.opens) } end
			if quest.note then onward[#onward + 1] = { glyph = "note", tint = C.alert, color = C.alert, text = quest.note } end
			if #onward > 0 then blocks[#blocks + 1] = { rows = onward } end
		end
	end
	if more > 0 then
		blocks[#blocks + 1] = { rows = { { quiet = true, text = ("and %d more quest%s here"):format(more, more == 1 and "" or "s") } } }
	end
	return blocks
end

-- The game told of an item a kept hover was waiting for, or ShyGear's verdicts changed (gear put on, a build
-- picked): it is filled again, once a moment.
local function Late()
	if waiting then return end
	waiting = true
	C_Timer.After(P.late, function()
		waiting = false
		wipe(asked)
		if ns.CardHover and ns.CardHover.Again then ns.CardHover.Again() end
	end)
end

Shy:On("SHY_LOGIN", function()
	local events = CreateFrame("Frame")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:SetScript("OnEvent", function(_, _, item)
		if item and asked[item] then Late() end
	end)
	Shy:On("SHY_GEAR", Late)
end)
