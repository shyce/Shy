-- Tooltip text for quests, stops and guide steps, shared by the tracker, the card and the pins.
-- A tracked quest gets full details (Tips.Quest); a stop lists each quest once, on one line.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, Z = ns.Data, ns.World, ns.Log, ns.Route, ns.Zones
local C = Shy.UI.colors

local Tips = {}
ns.Tips = Tips

local WHITE, DIM, HOT, GOLD, GOOD = C.text, C.dim, C.hot, C.alert, C.good
local MAX_SOURCES = 3
local STOP_SOURCES = 2     -- sources listed per objective of a stop
local MAX_LISTED = 6       -- quests listed for a zone
local MAX_QUESTS = 8       -- quests listed for one NPC
local MAX_PEOPLE = 5       -- NPCs listed for a merged pin
local MAX_STEPS = 4        -- guide steps listed for one pin
local MARK = 12            -- size of the mark before a quest's name

-- indent: true for one level, or a number of levels.
local function Pad(indent)
	if not indent then return "" end
	return ("   "):rep(indent == true and 1 or indent)
end

local function Line(tip, text, color, indent)
	tip:AddLine(Pad(indent) .. text, color[1], color[2], color[3])
end

local function Double(tip, left, right, leftColor, rightColor, indent)
	tip:AddDoubleLine(Pad(indent) .. left, right or "",
		leftColor[1], leftColor[2], leftColor[3], rightColor[1], rightColor[2], rightColor[3])
end

local function Title(tip, title, level)
	local color = GetQuestDifficultyColor(level > 0 and level or L.Level())
	tip:AddDoubleLine(title, level > 0 and ("Level " .. level) or "", color.r, color.g, color.b, DIM[1], DIM[2], DIM[3])
end
Tips.Line, Tips.Double, Tips.Title = Line, Double, Title

