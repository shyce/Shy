-- Builds Shy.Hover content for a route stop: head (mark, name, dial), "To do" rows, "Where" in words,
-- "Pays" (turn-in XP on the level bar) and mouse hints.
--
-- An errand supplies its own sections through stop.hover() (Train.lua, Bags.lua).
-- Show is for a card row, Beside for a map or minimap pin, StepContent for the guide window's list.
-- Show and Beside return false for a stop with no form here (a zone); Tips.ShowStop covers those.
-- A kept (clicked) hover follows its stop across route rebuilds (Follow), and only a click lets it go.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide
local UI = Shy.UI
local C = UI.colors

local CardHover = {}
ns.CardHover = CardHover

local MOST_ROWS = 10         -- rows per step
local MOST_STEPS = 4         -- steps listed for a merged pin
local MOST_PEOPLE = 5        -- members listed for a merged pin
-- What an objective is got from, on its hovers: how many are named for one objective, and for each of
-- several on one hover (the lit ground's: two objectives name two each, more than that one each).
local HUNT = { most = 3, shared = { 3, 2 }, least = 1 }

local MarkSeat = ns.MarkSeat   -- a mark (Marks.lua) on a hover seat

-- A hover glyph on the head seat, for a stop with no mark of its own (an errand).
local function GlyphSeat(glyph)
	return { key = "shyquest-glyph", set = function(seat)
		if not seat.picture then
			seat.picture = seat:CreateTexture(nil, "ARTWORK")
			seat.picture:SetPoint("TOPLEFT", 2, -2)
			seat.picture:SetPoint("BOTTOMRIGHT", -2, 2)
		end
		Shy.Hover.Glyph(seat.picture, glyph, seat:GetWidth() - 4)   -- its size picks the drawing made for it
		UI.Tint(seat.picture, C.hot)
	end }
end

local ERRAND_GLYPH = { train = "book", sell = "bag", talent = "star" }

local function GoalGlyph(goal)
	for _, token in ipairs(goal and goal.tokens or {}) do
		if token.kind == "c" or token.kind == "k" then return "kill" end
		if token.kind == "o" then return "use" end
		if token.kind == "i" then return "loot" end
	end
	if goal and goal.type == "monster" then return "kill" end
	if goal and goal.type == "object" then return "use" end
	return "loot"
end

-- Objective text without its "n/m" count, which the row shows at the right.
local function Counted(text)
	text = (text or ""):gsub("^%s*%d+/%d+%s+", ""):gsub("%s*:%s*%d+/%d+%s*$", "")
	return text
end

local function Experience(id)
	local xp = GetQuestLogRewardXP(id)
	return xp and xp > 0 and xp or nil
end

local function XpText(xp)
	return ("+%s XP"):format(BreakUpLargeNumbers(xp))
end

local function GoalRow(id, index, goal)
	local row = { glyph = GoalGlyph(goal), tint = ns.ToneColor(ns.QuestKind(id, index)), text = Counted(goal.text) }
	if goal.need and goal.need > 0 then
		row.count = { goal.have or 0, goal.need }
		row.right = ("%d/%d"):format(goal.have or 0, goal.need)
	end
	return row
end

-- What an objective is after: the NPCs its goal kills or that drop its item, each with the chance
-- in a hundred that it drops (nil where the data has none, or for a kill).
local function Quarry(goal)
	local out, seen = {}, {}
	local function Add(npc, chance)
		if npc and not seen[npc] then
			seen[npc] = true
			out[#out + 1] = { npc = npc, chance = chance }
		end
	end
	for _, token in ipairs(goal and goal.tokens or {}) do
		if token.kind == "c" then
			Add(token.id)
		elseif token.kind == "k" then
			for _, id in ipairs(token.ids) do Add(id) end
		elseif token.kind == "i" then
			for _, each in ipairs(D.Droppers(token.id)) do Add(each.npc, each.chance) end
		end
	end
	return out
end

-- Names said once each: "a Kolkar" for kin that share their first words (the only way they are
-- told apart is the rest), else "A or B", "A, B or others".
local function Either(names, kin)
	if #names == 1 then return names[1] end
	if kin then
		local first = {}
		for word in names[1]:gmatch("%S+") do first[#first + 1] = word end
		local shared = #first - 1
		for i = 2, #names do
			local n, words = 0, {}
			for word in names[i]:gmatch("%S+") do words[#words + 1] = word end
			while n < shared and n < #words - 1 and words[n + 1] == first[n + 1] do n = n + 1 end
			shared = n
		end
		if shared > 0 then return "a " .. table.concat(first, " ", 1, shared) end
	end
	if #names == 2 then return names[1] .. " or " .. names[2] end
	return names[1] .. ", " .. names[2] .. " or others"
end

local SUMMON_NAME = {
	d = function(id) return (D.Npc(id) or {}).name end,
	o = function(id) return (D.Object(id) or {}).name end,
	i = function(id) return (D.Item(id) or {}).name or C_Item.GetItemNameByID(id) end,
	q = function(id) return (D.Quest(id) or {}).name end,
}
SUMMON_NAME.f, SUMMON_NAME.e = SUMMON_NAME.d, SUMMON_NAME.q
local SUMMON_WORDS = { f = "Joins the fight with %s", o = "Appears when you use the %s", i = "Appears when you use %s",
	q = "Appears when you accept %s", e = "Appears when you hand in %s" }

-- What brings out an NPC that stands nowhere until then, in a sentence (Data/Summons.lua), or nil.
local function Summoned(npc)
	for _, how in ipairs(D.Summons(npc) or {}) do
		local names, seen = {}, {}
		for _, id in ipairs(how.ids) do
			local name = SUMMON_NAME[how.kind] and SUMMON_NAME[how.kind](id)
			if name and name ~= "" and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
		if #names > 0 then
			local who = Either(names, how.kind == "d" or how.kind == "f")
			if how.kind ~= "d" then return SUMMON_WORDS[how.kind]:format(who) end
			if how.chance >= 100 then return ("Appears when %s dies"):format(who) end
			return ("Appears when %s dies, about 1 in %d kills"):format(who, math.floor(100 / how.chance + 0.5))
		end
	end
end
CardHover.Summoned = Summoned

-- Rows under an objective, for what its own line doesn't say: who it is got from where the head
-- doesn't name them (`who`, the guide's words for it: "Kill Verog the Dervish"), how seldom it drops,
-- and what brings out a quarry that stands nowhere until it is called.
--   title: the hover's head, never said again. who, names: the guide's words, and the names in them.
local function Under(goal, title, who, names)
	local rows = {}
	if not goal or goal.finished then return rows end
	local quarry = Quarry(goal)
	-- The one it is got from: the only one, or the one the guide names.
	local one = #quarry == 1 and quarry[1] or nil
	for _, each in ipairs(names and not one and quarry or {}) do
		local npc = D.Npc(each.npc)
		if npc and npc.name:lower() == names:lower() then one = each end
	end
	local chance = one and D.OneIn(one.chance)
	local said = who and names and title and names:lower() ~= title:lower() and who or nil
	local text = said and chance and (said .. ", " .. chance) or said or (chance and (chance:gsub("^%l", string.upper)))
	if text then rows[1] = { quiet = true, indent = 1, text = text } end
	local told = {}
	for i = 1, math.min(3, #quarry) do
		local words = Summoned(quarry[i].npc)
		if words and not told[words] then
			told[words] = true
			rows[#rows + 1] = { glyph = "note", tint = C.alert, color = C.alert, indent = 1, text = words }
		end
	end
	return rows
end

local COMMAND_GLYPH = { ["goto"] = "go", fly = "fly", fp = "fly", hs = "home", home = "home", xp = "up", trainer = "book",
	vendor = "bag", zone = "go", subzone = "go", collect = "loot", train = "book" }

local Folds = G.Folds

-- A guide step's lines as checklist rows, and the quests it turns in. Done lines stay, ticked; the first
-- open task is lit; advice lines are quiet and indented under their task. Each thing is said once:
-- a note that restates its objective folds into it, and under the objective stands only what is new.
--   quiet: the step is done or skipped, so nothing is lit. title: the hover's head.
local function StepRows(view, quiet, title)
	local rows, handIns, more = {}, {}, 0
	local lit = quiet
	local folds, skip = Folds(view.lines)
	local function Add(row)
		if #rows < MOST_ROWS then rows[#rows + 1] = row else more = more + 1 end
	end
	for _, line in ipairs(view.lines) do
		local row, under
		local task = line.can or line.mark or COMMAND_GLYPH[line.command] ~= nil or line.command == "complete"
		if skip[line] then
			-- (Folded into the objective under it.)
		elseif line.done then
			row = { done = true, text = UI.PlainText(line.text) }
		elseif line.mark == "pickup" then
			row = { seat = MarkSeat("pickup"), text = line.text }
		elseif line.mark == "turnin" then
			local xp = line.id and Experience(line.id)
			row = { seat = MarkSeat("turnin"), text = line.text, right = xp and XpText(xp) or nil, rightColor = C.alert }
			if line.id and L.Has(line.id) then handIns[#handIns + 1] = line.id end
		elseif line.command == "complete" and line.id then
			local index = line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1
			local goal = L.Goals(line.id)[index]
			row = goal and GoalRow(line.id, index, goal) or { glyph = "kill", tint = ns.ToneColor(ns.LineTone(line)), text = line.text }
			if goal then
				row.text = Counted(line.text)
				local fold = folds[line] or {}
				under = not quiet and Under(goal, title, fold.who and (fold.who .. (fold.aside and (" (" .. fold.aside .. ")") or "")), fold.names) or nil
			end
		elseif line.command == "collect" and line.id then
			-- An item to get, as an objective is: its count at the right, how seldom it drops under it.
			local text = UI.PlainText(line.text)
			local have, need = text:match(":%s*(%d+)/(%d+)%s*$")
			row = { glyph = "loot", tint = ns.ToneColor(ns.LineTone(line)), text = Counted(text) }
			if need then row.count, row.right = { tonumber(have), tonumber(need) }, have .. "/" .. need end
			local fold = folds[line] or {}
			local goal = { tokens = { { kind = "i", id = line.id } } }
			under = not quiet and Under(goal, title, fold.who and (fold.who .. (fold.aside and (" (" .. fold.aside .. ")") or "")), fold.names) or nil
		elseif task then
			row = { glyph = COMMAND_GLYPH[line.command] or "go", text = line.text }
		else
			row = { text = line.text, quiet = true, indent = #rows > 0 and 2 or 0 }
		end
		if row then
			if task and not line.done and not lit then
				lit = true
				row.lit = true
			end
			if quiet then row.quiet, row.color = true, nil end
			Add(row)
			for _, extra in ipairs(under or {}) do Add(extra) end
		end
	end
	if more > 0 then rows[#rows + 1] = { glyph = "note", quiet = true, text = ("and %d more"):format(more) } end
	return rows, handIns
end

-- The quests' own words, as the quest log has them, for the quests of `actions` that are in your log (the
-- game gives the text of no other): a section for each, titled with the quest's name when there are several.
-- However long, it keeps to a few lines on the hover and scrolls there (Shy.Hover's story block).
-- (The words are the log's: L.Text.)
local function StoryOf(id)
	local text = L.Text(id)
	return text and text.story
end

local function Story(actions)
	local found, seen = {}, {}
	for _, action in ipairs(actions or {}) do
		local id = action.id
		if id and not seen[id] and L.Has(id) then
			seen[id] = true
			local story = StoryOf(id)
			if story then found[#found + 1] = { name = action.title, text = story } end
		end
	end
	local sections = {}
	for _, one in ipairs(found) do
		-- (Paragraphs a blank line apart, however the game spaced them.)
		local story = one.text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n%s*\n[%s\n]*", "\n\n")
		sections[#sections + 1] = { title = #found > 1 and one.name or "Quest text", story = story }
	end
	return sections
end

-- Rows of a non-guide stop: one per quest, or the open objectives of a quest in progress.
local function ActionRows(stop)
	local rows, handIns, seen = {}, {}, {}
	for _, action in ipairs(stop.actions) do
		local key = action.kind .. action.title
		if not seen[key] and #rows < MOST_ROWS then
			seen[key] = true
			if action.kind == "pickup" then
				local level = action.level or 0
				rows[#rows + 1] = { seat = MarkSeat("pickup"), text = action.title, right = level > 0 and tostring(level) or nil, rightColor = C.dim }
			elseif action.kind == "turnin" then
				local xp = Experience(action.id)
				rows[#rows + 1] = { seat = MarkSeat("turnin"), text = action.title, right = xp and XpText(xp) or nil, rightColor = C.alert }
				handIns[#handIns + 1] = action.id
			else
				for index, goal in ipairs(L.Goals(action.id)) do
					local own = not stop.objective or stop.objective == index
					if not goal.finished and goal.text and goal.text ~= "" and own and #rows < MOST_ROWS then
						rows[#rows + 1] = GoalRow(action.id, index, goal)
						for _, extra in ipairs(Under(goal)) do
							if #rows < MOST_ROWS then rows[#rows + 1] = extra end
						end
					end
				end
			end
		end
	end
	if rows[1] and #rows > 1 then rows[1].lit = true end
	return rows, handIns
end

-- "to the north-east", from the player.
local COMPASS = { "north", "north-west", "west", "south-west", "south", "south-east", "east", "north-east" }
local function Direction(stop)
	if not (stop.north and W.Known() and stop.continent == W.continent) then return nil end
	local north, west = stop.north - W.north, stop.west - W.west
	if north * north + west * west < 30 * 30 then return "right here" end
	local turn = math.atan2(west, north)                -- 0 north, increasing to the west
	local index = math.floor(turn / (math.pi / 4) + 0.5) % 8
	return "to the " .. COMPASS[index + 1]
end

-- What a hover has said already, as lower-case words to look names up in: its head and every row.
local function Said(content)
	local said = {}
	local function Note(text)
		if text and text ~= "" then said[UI.PlainText(text):lower()] = true end
	end
	Note(content.title)
	for _, section in ipairs(content.sections) do
		Note(section.title)
		for _, row in ipairs(section.rows or {}) do
			Note(row.text)
			-- (The name inside "Kill Verog the Dervish".)
			Note(row.text and UI.PlainText(row.text):match("^%a+ (.+)$"))
		end
	end
	return said
end

-- The "Where" section, in words: what is found there where the hover hasn't named it already (`said`,
-- Said's), else who or the zone; under it the zone, the way to it and the level it is on.
local function Where(stop, said)
	said = said or {}
	if not stop.map or not stop.x then return nil end
	local found = {}
	for _, name in ipairs(ns.Ground and ns.Ground.Names(stop, stop.map) or {}) do
		if #found < 2 and name and name ~= "" and not said[name:lower()] then found[#found + 1] = name end
	end
	local zone, way = W.MapName(stop.map), Direction(stop)
	local who = stop.who and not said[stop.who:lower()] and stop.who or nil
	local words = #found > 0 and table.concat(found, ", ") or who or zone or ""
	local more = zone and way and (zone .. ", " .. way) or zone or way
	if words == zone then more = way end
	-- (And the level it is on, where that isn't the ground.)
	local level = W.LevelWords(stop)
	if level then more = more and (more .. ", " .. level) or level end
	return { title = "Where", words = words, more = more }
end

-- The "Pays" section: turn-in XP, shown on the level bar.
local function Pays(handIns)
	local total, names = 0, {}
	for _, id in ipairs(handIns) do
		local xp = Experience(id)
		if xp then
			total = total + xp
			names[#names + 1] = (L.entries[id] or {}).title
		end
	end
	if total == 0 then return nil end
	local have, most = UnitXP("player") or 0, UnitXPMax("player") or 0
	local levels = most > 0 and have + total >= most
	local row = { glyph = "up", tint = C.alert, text = UI.Wrap(C.alert, XpText(total)) .. (#names == 1 and names[1] and ("  " .. UI.Wrap(C.dim, names[1])) or ""),
		right = levels and ("Level %d"):format(L.Level() + 1) or nil, rightColor = C.alert }
	return { title = "Pays", rows = { row }, bar = most > 0 and { have = have / most, gain = total / most } or nil }
end

-- The way to a stop, drawn as the quest window draws its own (Card.lua): the arrow in the ring, the
-- distance in words. `lead`: the stop the window is heading for already shows both there, so while
-- the window is up its hover keeps the ring with only the stop's mark in it.
-- Standing on the ground where what the stop asks for is found (stop.among, Route.lua) there is no way
-- to show: the ring keeps the stop's mark.
local function Dial(stop, lead)
	if lead and select(2, ns.CardBox()) then return { seated = true } end
	if not stop.map then return nil end
	if stop.among then return { seated = true } end
	return {
		arrow = ns.MEDIA .. "Arrow",
		says = function() return W.Far(stop) end,
		yards = function() return stop.yards end,
		turn = function()
			-- (Along the way the maps draw, as the card's own arrow points.)
			if stop.north then return (W.Heading(stop.continent, stop.north, stop.west)) end
		end,
	}
end

local STRIPS = { turnin = "Turn in", pickup = "Pick up", goal = "Objective" }
local NOTES = { clock = "ON A TIMER", failed = "FAILED QUEST", grind = "BETTER THAN GRINDING", class = "FOR YOUR CLASS" }

-- A step's name: its NPC, or its first open line.
local function StepName(view)
	if view.who then return view.who end
	for _, line in ipairs(view.lines) do
		if not line.done then return UI.PlainText(line.text) end
	end
	return view.lines[1] and UI.PlainText(view.lines[1].text) or ("Step " .. G.Number(view.step.index, view.guide))
end

-- A step's mark: that of its first open line with one.
local function StepSeat(view)
	for _, line in ipairs(view.lines) do
		if not line.done and line.mark then
			return MarkSeat(line.mark, nil, nil, line.mark == "goal" and ns.LineTone(line) or nil)
		end
	end
	return MarkSeat("guide")
end

local function StepHead(content, view)
	local number, total = G.Number(view.step.index, view.guide)
	content.note = view.guide.name
	content.title = StepName(view)
	content.sub = ("Step %d of %d"):format(number, total)
	content.seat = StepSeat(view)
end

-- Identifies the same stop across route rebuilds.
local function Key(stop)
	if stop.kind == "guide" then return "guide:" .. stop.view.step.index end
	if stop.kind == "errand" then return "errand:" .. tostring(stop.errand) end
	if stop.kind == "way" then return "way:" .. stop.way.id end
	local first = stop.actions and stop.actions[1]
	return ("%s:%s:%s:%s:%s"):format(stop.kind, first and first.id or "", stop.map or 0, stop.x or 0, stop.y or 0)
end
CardHover.Key = Key

-- Shy.Hover content for a stop, or nil for a kind with no form here.
--   way: with the way to it whatever it is (a map or minimap pin's hover, and any hover once pinned).
--   Without it the stop the window is heading for has none: the window's own dial shows that.
local function Whole(stop, lead, way)
	local sections = {}
	-- The window's dial is on the route's first stop, whatever kind it is.
	local heading = R.stops[1]
	local content = { sections = sections, dial = Dial(stop, not way and heading ~= nil and Key(stop) == Key(heading)) }
	-- A merged pin (Pins.lua): one section per member.
	if stop.members then
		local members = stop.members
		content.strip = "Several here"
		content.title = ("%d here"):format(#members)
		content.seat = MarkSeat(members[1].kind, nil, nil, ns.StopTone(members[1]))
		local handIns, all = {}, {}
		for i = 1, math.min(MOST_PEOPLE, #members) do
			local member = members[i]
			local rows, theirs = ActionRows(member)
			for _, row in ipairs(rows) do row.lit = nil end
			for _, id in ipairs(theirs) do handIns[#handIns + 1] = id end
			for _, action in ipairs(member.actions or {}) do all[#all + 1] = action end
			sections[#sections + 1] = { title = (R.Describe(member)), rows = rows }
		end
		if #members > MOST_PEOPLE then
			sections[#sections + 1] = { rows = { { quiet = true, text = ("and %d more here"):format(#members - MOST_PEOPLE) } } }
		end
		sections[#sections + 1] = Where(stop, Said(content))
		sections[#sections + 1] = Pays(handIns)
		return content
	end
	if stop.kind == "guide" then
		local view = stop.view
		content.strip = stop.catch and "Catching up" or stop.here and "Right here" or stop.side and "Along the way" or "Guide step"
		StepHead(content, view)
		local rows, handIns = StepRows(view, nil, content.title)
		sections[#sections + 1] = { title = "To do", rows = rows }
		-- Why a catch-up step is offered.
		local why = ns.CATCH_WHY and ns.CATCH_WHY[stop.catch]
		if why then
			rows[#rows + 1] = { glyph = "note", tint = C.alert, color = C.alert,
				text = why .. (stop.offered and " It's a bit off your route." or "") }
		end
		-- A pin merging several steps at one place: the others follow in guide order.
		local views = stop.views or {}
		if #views > 1 then
			-- Step numbers count this character's steps only, as on the card.
			local first, total = G.Number(view.step.index, view.guide)
			local last = G.Number(views[#views].step.index, view.guide)
			content.sub = last - first == #views - 1 and ("Steps %d-%d of %d"):format(first, last, total)
				or ("Step %d of %d and %d more here"):format(first, total, #views - 1)
		end
		for i = 2, math.min(#views, MOST_STEPS) do
			local more, theirs = StepRows(views[i], nil, StepName(views[i]))
			for _, row in ipairs(more) do row.lit = nil end
			for _, id in ipairs(theirs) do handIns[#handIns + 1] = id end
			sections[#sections + 1] = { title = "Then: " .. StepName(views[i]), rows = more }
		end
		if #views > MOST_STEPS then
			sections[#sections + 1] = { rows = { { quiet = true, text = ("and %d more steps here"):format(#views - MOST_STEPS) } } }
		end
		local open = {}
		for _, one in ipairs(#views > 0 and views or { view }) do
			for _, action in ipairs(one.actions) do
				if not action.done then open[#open + 1] = action end
			end
		end
		for _, section in ipairs(Story(open)) do sections[#sections + 1] = section end
		sections[#sections + 1] = Where(stop, Said(content))
		sections[#sections + 1] = Pays(handIns)
		content.hints = { { "left", stop.manual and "Mark done" or "Point the way" }, { "right", "Done, skip, back" } }
	elseif stop.kind == "errand" then
		content.strip = stop.strip or (stop.first and "On your way" or "Close by")
		content.note = stop.caption
		content.title = stop.title
		content.sub, content.subHot = stop.lines and stop.lines[1], true
		local sign = ns.StopMark(stop)
		content.seat = sign ~= stop.kind and MarkSeat(sign, nil, nil, ns.StopTone(stop)) or GlyphSeat(ERRAND_GLYPH[stop.errand] or "note")
		local own = stop.hover and stop.hover()
		for _, section in ipairs(own or {}) do sections[#sections + 1] = section end
		if not own then
			local rows = {}
			for i = 2, #(stop.lines or {}) do rows[#rows + 1] = { glyph = "note", text = stop.lines[i] } end
			if #rows > 0 then sections[#sections + 1] = { title = "To do", rows = rows } end
		end
		sections[#sections + 1] = Where(stop, Said(content))
		content.hints = { { "left", stop.hint or (stop.map and "Point the way" or "Open") } }
		if stop.menu or R.CanHush(stop.errand) then content.hints[2] = { "right", stop.menuHint or "Not now, turn off" } end
	elseif stop.kind == "way" then
		-- A stop of your own route (Plan.lua): where it is.
		content.strip, content.note = "Your route", stop.caption
		content.title = stop.title
		content.sub, content.subHot = stop.lines[1], true
		content.seat = MarkSeat("way")
		sections[#sections + 1] = Where(stop, Said(content))
		content.hints = { { "left", "Show on the map" }, { "right", "Route" } }
	elseif stop.kind == "fly" then
		local title, lines = R.Describe(stop)
		-- (A boat or a zeppelin says its own: stop.strip, stop.note.)
		content.strip, content.title = stop.strip or "Fly there", title
		content.sub, content.subHot = lines[1], true
		content.seat = GlyphSeat("fly")
		sections[1] = { title = "To do", rows = { { glyph = "fly", text = title }, { glyph = "note", quiet = true, text = stop.note or "Faster than walking" } } }
		sections[2] = Where(stop, Said(content))
		content.hints = { { "left", "Point the way" } }
	elseif stop.kind == "turnin" or stop.kind == "pickup" or stop.kind == "goal" then
		local title, _, where = R.Describe(stop)
		content.strip = STRIPS[stop.kind]
		content.note = stop.chosen and "HEADING TO" or NOTES[stop.detour] or (stop.detour and "ON YOUR WAY") or nil
		content.title = title
		content.sub = where
		content.seat = MarkSeat(stop.kind, nil, nil, ns.StopTone(stop))
		local rows, handIns = ActionRows(stop)
		sections[#sections + 1] = { title = "To do", rows = rows }
		for _, section in ipairs(Story(stop.actions)) do sections[#sections + 1] = section end
		sections[#sections + 1] = Where(stop, Said(content))
		sections[#sections + 1] = Pays(handIns)
		-- Compare by Key, not identity: a row may briefly hold the previous route's stop table.
		local leads = lead ~= nil and Key(stop) == Key(lead)
		content.hints = { { "left", leads and not stop.chosen and "Point the way" or stop.chosen and "Let the route choose" or "Head here first" },
			{ "right", "More" } }
	else
		return nil
	end
	return content
end

-- A card row's hover ---------------------------------------------------------------------------------
-- It stands beside the row, which already says the step's name, every line with its count, what a
-- hand-in pays and, in the card's head, the step's number. So it says only what the row can't: what
-- the subject is, what an open objective takes that isn't plain (who drops it and how seldom, what
-- brings out a target that stands nowhere), what a quest to pick up will ask, where a quest goes back
-- to. A map pin's hover and a kept one keep the whole form (Whole).

-- What the subject is, for the line over its name: a person's title, a foe's level and rank.
local function Kind(thing)
	if not thing then return nil end
	if thing.title then return thing.title end
	local ours = (UnitFactionGroup("player") or ""):sub(1, 1)
	if (thing.maxLevel or 0) > 0 and not (thing.side or ""):find(ours, 1, true) then return D.LevelText(thing) end
end

-- The NPC a stop is named for, or nil: a guide step's subject (G.Who), a quest stop's own.
local function Subject(stop)
	local view = stop.view
	if not view then return stop.thing end
	for _, target in ipairs(view.targets or {}) do
		if target.npc and target.name == view.who then return D.Npc(target.npc) end
	end
end

-- What a quest not yet taken will ask for, from the data: a row for each thing, with what isn't plain
-- about it under it (Under).
local function Asks(id)
	local rows = {}
	local quest = D.Quest(id)
	for _, token in ipairs(quest and quest.goals or {}) do
		local row
		if token.kind == "c" or token.kind == "k" then
			local names = {}
			for _, npc in ipairs(token.ids or { token.id }) do
				local record = D.Npc(npc)
				if record then names[#names + 1] = record.name end
			end
			if #names > 0 then row = { glyph = "kill", tint = ns.ToneColor("kill"), text = Either(names) } end
		elseif token.kind == "i" then
			local item = D.Item(token.id)
			if item then row = { glyph = "loot", tint = ns.ToneColor(ns.ItemKind(token.id)), text = item.name } end
		elseif token.kind == "o" then
			local object = D.Object(token.id)
			if object then row = { glyph = "use", tint = ns.ToneColor("gather"), text = object.name } end
		end
		if row and #rows < MOST_ROWS then
			rows[#rows + 1] = row
			for _, extra in ipairs(Under({ tokens = { token } })) do rows[#rows + 1] = extra end
		end
	end
	return rows
end

-- Who a quest goes back to once done, where, and what it pays: a row, or nil for one handed in to
-- someone the hover already names (`said`, Said's). The zone only where it isn't the stop's (`map`).
local function Back(id, said, map)
	local quest = D.Quest(id)
	local ender = quest and R.Usable(quest.ends)
	local thing = ender and D.Thing(ender.kind, ender.id)
	if not thing or said[thing.name:lower()] then return nil end
	local place = thing.places and thing.places[1]
	local zone = place and place.map ~= map and W.MapName(place.map)
	local xp = Experience(id) or quest.xp
	return { seat = MarkSeat("turnin"), text = thing.name .. (zone and UI.Wrap(C.dim, "  " .. zone) or ""),
		right = xp and xp > 0 and XpText(xp) or nil, rightColor = C.alert }
end

local function Docked(stop)
	local kind = stop.kind
	if stop.members or not (kind == "guide" or kind == "pickup" or kind == "turnin" or kind == "goal") then return nil end
	-- (The window's dial is on the route's first stop, whatever kind it is.)
	local heading = R.stops[1]
	local content = { sections = {}, dial = Dial(stop, heading ~= nil and Key(stop) == Key(heading)) }
	local sections = content.sections
	local view = stop.view
	local picks, back, handed, open = {}, {}, {}, {}
	local function Objective(id, goal, fold)
		fold = fold or {}
		local who = fold.who and (fold.who .. (fold.aside and (" (" .. fold.aside .. ")") or ""))
		local rows = Under(goal, content.title, who, fold.names)
		if #rows > 0 then sections[#sections + 1] = { title = Counted(goal.text), rows = rows } end
		if id then back[#back + 1] = id end
	end
	if view then
		content.title, content.seat = StepName(view), StepSeat(view)
		local folds = Folds(view.lines)
		for _, line in ipairs(view.lines) do
			if not line.done and line.id then
				if line.command == "complete" then
					local index = line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1
					local goal = L.Goals(line.id)[index]
					if goal and not goal.finished then Objective(line.id, goal, folds[line]) end
				elseif line.command == "collect" then
					Objective(nil, { text = UI.PlainText(line.text), tokens = { { kind = "i", id = line.id } } }, folds[line])
				elseif line.mark == "pickup" then
					picks[#picks + 1] = line.id
				elseif line.mark == "turnin" then
					handed[line.id] = true
				end
			end
		end
		for _, action in ipairs(view.actions) do
			if not action.done then open[#open + 1] = action end
		end
	else
		content.title = (R.Describe(stop))
		content.seat = MarkSeat(kind, nil, nil, ns.StopTone(stop))
		for _, action in ipairs(stop.actions) do
			if action.kind == "pickup" then
				picks[#picks + 1] = action.id
			elseif action.kind == "turnin" then
				handed[action.id] = true
			else
				for index, goal in ipairs(L.Goals(action.id)) do
					if (not stop.objective or stop.objective == index) and not goal.finished and goal.text and goal.text ~= "" then
						Objective(action.id, goal)
					end
				end
			end
		end
		open = stop.actions
	end
	content.strip = Kind(Subject(stop))
	-- Why a catch-up step is offered: the card says it on the row it is heading for only.
	local why = ns.CATCH_WHY and ns.CATCH_WHY[stop.catch]
	if why and not (heading ~= nil and Key(stop) == Key(heading)) then
		table.insert(sections, 1, { rows = { { glyph = "note", tint = C.alert, color = C.alert,
			text = why .. (stop.offered and " It's a bit off your route." or "") } } })
	end
	-- Quests to pick up: what each will ask.
	for _, id in ipairs(picks) do
		local rows = Asks(id)
		if #rows > 0 then
			sections[#sections + 1] = { title = #picks > 1 and (D.Quest(id) or {}).name or "Asks for", rows = rows }
		end
		back[#back + 1] = id
	end
	-- Where each goes back to, unless that is here.
	local said, rows, seen = Said(content), {}, {}
	for _, id in ipairs(back) do
		local row = not seen[id] and not handed[id] and Back(id, said, stop.map)
		seen[id] = true
		if row and #rows < MOST_STEPS then rows[#rows + 1] = row end
	end
	if #rows > 0 then sections[#sections + 1] = { title = "Hand in to", rows = rows } end
	-- The quests' own words, for those in your log.
	for _, section in ipairs(Story(open)) do sections[#sections + 1] = section end
	return content
end

-- The color a stop's mark wears: its kind's, gold for a quest to pick up or hand in, nil for none (the
-- accent). A guide's step wears that of the line its mark is from.
local function Light(stop)
	if stop.members then stop = stop.members[1] end
	if stop.kind == "pickup" or stop.kind == "turnin" then return ns.MARK.gold end
	local tone = ns.StopTone(stop)
	if tone then return ns.ToneColor(tone) end
	for _, line in ipairs(stop.kind == "guide" and stop.view.lines or {}) do
		if not line.done and line.mark then
			if line.mark == "pickup" or line.mark == "turnin" then return ns.MARK.gold end
			tone = line.mark == "goal" and ns.LineTone(line)
			return tone and ns.ToneColor(tone) or nil
		end
	end
	return nil
end

-- The same for a pin on a map, as a card (Shy.Hover's, the form the game's own tooltips are drawn
-- in): the map is already under the mouse, so the words of where it is go, and with them the dial and
-- the level bar. The head is the mark and the name on a wash of the mark's color, what kind of stop it
-- is under the name and how far at the right; the lists follow, one list with no heading.
--   light: the mark's color (Light). far: the distance, or nil. stop: the card's `about`, which the
--   hover keeps as frame.about (OnKeep reads it there).
local SLIM_WIDE = 236
local DOT = "  \194\183  "
local function AsCard(content, light, far, stop)
	local body = {}
	for _, section in ipairs(content.sections) do
		if section.story then
			body[#body + 1] = { title = section.title, story = section.story, at = section.at }
		elseif not section.bar and section.rows and #section.rows > 0 then
			body[#body + 1] = { title = section.title, rows = section.rows }
		end
	end
	if #body == 1 and body[1].title == "To do" then body[1].title = nil end
	-- The line under the name: what kind of stop, in the mark's color; then where.
	-- A step of the guide says only its number.
	local key = {}
	local function Add(text, color)
		if not text or text == "" then return end
		if #key > 0 then key[#key + 1] = { text = DOT, color = C.dim } end
		key[#key + 1] = { text = text, color = color }
	end
	local sub = content.sub
	if content.strip ~= "Guide step" or not sub then Add(content.strip, light or C.hot) end
	Add(sub, (#key == 0 and (light or C.hot)) or (content.subHot and C.text) or C.dim)
	return { card = true, about = stop, title = content.title, seat = content.seat, light = light,
		kind = far, key = #key > 0 and key or nil, body = body, hints = content.hints, extras = content.extras,
		edge = content.edge }
end

-- How far a stop is, for a card's head: "Here" standing on it.
local function Far(stop)
	local here = stop.among or (stop.yards and stop.yards < 10)
	return here and "Here" or (stop.yards and W.Far(stop)) or nil
end

local function Slim(content, stop)
	return AsCard(content, Light(stop), Far(stop), stop)
end

-- An errand, a flight or a stop of your own route beside its card row (`row`), which has its name and its
-- first line already: the card's body says only what the row can't. Each of its lines the row hasn't
-- whole (cut short, or not shown at all); what the errand lists (stop.hover), else why the route asks it
-- of you (stop.tip); what leads, down a cliff or over water (`glide`). Kept (no row), every line.
local ASIDE = { errand = true, fly = true, way = true }
local function Aside(stop, row, glide)
	local seen = {}
	if row then
		local shown = { row.title }
		for _, words in ipairs(row.lines or {}) do shown[#shown + 1] = words end
		for _, words in pairs(shown) do
			if words:IsShown() and not words:IsTruncated() then seen[UI.PlainText(words:GetText() or "")] = true end
		end
	end
	local body = {}
	local function Say(text, color)
		if text and text ~= "" and not seen[UI.PlainText(text)] then body[#body + 1] = { text = text, color = color } end
	end
	local _, lines = R.Describe(stop)
	for _, text in ipairs(lines or {}) do Say(text) end
	local own = stop.kind == "errand" and stop.hover and stop.hover()
	for _, section in ipairs(own or {}) do
		if section.story then
			body[#body + 1] = { title = section.title, story = section.story, at = section.at }
		elseif section.rows and #section.rows > 0 then
			body[#body + 1] = { title = section.title, rows = section.rows }
		end
	end
	if not own and stop.tip then
		local said = Shy.Hover.Lines()
		stop.tip(said)
		for _, line in ipairs(said) do Say(line.text, C.dim) end
	end
	if glide then body[#body + 1] = { title = glide.title, rows = glide.rows } end
	return body
end

--   slim: for a map or minimap pin (Slim).
--   docked: for a card row, in the card form, saying only what the row can't (Docked; a stop with no
--   form there as a pin's). The row has the distance: the card says it only with `way` (kept, it may
--   be dragged off). The card is marked docked, so a kept one is filled the same way again. row: the
--   card row it stands beside, whose words it needn't say again (Aside). False for a card row's hover
--   with nothing the row doesn't say: there is none.
function CardHover.Content(stop, lead, way, slim, docked, row)
	local own = docked and Docked(stop)
	local content = own or Whole(stop, lead, way)
	-- What leads, down a cliff or over water: before where it is and what it pays.
	local heading = R.stops[1]
	local glide = content and heading and ns.Glide and Key(stop) == Key(heading) and ns.Glide.Section(stop)
	if glide then
		local at = #content.sections + 1
		for i, section in ipairs(content.sections) do
			if section.words or section.bar then
				at = i
				break
			end
		end
		table.insert(content.sections, at, glide)
	end
	if content and docked then
		-- The way, as the card's own arrow points: on every row but the one the card is heading for (its
		-- arrow is the card's), and on any kept one, which may be dragged off.
		local leads = heading ~= nil and Key(stop) == Key(heading)
		local pointed = (way or not leads) and stop.north ~= nil and not stop.among
		local card = AsCard(content, Light(stop), (way or pointed) and Far(stop) or nil, stop)
		if pointed then
			card.way = { arrow = ns.MEDIA .. "Arrow", says = function() return Far(stop) end,
				turn = function()
					if stop.north and stop.continent == W.continent then return (W.Heading(stop.continent, stop.north, stop.west)) end
				end }
		end
		local aside = ASIDE[stop.kind] and not stop.members
		if aside then
			-- (Under the name only what kind of stop it is: the row has its first line.)
			card.body = Aside(stop, row, glide)
			card.key = content.strip and { { text = content.strip, color = card.light or C.hot } } or nil
		end
		-- A tricky spot the player stands near (Spots.lua): its picture, before the rest.
		local spot = ns.Spots and ns.Spots.Block(stop)
		if spot then table.insert(card.body, 1, spot) end
		-- A row for an objective (a goal's, a guide step's): what it is got from, turning on the stage, as its
		-- mark's hover shows it (Hunted: the one builder every hover of an objective uses).
		local id, index = CardHover.ObjectiveOf(stop)
		local model = id and CardHover.Hunted(id, index)
		if model and (model.creature or model.display or model.file) then table.insert(card.body, 1, { model = model }) end
		card.docked = true
		if aside and #card.body == 0 and not card.way then return false end
		return card
	end
	return content and slim and Slim(content, stop) or content
end

-- What the lit ground under the mouse asks for (Ground.Under's hits: each kind of ground the point is
-- on, with the key's rows of that kind), as a pin's hover says it: what is done here, to what, and how
-- much of it is still to do. Where grounds lie over one another every one of them is said, each quest
-- under its own name: standing in the kills in the middle of a wide patch of loot, both apply. The card
-- stays short however much is here: each objective names fewer of what it is got from the more there are.
local HERE = { kill = "Kill here", loot = "Loot here", gather = "Gather here", talk = "Talk here", buy = "Buy here", go = "Go here", find = "Found here" }
local GROUND_GLYPH = { kill = "kill", loot = "loot", gather = "use", talk = "talk", buy = "buy", go = "go", find = "go" }
function CardHover.Ground(hits)
	local content = { strip = HERE[hits[1].kind] or "Here", sections = {} }
	if #hits > 1 then
		-- "Loot and kill here".
		local words = {}
		for i, hit in ipairs(hits) do
			local word = ns.KIND[hit.kind].word
			words[i] = i == 1 and word or word:lower()
		end
		content.strip = table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words] .. " here"
	end
	local by, said = {}, {}      -- quest -> its section; the objectives already listed
	local model, light          -- the stage: what the first objective here is got from, in its shade
	-- Whether a ground's row lists that objective: its own (or any, where the ground is the quest's as a
	-- whole), still open, with words.
	local function Listed(row, index, goal)
		return (not row.objective or row.objective == index) and not goal.finished and goal.text and goal.text ~= ""
	end
	-- The more objectives the hover lists, the fewer each names of what it is got from: the card stays short.
	local listed, counted = 0, {}
	for _, hit in ipairs(hits) do
		for _, row in ipairs(hit.rows) do
			local id = row.quest
			for index, goal in ipairs(id and L.entries[id] and L.Goals(id) or {}) do
				if Listed(row, index, goal) and not counted[id .. ":" .. index] then
					counted[id .. ":" .. index] = true
					listed = listed + 1
				end
			end
		end
	end
	local most = HUNT.shared[listed] or HUNT.least
	for _, hit in ipairs(hits) do
		local kind = hit.kind
		for _, row in ipairs(hit.rows) do
			local id = row.quest
			local entry = id and L.entries[id]
			-- (With no quest to name, the first thing here is the head, never a list cut short.)
			local name = entry and entry.title or (id and D.Name("quests", id)) or (row.names and row.names[1]) or row.text
			local section = by[name]
			if not section then
				section = { title = name, rows = {} }
				by[name] = section
				content.sections[#content.sections + 1] = section
				if not content.title then
					content.title = name
					content.seat = MarkSeat("goal", nil, nil, kind)
				end
			end
			-- The row's own objective; where the ground is the quest's as a whole (the game's area), all
			-- that is still open.
			local any = false
			for index, goal in ipairs(entry and L.Goals(id) or {}) do
				if Listed(row, index, goal) then
					any = true
					if not said[id .. ":" .. index] then
						said[id .. ":" .. index] = true
						-- As the objective's own hover has it (Hunted): the first one here on the stage, and under each
						-- objective's line what it is got from, how seldom it drops and its level.
						local staged, under, _, _, shade, hunted = CardHover.Hunted(id, index, nil, most)
						section.rows[#section.rows + 1] = GoalRow(id, index, goal)
						if staged and not model and (staged.creature or staged.display or staged.file) then model, light = staged, shade end
						-- (With nothing to fight for it, the ground's own row has said where: no line under.)
						for _, extra in ipairs((hunted or 0) > 0 and under or Under(goal)) do
							extra.indent = (extra.indent or 0) + 1
							section.rows[#section.rows + 1] = extra
						end
					end
				end
			end
			if not any and name ~= row.text then
				-- Nothing of the quest's to list: what is done here to what, each thing on a line of its own.
				for i, each in ipairs(row.names or { row.text }) do
					if each ~= name or i > 1 then
						section.rows[#section.rows + 1] = { glyph = GROUND_GLYPH[kind] or "go", tint = ns.ToneColor(kind), text = row.word .. " " .. each }
					end
				end
			end
		end
	end
	if not content.title then return nil end
	-- One quest: its name is the head, and its lines follow with no heading of their own. Several:
	-- the head says how many, and each has its heading.
	if #content.sections == 1 then
		content.sections[1].title = nil
	else
		content.title = ("%d quests here"):format(#content.sections)
	end
	-- As a pin's card, in the color of the ground on top. Under the mouse already: no distance. The stage
	-- turns under the lists at once.
	local card = AsCard(content, ns.ToneColor(hits[1].kind))
	if model then
		model.color = light or model.color
		card.body[#card.body + 1] = { model = model }
	end
	return card, SLIM_WIDE
end

-- A line of the route on the world map, as the pin it leads to says it (Beside): where it goes and what
-- is done there, under the name how it gets there ("Walk from 3", "Fly from 5"), at the right how far it
-- runs. A line takes no click, so there are no hints.
--   how: those words. far: the distance in words, or nil. color: the line's.
function CardHover.Leg(stop, how, far, color)
	local card = CardHover.Content(stop, R.Lead and R.Lead() or R.stops[1], true, true)
	if not card then return nil end
	local key = { { text = how, color = color or C.text } }
	for i, part in ipairs(card.key or {}) do
		if i == 1 then key[#key + 1] = { text = DOT, color = C.dim } end
		key[#key + 1] = part
	end
	card.key, card.kind, card.hints = key, far, nil
	return card, SLIM_WIDE
end

-- Content for a step in the guide window's list. `state` is G.View's: "todo", "done" or "skipped".
function CardHover.StepContent(view, state)
	local content = { sections = {} }
	StepHead(content, view)
	-- The list's row has the step's number and the list stands under the guide's name: the line over the
	-- name says what the subject is instead, or that the step is behind you.
	local subject
	for _, target in ipairs(view.targets or {}) do
		if target.npc and target.name == view.who then subject = D.Npc(target.npc) end
	end
	content.strip = state == "done" and "Done" or state == "skipped" and "Skipped" or Kind(subject)
	content.note, content.sub = nil, nil
	-- The step the window is heading for has its way on the window: here the ring keeps only its mark.
	local lead = R.stops[1]
	if lead ~= nil and lead.kind == "guide" and lead.view.step.index == view.step.index and select(2, ns.CardBox()) then
		content.dial = { seated = true }
	elseif view.north and view.continent == W.continent and W.Known() then
		content.dial = {
			arrow = ns.MEDIA .. "Arrow",
			says = function() return W.Yards(W.Between(W.north, W.west, view.north, view.west)) end,
			yards = function() return W.Between(W.north, W.west, view.north, view.west) end,
			turn = function() return (W.Heading(view.continent, view.north, view.west)) end,
		}
	end
	local rows = StepRows(view, state ~= "todo", content.title)
	if state == "skipped" then
		local index = view.step.index
		rows[#rows + 1] = { glyph = "note", tint = C.alert, color = C.alert, text = view.absent and "Skipped: you can't take its quest"
			or (view.skipped ~= index and ("Skipped with step " .. G.Number(view.skipped))) or "Skipped" }
	end
	content.sections[1] = { title = state == "todo" and "To do" or "Tasks", rows = rows }
	for _, section in ipairs(Story(view.actions)) do content.sections[#content.sections + 1] = section end
	content.hints = { { "left", "Step options" } }
	return content
end

-- One objective, as its row on the card and its mark on the map show it when pointed at: what it is got
-- from, turning on a stage (Shy.Hover's model block), over the facts the row can't say: who it is got
-- from and their level, how seldom it drops, what brings out one that stands nowhere until called. The
-- stage shows the item's icon (or the kind's emblem) until the game has the creature, and for an object.
local function ObjectiveStage(id, index, goal, color)
	local where = R.Objectives and R.Objectives(id)[index]
	local source = where and where.source
	local quarry = Quarry(goal)
	-- The one the stage shows (where the route sends you for it) first, then the quickest to have it from
	-- (R.SourceRanks: Stand's own measure), then the likeliest.
	local shown = source and source.id
	local ranks = R.SourceRanks and R.SourceRanks(id, index) or {}
	table.sort(quarry, function(a, b)
		if (a.npc == shown) ~= (b.npc == shown) then return a.npc == shown end
		local ra, rb = ranks[a.npc] or math.huge, ranks[b.npc] or math.huge
		if ra ~= rb then return ra < rb end
		return (a.chance or 100) > (b.chance or 100)
	end)
	local creature = source and (source.how == "kill" or source.how == "drops") and source.id or (quarry[1] and quarry[1].npc) or nil
	-- Nothing to fight for it: the object it is used or found in, as its own model.
	local object = not creature and source and (source.how == "use" or source.how == "holds") and source.id or nil
	local item
	for _, token in ipairs(goal.tokens or {}) do
		if token.kind == "i" then
			item = token.id
			break
		end
	end
	local icon = item and C_Item.GetItemIconByID(item) or nil
	local kind = ns.QuestKind(id, index)
	return { creature = creature, display = creature and D.Look("n", creature) or nil, file = object and D.Look("o", object) or nil,
		icon = icon, color = color,
		art = not icon and { ns.MEDIA .. "MarksLarge", coords = ns.MarkPicture(ns.ToneSign(kind)), color = color } or nil }, quarry, where
end

-- The letter of an objective of a quest of several on a hover's head seat.
local function LetterSeat(one)
	return { key = "shyquest-letter", set = function(seat)
		if not seat.disc then
			seat.disc = ns.CreateLetter(seat, 14)
			seat.disc:SetPoint("CENTER")
		end
		seat.disc:Set(one)
	end }
end

-- What an objective is got from, as every hover of it shows it (a mark's, a card row's, the lit ground's):
-- the stage (Shy.Hover's model block) and the rows under it, each creature on a line of its own with how
-- seldom it drops and its level at the right, and under it what brings it out; or, with nothing to fight,
-- where it is got. One place for all of them, so they never drift apart. Returns the model block, the
-- rows, `where` (ObjectiveStage's), the goal and the color; nil for an objective with no words.
--   color: the objective's own shade unless given.
--   most: how many it names (HUNT.most unless given). Fewer, on a hover it shares with other objectives,
--   are the quickest to have it from alone: no line counts the rest.
local function Hunted(id, index, color, most)
	local goal = id and index and L.Has(id) and L.Goals(id)[index]
	if not goal or not goal.text or goal.text == "" then return nil end
	local one = ns.Objective(id, index)
	color = color or (one and one.shade) or ns.ToneColor(ns.QuestKind(id, index))
	local model, quarry, where = ObjectiveStage(id, index, goal, color)
	most = most or HUNT.most
	local rows = {}
	for i = 1, math.min(most, #quarry) do
		local npc = D.Npc(quarry[i].npc)
		if npc then
			local odds, level = D.OneIn(quarry[i].chance, true), D.LevelText(npc)
			-- (A name too long for the line is shortened as a name is, never wrapped: row.name.)
			rows[#rows + 1] = { glyph = GoalGlyph(goal), tint = color, text = npc.name, name = true,
				right = odds and level and (odds .. " \194\183 " .. level) or odds or level, rightColor = C.dim }
			local words = Summoned(quarry[i].npc)
			if words then rows[#rows + 1] = { glyph = "note", tint = C.alert, color = C.alert, indent = 1, text = words } end
		end
	end
	if #quarry > most and most >= HUNT.most then rows[#rows + 1] = { quiet = true, text = ("and %d more"):format(#quarry - most) } end
	-- Nothing to fight for it (an object to use, an item found in one): where it is got.
	if #rows == 0 and where and where.source and where.source.name ~= "" then
		rows[1] = { glyph = "use", tint = color, text = where.source.name }
	end
	return model, rows, where, goal, color, #quarry
end
CardHover.Hunted = Hunted

-- The objective a stop is for, where it is got from something: its quest and index, or nil. A goal stop:
-- its first action's quest and its objective; a guide step: the task its position is for (stop.aimed), where
-- that line completes an objective, else the first open one it completes.
function CardHover.ObjectiveOf(stop)
	if not stop then return nil end
	if stop.kind == "goal" then
		local action = stop.objective and stop.actions and stop.actions[1]
		if action and action.id then return action.id, stop.objective end
		return nil
	end
	if stop.kind == "guide" and stop.view then
		-- An objective line names its quest and objective; a collect line its item, its count and its quest,
		-- whose objective is the one that counts that item.
		local function Of(line)
			if line.command == "complete" and line.id then
				return line.id, line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1
			elseif line.command == "collect" and line.id then
				local quest = tonumber((line.spec or ""):match("^%s*%d+%s*,%s*%d+%s*,%s*(%d+)"))
				for index, goal in ipairs(quest and L.Has(quest) and L.Goals(quest) or {}) do
					for _, token in ipairs(goal.tokens or {}) do
						if token.kind == "i" and token.id == line.id then return quest, index end
					end
				end
			end
		end
		local first
		for _, line in ipairs(stop.view.lines or {}) do
			if not line.done then
				local id, index = Of(line)
				if id then
					if stop.aimed and line.number == stop.aimed then return id, index end
					if not first then first = { id, index } end
				end
			end
		end
		if first then return first[1], first[2] end
	end
end

-- A creature alone, for a stage (a target chip's hover): the model block, with its kind's mark until it is in.
function CardHover.Creature(npc, color)
	color = color or C.hot
	return { creature = npc, display = D.Look("n", npc), color = color,
		art = { ns.MEDIA .. "MarksLarge", coords = ns.MarkPicture(ns.ToneSign("kill")), color = color } }
end

function CardHover.Objective(owner, stop, id, index, card)
	local model, rows, where, goal, color = Hunted(id, index)
	if not model then return false end
	local one = ns.Objective(id, index)
	local kind = ns.QuestKind(id, index)
	local entry = L.entries[id]
	local far = where and (where.here and "Here" or where.yards and (W.Yards(where.yards) .. (where.way and (" " .. where.way) or ""))) or nil
	local key = { { text = (ns.KIND[kind] or ns.KIND.go).word, color = color } }
	if entry then
		key[2] = { text = "  \194\183  ", color = C.dim }
		key[3] = { text = entry.title, color = C.dim }
	end
	local body = { { model = model } }
	if #rows > 0 then body[2] = { rows = rows } end
	local content = { card = true, about = "objective:" .. id .. ":" .. index, title = Counted(goal.text),
		seat = one and LetterSeat(one) or MarkSeat("goal", nil, nil, kind), light = color, kind = far,
		key = key, body = body }
	return Shy.Hover.Show(owner, content, { dock = card, key = "objective:" .. id .. ":" .. index }) ~= nil
end
CardHover.ObjectiveStage = ObjectiveStage

-- A spawn under the mouse on a map (Ground.SpawnAt's), as an objective's mark says it: on the head who or
-- what stands there, in its objective's shade and letter, how far at the right; on the key line its level
-- and rank (or its title) and the quest; turning on a stage; under it each objective it is for, how
-- seldom it drops that, and what brings it out where it stands nowhere until called. A thing for several
-- quests has a list for each, under the quest's name.
function CardHover.Spawn(spawn)
	local thing, first = spawn.thing, spawn.whats[1]
	if not (thing and first) then return nil end
	local one = first.quest and first.objective and ns.Objective(first.quest, first.objective)
	local light = spawn.shade or (one and one.shade) or ns.ToneColor(spawn.kind)
	local by, lists, item = {}, {}, nil
	for _, what in ipairs(spawn.whats) do
		local id = what.quest
		local name = id and ((L.entries[id] and L.entries[id].title) or D.Name("quests", id)) or ""
		local list = by[name]
		if not list then
			list = { title = name ~= "" and name or nil, rows = {} }
			by[name] = list
			lists[#lists + 1] = list
		end
		local goal = id and what.objective and L.Has(id) and L.Goals(id)[what.objective]
		local counted = goal and not goal.finished and goal.text and goal.text ~= ""
		if counted then
			local row = GoalRow(id, what.objective, goal)
			local own = ns.Objective(id, what.objective)
			if own then row.tint = own.shade end
			list.rows[#list.rows + 1] = row
			for _, token in ipairs(goal.tokens or {}) do
				if token.kind == "i" then item = item or token.id end
			end
		end
		local chance = what.how == "drops" and D.OneIn(what.chance)
		if chance then list.rows[#list.rows + 1] = { quiet = true, indent = counted and 1 or nil, text = (chance:gsub("^%l", string.upper)) } end
	end
	local words = spawn.of == "n" and Summoned(thing.id)
	if words then
		local rows = lists[#lists].rows
		rows[#rows + 1] = { glyph = "note", tint = C.alert, color = C.alert, text = words }
	end
	local key = {}
	local function Add(text, color)
		if not text or text == "" then return end
		if #key > 0 then key[#key + 1] = { text = DOT, color = C.dim } end
		key[#key + 1] = { text = text, color = color }
	end
	-- What is fought for it says its level, whoever's side it is on.
	local fought = spawn.of == "n" and (first.how == "kill" or first.how == "drops")
	Add(fought and D.LevelText(thing) or Kind(thing) or (ns.KIND[spawn.kind] or ns.KIND.go).word, light)
	-- One quest: its name is on the key line, and its list has no heading.
	if #lists == 1 then
		Add(lists[1].title, C.dim)
		lists[1].title = nil
	end
	local far
	if spawn.north and spawn.continent == W.continent and W.Known() then
		local yards = W.Between(W.north, W.west, spawn.north, spawn.west)
		far = yards and (yards < 10 and "Here" or W.Yards(yards)) or nil
	end
	local icon = item and C_Item.GetItemIconByID(item) or nil
	local creature = spawn.of == "n" and thing.id or nil
	local body = {}
	for _, list in ipairs(lists) do
		if #list.rows > 0 then body[#body + 1] = list end
	end
	-- Turning on its stage under the lists, at once.
	body[#body + 1] = { model = { creature = creature, display = creature and D.Look("n", creature) or nil,
		file = spawn.of == "o" and D.Look("o", thing.id) or nil, icon = icon, color = light,
		art = not icon and { ns.MEDIA .. "MarksLarge", coords = ns.MarkPicture(ns.ToneSign(spawn.kind)), color = light } or nil } }
	return { card = true, title = thing.name, light = light, kind = far, key = #key > 0 and key or nil, body = body,
		seat = one and LetterSeat(one) or MarkSeat("goal", nil, nil, spawn.kind) }, SLIM_WIDE
end

local shown                  -- the card row whose hover is up
local keeping                -- the kept hover frame (its .key is the stop's)

-- A hover opened from a card filtered by `words` (lower case): they are lit in the accent wherever they stand in it,
-- every time (its name, its rows, its quest text), and the quest text opens where they first are (Shy.Hover's story
-- block, `at`). Content in the card form (AsCard). Returns it.
local function Lit(content, words)
	local Light = ns.LightWords
	if not (words and content and Light) then return content end
	if content.title then content.title = (Light(content.title, words, true)) end
	for _, block in ipairs(content.body or {}) do
		for _, row in ipairs(block.rows or {}) do
			if row.text then row.text = (Light(row.text, words, true)) end
		end
		if block.story then
			local plain = UI.PlainText(block.story)
			local first = plain:lower():find(words, 1, true)
			if first then block.at = first / math.max(1, #plain) end
			block.story = (Light(block.story, words, true))
		end
	end
	return content
end

local function OnKeep(frame, kept)
	keeping = kept and frame or nil
	local content = kept and frame.content
	if not content then return end
	-- Pinned, it may be dragged anywhere: it gets the way to its stop, the window's own included.
	local whole = frame.about and CardHover.Content(frame.about, nil, true, nil, content.docked)
	if whole then
		whole.hints, whole.pins = content.hints, content.pins
		content = Lit(whole, frame.words)
	end
	-- Kept from a card row: the hint becomes what the next click does.
	if content.pins and content.hints then content.hints[1] = { "left", "Unpin" } end
	if whole or content.pins then Shy.Hover.Refill(frame, content) end
end

-- Mouse hints for a card row: a click pins the hover, the menu has the rest.
local function RowHints(stop)
	if stop.kind == "guide" then return { { "left", "Pin step" }, { "right", "Point the way, done, skip" } } end
	if stop.kind == "errand" then
		-- An errand with a click of its own keeps it (Card.lua).
		return { { "left", stop.click and (stop.hint or "Open") or "Pin" }, { "right", stop.menuHint or "Point the way" } }
	end
	if stop.kind == "fly" then return { { "left", "Pin" }, { "right", "Point the way" } } end
	if stop.kind == "way" then return { { "left", "Pin" }, { "right", "Route" } } end
	return { { "left", "Pin" }, { "right", stop.chosen and "Let the route choose" or "Head here first" } }
end

-- Show the hover for a card row. False when the stop has no form here (a zone); true with none shown
-- where there is nothing the row doesn't say.
-- (Its two halves on the clock: what it says gathered, and the hover put up. The mouse coming onto a row
-- is in no clock of its own, and one took 220 ms.)
function CardHover.Show(row, stop, card)
	if stop.sample then return false end
	local from = debugprofilestop()
	local content = CardHover.Content(stop, R.Lead and R.Lead() or R.stops[1], nil, nil, true, row)
	Shy.Clock("card: a row's hover, what it says gathered"):Lap(debugprofilestop() - from)
	-- (Nothing the row doesn't say: no hover at all, and none of the plain lines either.)
	if content == false then return true end
	if not content then return false end
	from = debugprofilestop()
	-- From a filtered card (its box at the top), the words it was filtered by are lit here too.
	local words = card and card.filter
	Lit(content, words)
	content.hints = RowHints(stop)
	content.pins = not (stop.kind == "errand" and stop.click)   -- a row click pins it (OnKeep)
	shown = row
	row.hoverCard = card
	local frame = Shy.Hover.Show(row, content, { dock = card, key = Key(stop), onKeep = OnKeep })
	if frame then frame.about, frame.words = stop, words end
	Shy.Clock("card: a row's hover, put up"):Lap(debugprofilestop() - from)
	return true
end

-- Toggle the pin on a card row's hover. False when the stop has no hover (a zone), so the card can
-- use the click for something else.
function CardHover.Pin(row, stop, card)
	if stop.sample then return false end
	local key = Key(stop)
	local up = Shy.Hover.Kept()
	if up and up.key == key then
		Shy.Hover.Close(up)
		-- The mouse is still on the row: show its ordinary hover again.
		CardHover.Show(row, stop, card)
		return true
	end
	if Shy.Hover.Owner() ~= row and not CardHover.Show(row, stop, card) then return false end
	return Shy.Hover.Keep(row)
end

function CardHover.Pinned(stop)
	local up = Shy.Hover.Kept()
	return up ~= nil and up.key == Key(stop)
end

-- A hover of something on the minimap (a pin, a spawn, the ground) stands beside the minimap, never over
-- the little it shows. opts: Shy.Hover.Show's, made over.
function CardHover.Minimap(opts)
	opts.side, opts.outside, opts.gap = nil, Minimap, 10
end

-- Beside a map or minimap pin: the slim form (Slim), the map being under the mouse already. Kept by a
-- click, it gets the whole of it. hints: the pin's mouse hints. mini: a minimap pin's, beside the minimap
-- (Minimap).
function CardHover.Beside(owner, stop, hints, side, mini)
	local content = CardHover.Content(stop, R.Lead and R.Lead() or R.stops[1], true, true)
	if not content then return false end
	content.hints = hints or content.hints
	-- An objective's own mark: what it is got from, turning on its stage under the rest at once.
	local action = stop.objective and stop.kind == "goal" and not stop.members and stop.actions and stop.actions[1]
	local goal = action and L.Has(action.id) and L.Goals(action.id)[stop.objective]
	if goal and content.body then
		local one = ns.Objective(action.id, stop.objective)
		local color = one and one.shade or ns.ToneColor(ns.QuestKind(action.id, stop.objective))
		content.body[#content.body + 1] = { model = (ObjectiveStage(action.id, stop.objective, goal, color)) }
		if one then content.seat, content.light = LetterSeat(one), color end
	end
	local opts = { side = side, key = Key(stop), onKeep = OnKeep, width = SLIM_WIDE }
	if mini then CardHover.Minimap(opts) end
	local frame = Shy.Hover.Show(owner, content, opts)
	if frame then frame.about = stop end
	return true
end

function CardHover.Hide(row)
	if shown == row then shown = nil end
	Shy.Hover.Hide(row)
end

-- The stop a kept hover (or the arrow, Arrow.lua) is about after a rebuild: the one with its Key; else, for
-- a quest's stop, one for the same quest (the same kind and objective first, then any: an objective done is
-- its hand-in), the nearest to where it was. A quest stop's Key holds its first quest and its spot, and both
-- move (a quest taken at a giver of several, another area of a kill nearer): matching the Key alone let it
-- go then. nil when nothing on the route is about it any more.
local function Follow(was, key)
	for _, stop in ipairs(R.stops) do
		if Key(stop) == key then return stop end
	end
	if not was or was.kind == "guide" or was.kind == "errand" then return nil end   -- (their Key never moves)
	local quests = {}
	for _, action in ipairs(was.actions or {}) do quests[action.id] = true end
	local best, most, least
	for _, stop in ipairs(R.stops) do
		for _, action in ipairs(stop.actions or {}) do
			if quests[action.id] then
				local alike = (stop.kind == was.kind and 2 or 0) + (stop.objective == was.objective and 1 or 0)
				local far = stop.map == was.map and stop.x and was.x and ((stop.x - was.x) ^ 2 + (stop.y - was.y) ^ 2) or math.huge
				if not best or alike > most or (alike == most and far < least) then best, most, least = stop, alike, far end
				break
			end
		end
	end
	return best
end
CardHover.Follow = Follow

-- After a rebuild the stop tables are new: refill the hover under the mouse, and the kept one with the
-- stop it follows (Follow). Only a click lets a kept one go: one about nothing on the route any more stays
-- as it was.
ns.OnRoute(function(rebuilt)
	if not rebuilt then return end
	if keeping then
		local frame = keeping
		local now = Follow(frame.about, frame.key)
		local content = now and CardHover.Content(now, R.Lead and R.Lead() or R.stops[1], true, nil, frame.content and frame.content.docked)
		if content then
			frame.about, frame.key = now, Key(now)
			-- Keep the hints of where it was opened (a pin's differ from a row's).
			if frame.content then content.hints, content.pins = frame.content.hints, frame.content.pins end
			Shy.Hover.Refill(frame, content)
		end
	end
	if not shown then return end
	if Shy.Hover.Owner() ~= shown then
		shown = nil
	elseif shown.stop and shown:IsShown() then
		if not CardHover.Show(shown, shown.stop, shown.hoverCard) then CardHover.Hide(shown) end
	else
		Shy.Hover.Close()
		shown = nil
	end
end, true)