-- Lines other files add under a quest or objective (Party.lua). They register here so this
-- file works without them: a file new to the TOC isn't loaded until the client restarts.
local under = {}
function Tips.AddUnder(fn)
	under[#under + 1] = fn
end

-- Adds those lines for quest `id`, or for its objective `index`.
function Tips.Under(tip, id, index, indent)
	for _, fn in ipairs(under) do fn(tip, id, index, indent) end
end

local function YardsTo(places)
	local _, _, _, yards = W.Nearest(places)
	return W.Yards(yards)
end

-- Where a place is when no distance can be given: "inside The Deadmines", "Stormwind City".
local function Elsewhere(places)
	local map, _, _, yards, dungeon = W.Nearest(places)
	if dungeon then return "inside " .. (D.DungeonName(dungeon) or "a dungeon") end
	if map and not yards and map ~= W.map then return W.MapName(map) end
end

-- One objective

local function CreatureLine(tip, npc, chance, indent)
	local right = chance and (chance .. "%") or YardsTo(npc.places)
	local level = D.LevelText(npc)
	Double(tip, npc.name .. (level and ("  " .. Shy.UI.Wrap(DIM, level)) or ""), right, WHITE, HOT, indent)
end

-- The creatures an object is found among, if the data has it: "among Grellkin".
local function Among(object)
	local npc = object.among and D.Npc(object.among)
	return npc and npc.name ~= "" and ("among " .. npc.name) or nil
end

-- most: how many sources to list.
local function GoalLines(tip, token, most, indent)
	most, indent = most or MAX_SOURCES, indent or true
	if token.kind == "c" then
		local npc = D.Npc(token.id)
		if npc then
			local level = D.LevelText(npc)
			Double(tip, level or npc.name, YardsTo(npc.places), DIM, HOT, indent)
		end
	elseif token.kind == "k" then
		for i = 1, math.min(most, #token.ids) do
			local npc = D.Npc(token.ids[i])
			if npc then CreatureLine(tip, npc, nil, indent) end
		end
	elseif token.kind == "o" then
		local object = D.Object(token.id)
		if object then
			local among = Among(object)
			Double(tip, Elsewhere(object.places) or (among and (among:sub(1, 1):upper() .. among:sub(2))) or "Out in the world",
				YardsTo(object.places), DIM, HOT, indent)
		end
	else
		local item = D.Item(token.id)
		if not item then return end
		if token.kind == "s" then Line(tip, "Also needs " .. item.name, DIM, indent) end
		if item.trade and not T.db.guide.selfFound then Line(tip, "Trade good: check the AH", DIM, indent) end
		-- Nearest sources first. Records with the same name (the data has duplicates) share one
		-- line, with the nearest distance and the best drop chance among them.
		local near, by = {}, {}
		for i, source in ipairs(item.sources) do
			local thing = D.Thing(source.kind, source.id)
			if thing and (source.kind ~= "v" or L.Friendly(thing)) then
				local _, _, _, yards = W.Nearest(thing.places)
				local key = source.kind .. thing.name
				local same = by[key]
				if not same then
					same = { kind = source.kind, thing = thing, yards = yards, chance = source.chance, at = i }
					by[key] = same
					near[#near + 1] = same
				else
					if yards and (not same.yards or yards < same.yards) then same.thing, same.yards = thing, yards end
					if source.chance and (not same.chance or source.chance > same.chance) then same.chance = source.chance end
				end
			end
		end
		table.sort(near, function(a, b)
			if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
			if a.yards and a.yards ~= b.yards then return a.yards < b.yards end
			return a.at < b.at
		end)
		for i = 1, math.min(most, #near) do
			local thing = near[i].thing
			if near[i].kind == "n" then
				CreatureLine(tip, thing, near[i].chance, indent)
			elseif near[i].kind == "v" then
				Double(tip, "Sold by " .. thing.name, YardsTo(thing.places), WHITE, HOT, indent)
			else
				-- A container named like the item is the item itself on the ground.
				local among = Among(thing)
				local how
				if thing.name == item.name then
					how = "Lying " .. (among or "out in the world") .. ": pick it up"
				else
					how = "In " .. thing.name .. (among and (", " .. among) or "")
				end
				Double(tip, how, YardsTo(thing.places), WHITE, HOT, indent)
			end
		end
	end
end

-- A quest in the log

local function HandIn(tip, quest)
	if not quest then return end
	for _, token in ipairs(quest.ends) do
		local thing = D.Thing(token.kind, token.id)
		if thing and (token.kind == "o" or L.Friendly(thing)) then
			local where = Elsewhere(thing.places)
			Double(tip, "Turn in to |cffffffff" .. thing.name .. "|r" .. (where and (", " .. where) or ""),
				YardsTo(thing.places), GOLD, HOT)
			return
		end
	end
end

-- Lines for one objective of a quest in the log: its text, then where what it asks for is got.
-- `alone` as for Tips.Quest.
function Tips.Goal(tip, id, index, alone)
	local goal = L.Has(id) and L.Goals(id)[index]
	if not (goal and goal.text and goal.text ~= "") then return end
	Line(tip, goal.text, goal.finished and GOOD or WHITE)
	if not goal.finished then
		for _, token in ipairs(goal.tokens) do GoalLines(tip, token) end
	end
	if not alone then Tips.Under(tip, id, index, true) end
end

-- Lines for a quest in the log. `titled` adds its name on top; `alone` omits party progress
-- (for tooltips that already have the default party lines).
function Tips.Quest(tip, id, titled, alone)
	local entry, quest = L.entries[id], D.Quest(id)
	if not entry then return end
	if titled then Title(tip, entry.title, entry.level or 0) end

	if entry.complete then
		HandIn(tip, quest)
		if not alone then Tips.Under(tip, id) end
	else
		for index in ipairs(L.Goals(id)) do Tips.Goal(tip, id, index, alone) end
		HandIn(tip, quest)
	end

	local xp = GetQuestLogRewardXP(id)
	if xp and xp > 0 then
		Line(tip, ("+%s XP"):format(BreakUpLargeNumbers(xp)), DIM)
	end
	-- The quest it leads to, as an offer says it.
	local after = quest and L.Opens(quest)
	if after then Line(tip, "Unlocks " .. after.name, DIM) end
end

-- An available quest

function Tips.Offer(tip, quest, giver)
	Title(tip, quest.name, quest.level)
	if giver then Line(tip, "Starts with |cffffffff" .. giver.name .. "|r", GOLD) end
	if quest.flags:find("d", 1, true) then Line(tip, "Dungeon quest", DIM) end
	if quest.flags:find("r", 1, true) then Line(tip, "Repeatable", DIM) end
	local pays, share = L.Pays(quest), L.Share(quest.level)
	if pays then
		Line(tip, ("Gives about %d XP%s"):format(pays, share < 1 and (", %d%% of it at your level"):format(math.floor(share * 100 + 0.5)) or ""), DIM)
	elseif share < 1 then
		Line(tip, ("Gives %d%% of its XP at your level"):format(math.floor(share * 100 + 0.5)), DIM)
	end
	local after = L.Opens(quest)
	if after then Line(tip, "Unlocks " .. after.name, DIM) end
	local worth, why = R.WorthOffer(quest)
	if not worth then Line(tip, "Not on your route: " .. why:sub(1, 1):lower() .. why:sub(2), GOLD) end
	if R.offGuide and not L.Has(quest.id) then
		-- A quest for the player's class always counts as the guide's (G.Uses).
		Line(tip, quest.classes and "For your class: accept it" or ns.Guide.Uses(quest.id) and "Your guide picks this up later"
			or "Not in your guide: skip", GOLD)
	end
end

-- A stop on the route

-- quest: the quest the line is about. An objective's
-- mark is the emblem and color of what it asks for: `tone` where the caller knows which objective, else the
-- quest's first one open.
local function Mark(kind, quest, tone)
	return ns.MarkText(kind, MARK, kind == "goal" and (tone or ns.QuestKind(quest)) or nil) .. " "
end

local function ItemName(id)
	return C_Item.GetItemNameByID(id) or (D.Item(id) or {}).name or "an item"
end

-- The indent one level below `indent`.
local function Under(indent)
	return (indent == true and 1 or indent or 0) + 1
end

-- A suggested zone: its quests and the quest giver to start with.
local function Zone(tip, stop)
	local zone = stop.zone
	Double(tip, zone.name, W.Yards(stop.yards), WHITE, HOT)
	Line(tip, Z.Summary(zone) .. (stop.yards and "" or ", on another continent"), GOLD)
	for i = 1, math.min(MAX_LISTED, #zone.quests) do
		local quest = zone.quests[i]
		local color = GetQuestDifficultyColor(quest.level > 0 and quest.level or L.Level())
		tip:AddDoubleLine(Pad(true) .. quest.name, quest.level > 0 and tostring(quest.level) or "",
			color.r, color.g, color.b, DIM[1], DIM[2], DIM[3])
	end
	if #zone.quests > MAX_LISTED then Line(tip, ("and %d more"):format(#zone.quests - MAX_LISTED), DIM, true) end
	Line(tip, "Start with |cffffffff" .. zone.hub.thing.name .. "|r", DIM)
end

-- An available quest on one line (difficulty color, level), with a note under it only when
-- it starts from an item, has failed, or the route skips it.
local function OfferLine(tip, action, indent)
	local quest = D.Quest(action.id)
	local level = action.level or 0
	local color = GetQuestDifficultyColor(level > 0 and level or L.Level())
	local right = level > 0 and tostring(level) or ""
	if quest and quest.flags:find("d", 1, true) then right = right .. " dungeon" end
	tip:AddDoubleLine(Pad(indent) .. Mark("pickup", action.id) .. action.title, right, color.r, color.g, color.b, DIM[1], DIM[2], DIM[3])
	local under = Under(indent)
	if action.failed then
		Line(tip, "Failed: abandon it and accept it again", GOLD, under)
	elseif action.held then
		Line(tip, ("Starts from %s in your bags"):format(ItemName(action.item)), GOLD, under)
	elseif action.item then
		local how = action.from == "o" and "In " or action.from == "v" and "Sells " or "Drops "
		Double(tip, how .. ItemName(action.item) .. ", which starts it", action.chance and (action.chance .. "%") or "", DIM, HOT, under)
	elseif quest then
		-- Too high a level already shows as the red level on the line.
		local worth, why, what = R.WorthOffer(quest)
		if not worth and what ~= "level" then Line(tip, why, DIM, under) end
	end
end

local function LogLine(tip, action, indent)
	local entry = L.entries[action.id]
	if action.kind == "turnin" or (entry and entry.complete) then
		Double(tip, Mark("turnin", action.id) .. action.title, "Turn in", GOLD, DIM, indent)
	else
		local level = entry and entry.level or action.level or 0
		local color = GetQuestDifficultyColor(level > 0 and level or L.Level())
		tip:AddLine(Pad(indent) .. Mark("goal", action.id) .. action.title, color.r, color.g, color.b)
	end
end

-- An objective stop with no NPC: the quest as heading, then what is left to do.
-- alone: the tooltip holds nothing else, so sources are listed too.
local function Objective(tip, stop, action, alone)
	local id = action.id
	local entry = L.entries[id]
	local level = entry and entry.level or action.level or 0
	local color = GetQuestDifficultyColor(level > 0 and level or L.Level())
	local complete = action.kind == "turnin" or (entry and entry.complete)
	tip:AddDoubleLine(Mark(complete and "turnin" or "goal", id, ns.StopTone(stop)) .. action.title, W.Yards(stop.yards) or "",
		color.r, color.g, color.b, HOT[1], HOT[2], HOT[3])
	-- A party member's objective (Party.lua): what it asks for, and who is on it how far.
	local party = stop.party
	if party then
		if party.what then Line(tip, party.what, WHITE, true) end
		Tips.Under(tip, id, party.index, true)
		return
	end
	local _, _, where = R.Describe(stop)
	if where then Line(tip, where, DIM) end
	if complete then
		Line(tip, "Ready to turn in", GOLD, true)
		if alone then Tips.Under(tip, id, nil, true) end
		return
	end
	if not entry then return end
	for index, goal in ipairs(L.Goals(id)) do
		local own = not stop.objective or stop.objective == index
		if not goal.finished and goal.text and goal.text ~= "" and (own or alone) then
			Line(tip, goal.text, WHITE, true)
			if alone then
				if own then
					for _, token in ipairs(goal.tokens) do GoalLines(tip, token, STOP_SOURCES, 2) end
				end
				Tips.Under(tip, id, index, 2)
			end
		end
	end
end

-- An NPC stop: name, distance and a line per quest. Duplicate quest records are listed once.
local function Person(tip, stop, alone)
	local first = stop.actions[1]
	if not stop.who and first and #stop.actions == 1 and first.kind ~= "pickup" then
		return Objective(tip, stop, first, alone)
	end
	local indent = nil
	if stop.who then
		local _, _, where = R.Describe(stop)
		Double(tip, stop.who, W.Yards(stop.yards), WHITE, HOT)
		if where then Line(tip, where, DIM) end
		indent = true
	end
	local seen, listed, more = {}, 0, 0
	for _, action in ipairs(stop.actions) do
		local key = action.kind .. action.title
		if not seen[key] then
			seen[key] = true
			if listed >= MAX_QUESTS then
				more = more + 1
			elseif action.kind == "pickup" then
				listed = listed + 1
				OfferLine(tip, action, indent)
			else
				listed = listed + 1
				LogLine(tip, action, indent)
				if alone and action.kind == "turnin" then Tips.Under(tip, action.id, nil, Under(indent)) end
			end
		end
	end
	if more > 0 then Line(tip, ("and %d more"):format(more), DIM, indent) end
end

-- The objective index a guide line names ("complete 22,1").
local function ObjectiveOf(line)
	return line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1
end

-- A step's heading: its NPC, else its first unfinished line (returned so it isn't listed again).
local function StepHead(view)
	if view.who then return view.who, nil end
	for _, line in ipairs(view.lines) do
		if not line.done then return Shy.UI.PlainText(line.text), line end
	end
	return "Step " .. view.step.index, nil
end

-- Adds a step's unfinished lines; returns whether there were any.
--   said: the heading line, omitted. detail: also list objective sources. tasks: tasks only, no advice.
local function StepLines(tip, view, said, indent, detail, tasks)
	local under = Under(indent)
	local any = false
	for _, line in ipairs(view.lines) do
		if not line.done and line ~= said and (not tasks or line.can or line.mark) then
			any = true
			tip:AddLine(Pad(indent) .. ns.Bullet(line) .. line.text, WHITE[1], WHITE[2], WHITE[3], true)
			if detail and line.command == "complete" and line.id and L.Has(line.id) then
				local index = ObjectiveOf(line)
				local goal = L.Goals(line.id)[index]
				for _, token in ipairs(goal and not goal.finished and goal.tokens or {}) do GoalLines(tip, token, STOP_SOURCES, under) end
				Tips.Under(tip, line.id, index, under)
			end
		end
	end
	return any
end

-- "13-15 Westfall, step 8 of 70", numbered as the card does (steps for this character only).
local function StepCount(views)
	local view = views[1]
	local first, total = ns.Guide.Number(view.step.index, view.guide)
	if #views == 1 then return ("%s, step %d of %d"):format(view.guide.name, first, total) end
	local last = ns.Guide.Number(views[#views].step.index, view.guide)
	if last - first == #views - 1 then return ("%s, steps %d-%d of %d"):format(view.guide.name, first, last, total) end
	return ("%s, step %d of %d and %d more here"):format(view.guide.name, first, total, #views - 1)
end

-- A guide step. A pin for several steps at one place (stop.views) lists the first in full
-- and the rest by their tasks.
local function GuideStep(tip, stop)
	local views = stop.views or { stop.view }
	local several = #views > 1
	local title, said = StepHead(views[1])
	Double(tip, title, W.Yards(stop.yards), WHITE, HOT)
	Line(tip, StepCount(views), DIM)
	StepLines(tip, views[1], said, several, true, false)
	local last = title
	for i = 2, math.min(#views, MAX_STEPS) do
		local view = views[i]
		local head, line = StepHead(view)
		-- Consecutive steps with the same NPC share one heading.
		if head ~= last then Line(tip, head, WHITE) end
		last = head
		if not StepLines(tip, view, line, true, false, true) and not line then
			-- No tasks, only advice: show its first line.
			for _, each in ipairs(view.lines) do
				if not each.done then
					tip:AddLine(Pad(true) .. each.text, DIM[1], DIM[2], DIM[3], true)
					break
				end
			end
		end
	end
	local more = #views - MAX_STEPS
	if more > 0 then Line(tip, ("and %d more step%s here"):format(more, more == 1 and "" or "s"), DIM) end
end

local function Flight(tip, stop)
	local title, lines = R.Describe(stop)
	Double(tip, title, W.Yards(stop.yards), WHITE, HOT)
	for _, line in ipairs(lines) do Line(tip, line, DIM) end
	Line(tip, "Faster than walking to your next step", DIM)
end

function Tips.Stop(tip, stop)
	if stop.kind == "guide" then
		GuideStep(tip, stop)
		-- A catch-up step from earlier in the guide (Guide.lua, Catchup).
		local why = ns.CATCH_WHY[stop.catch]
		if why then Line(tip, why .. (stop.offered and " It's a bit off your route." or ""), GOLD) end
		return
	end
	if stop.kind == "zone" then return Zone(tip, stop) end
	if stop.kind == "fly" then return Flight(tip, stop) end
	if stop.kind == "errand" then
		local title, lines = R.Describe(stop)
		Double(tip, title, W.Yards(stop.yards), WHITE, HOT)
		for _, line in ipairs(lines) do Line(tip, line, DIM) end
		if stop.tip then stop.tip(tip) end
		return
	end
	-- A pin merged from several that would overlap (Pins.lua).
	local members = stop.members
	if members then
		for i = 1, math.min(MAX_PEOPLE, #members) do Person(tip, members[i], false) end
		if #members > MAX_PEOPLE then Line(tip, ("and %d more here"):format(#members - MAX_PEOPLE), DIM) end
		return
	end
	Person(tip, stop, true)
end

-- Shown through Shy.Hover, not GameTooltip. The builders above write to any object with
-- AddLine / AddDoubleLine:
--   local lines = Tips.Lines(); Tips.Quest(lines, id, true)
--   Tips.Open(owner, lines, { side = "LEFT", hints = { { "left", "Point the way" } } })
--   Tips.Close(owner)
function Tips.Lines()
	return Shy.Hover.Lines()
end

function Tips.Open(owner, lines, opts)
	return Shy.Hover.ShowLines(owner, lines, opts)
end

function Tips.Close(owner)
	Shy.Hover.Hide(owner)
end

-- Shows a stop's hover beside `owner` (a pin or a row): CardHover's layout when it has one,
-- else plain lines. hints: overrides the default click hints (the map's pins). mini: a minimap pin's,
-- which stands beside the minimap.
function Tips.ShowStop(owner, stop, side, hints, mini)
	if not hints then
		if stop.kind == "guide" then
			hints = { { "left", stop.manual and "Mark done" or "Point the way" } }
		elseif stop.kind == "fly" then
			hints = { { "left", "Point the way" } }
		elseif stop.kind == "errand" then
			hints = { { "left", stop.hint or "Point the way" } }
		else
			hints = { { "left", stop.chosen and "Remove from my route" or "Go here next" } }
		end
	end
	-- CardHover.lua may not be loaded: a file new to the TOC needs a client restart. A party member's
	-- objective isn't the player's to plan, so it has the plain lines.
	if not stop.party and ns.CardHover and ns.CardHover.Beside(owner, stop, hints, side, mini) then return end
	local lines = Tips.Lines()
	Tips.Stop(lines, stop)
	Tips.Open(owner, lines, { side = not mini and side or nil, hints = hints, outside = mini and Minimap or nil, gap = mini and 10 or nil })
end

-- A step as the guide window lists it: every line, done ones dimmed.
-- state: "todo", "done" or "skipped", as G.View returned it.
function Tips.Step(tip, view, state)
	local title = view.who or (view.lines[1] and Shy.UI.PlainText(view.lines[1].text)) or ("Step " .. view.number)
	local yards
	if view.north and view.continent == W.continent and W.Known() then
		yards = W.Between(W.north, W.west, view.north, view.west)
	end
	Double(tip, title, W.Yards(yards), WHITE, HOT)
	Line(tip, StepCount({ view }), DIM)
	local quiet = state ~= "todo"
	for _, line in ipairs(view.lines) do
		local text = state == "skipped" and Shy.UI.PlainText(line.text) or (ns.Bullet(line) .. line.text)
		local color = (quiet or line.done) and DIM or WHITE
		tip:AddLine(text, color[1], color[2], color[3], true)
	end
	if state == "skipped" then
		local index = view.step.index
		Line(tip, view.absent and "Skipped because you can't take its quest"
			or (view.skipped ~= index and ("Skipped with step " .. ns.Guide.Number(view.skipped))) or "Skipped", GOLD)
	elseif state == "done" then
		Line(tip, "Done", GOOD)
	end
end

function Tips.ShowStep(owner, view, state)
	if ns.CardHover then
		Shy.Hover.Show(owner, ns.CardHover.StepContent(view, state), { side = "LEFT", keep = true })
		return
	end
	local lines = Tips.Lines()
	Tips.Step(lines, view, state)
	Tips.Open(owner, lines, { side = "LEFT", hints = { { "left", "Step options" } } })
end
