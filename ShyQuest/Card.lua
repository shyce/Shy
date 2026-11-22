-- The quest window: your guide and tracked quests as one route. ns.CreateCard builds it for both
-- the Shy.HUD box and the options preview.
--
-- A rail down the left is the route, in the order you walk it. The stop you head for leads, on a
-- dial. Later stops wear the numbers their pins have on the map (Pins.lua, ns.RoutePlaces). Under
-- each stop are the quests done there, with their counts. With a guide, the rail carries on through
-- its next places. After the rail come the errands that are not on the way (a trainer, a vendor, a
-- flight point), one line each under their signs. After them come the quests the guide has no step
-- for. Only tracked quests get a row (Tracker.lua keeps the watch list to where you are). The rest
-- of the log folds into one line per zone.
--
-- With a guide the header has a pager: back, "37 / 212", skip. The count is a switch
-- (ns.char.guideFull) that opens the whole guide: a progress bar and a scrolling step list from
-- GuideWindow.lua's ns.GuideList. This file lays the card out and asks it for heights.
-- With ShyXP the foot shows level progress (XP.lua) and the card stays up with no steps.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G, Tips = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide, ns.Tips
local B, UI = Shy.Brand, Shy.UI
local C = UI.colors

local WIDTH, PAD = 270, 10
local GUTTER, RAIL = 46, 23          -- where text starts, and the rail's middle
local STRIP = UI.HEAD.piece.line - 2 -- the card's own title strip (a console piece's, inside the rim); its line is under it
local DIAL, DIAL_ART = 36, 44        -- the lead's ring, and its art's size (DialLead, drawn for it)
local WAY = 18                       -- the arrowhead in it (ArrowLead, drawn for it)
local PIN, MARK = 24, 22             -- a numbered place, and a plain mark
local ASIDE = 22                     -- the mark beside a note and on the countdown's plate (an errand's sign, an escort's face)
local TAG, DIAL_TAG = 14, 13         -- what a place is for, over its pin: its size, and how far right and down of the dial's middle
local PIN_TAG_X, PIN_TAG_Y = 9, 5   -- ... and of a pin's: over the lower right of the pin's head, the pin's point showing under it
local PIN_SEAT = 14                  -- a pin's middle under its row's top: its head comes up to the top of the title's letters
local MARK_SEAT = 10                -- a mark's middle under a title alone: level with the title's middle, so it stays inside the row
local BARE_ROW = 24                  -- a mark alone on a line (an errand in the tray): the line's height, the mark its middle (the hover lights the line evenly round it)
local HERE = 32                      -- the emblem that fills the dial on the ground where the lead is done (its picture's 64 texel cell)
local LEAD_HEAD = 33                 -- the lead's title and caption; GuideButtons.lua's strip docks under them
local ROW_HEAD = 16                  -- a later stop's title
local LINE = 13                      -- a line with a count
local LETTER = 14                    -- an objective's letter disc (Letters.tga, drawn for it)
local UNIT, UNIT_UNDER = 27, 13      -- an objective's unit on the lead (two lines), and where its second line stands
local UNIT_AIR = 4                   -- over the first of them
local BAR, BAR_TALL = 34, 3          -- a count's bar: its width, and how thick it is
local RIGHT = { size = 11, worth = 9 }   -- what stands at a line's right: a count's size, and what a hand-in pays (quieter)
-- Row sizes: a notice or a stop with no lines (row); a zone's line, its name over what is in it (height), where its
-- second line stands (sub), and what an open zone keeps under its last quest (gap).
-- steps: how far the step count's plate (the whole guide's switch) reaches past its digits. switch: Zone | Guide | Dungeon. runLines: the lines of any stop in Dungeon mode, the whole of it, nothing cut to
-- "and more" (kept here, not a local of its own: the card's maker is at the game's 60 upvalues).
local MINE = { from = 0.20, to = 0.03 }   -- the wash on a stop you put on your route: its color's share at the rail, and at the right
local ZONE = { steps = 3, row = 22, height = 32, sub = 19, gap = 4, controls = 28, switch = 150, runLines = 24 }
local PLATE, PLATE_AIR = 34, 5      -- the countdown's plate, and the room kept above and below it
local PLATE_IN = 7                   -- the plate's words from its right edge
local CLOCK_ROOM = 34                -- what the plate keeps for its clock at the least
local SIGN_ROOM = 34                 -- where a note's words begin after its mark: under the countdown's name
local LINE_MID = 7                   -- a 12-point line's middle under its top
local MAX_ROWS = 6                   -- the "Steps listed" setting's maximum
local MAX_ZONES = 3                  -- zone suggestions, on top of those
local MAX_GUIDE = 4                  -- live guide steps, on top of those too
local MAX_AHEAD = 3                  -- the guide's next places
local MAX_TRACKED = 8                -- tracked quests beyond the steps asked for
local MAX_ERRANDS = 4                -- errands off the way, a line each
local MAX_LINES = 8                  -- lines of the lead
local ROW_LINES = 5                  -- lines of a later stop
local MAX_FOLDS = 4                  -- zones folded to a line
local MAX_NOTICES = 2                -- quests waiting for a click (ns.QuestPopups)
local PAGER = 15                     -- size of the back and skip buttons
local DOT = "|TInterface\\AddOns\\ShyQuest\\Media\\Dot:0:0:0:0:64:64:0:64:0:64:%d:%d:%d|t "
local ARROW = "|TInterface\\AddOns\\ShyQuest\\Media\\Arrow:0:0:0:0:40:40:0:40:0:40:%d:%d:%d|t "   -- leads the aimed task

-- The dot inline, in a theme color.
local function Dot(color)
	return DOT:format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end
local ARRIVED = 8                    -- yards: no arrow when this close

ns.cards = {}

-- The bullet in front of a guide line.
function ns.Bullet(line)
	if line.done then return Dot(C.good) end
	-- A task only the player can mark done.
	if line.manual then return Dot(C.alert) end
	if line.mark == "pickup" then return UI.Wrap(C.alert, "!") .. " " end
	if line.mark == "turnin" then return UI.Wrap(C.alert, "?") .. " " end
	if line.mark == "goal" then return Dot(ns.ToneColor(ns.LineTone(line))) end
	return ""
end

-- Sample steps for the options preview

local function Sample()
	local function Name(id, fallback)
		local quest = D.Quest(id)
		return quest and quest.name or fallback
	end
	local gryan = D.Npc(234)
	return {
		{ kind = "turnin", who = gryan and gryan.name or "Gryan Stoutmantle", yards = 84, sample = true, turn = 0.6,
			actions = {
				{ kind = "turnin", id = 12, title = Name(12, "The People's Militia"), level = 12 },
				{ kind = "pickup", id = 13, title = Name(13, "The People's Militia"), level = 14 },
			} },
		{ kind = "goal", yards = 310, sample = true, number = 2, lines = { "Gnoll Paw: 5/8" },
			actions = { { kind = "goal", id = 153, title = Name(153, "Red Leather Bandanas"), level = 12 } } },
		{ kind = "pickup", who = "Farmer Saldean", yards = 455, sample = true, number = 3,
			actions = { { kind = "pickup", id = 9, title = Name(9, "The Killing Fields"), level = 12 } } },
		{ kind = "goal", yards = 620, sample = true, number = 4, lines = { "Harvest Watcher slain: 3/20" },
			actions = { { kind = "goal", id = 9, title = Name(9, "The Killing Fields"), level = 12 } } },
		{ kind = "errand", title = "Train: 2 new spells", mark = "train", yards = 240, sample = true, lines = {}, actions = {} },
		{ kind = "zone", who = W.MapName(1433) or "Redridge Mountains", yards = 2140, sample = true, count = 9,
			lines = { "9 quests for you, levels 15-20" }, actions = {} },
	}
end

-- What a stop says

local function Describe(stop)
	if stop.sample then
		local lines = stop.lines
		if not lines then
			lines = {}
			for _, action in ipairs(stop.actions) do
				lines[#lines + 1] = (action.kind == "turnin" and "Turn in " or "Pick up ") .. action.title
			end
		end
		return stop.title or stop.who or stop.actions[1].title, lines
	end
	return R.Describe(stop)
end

local function OneLine(fs, width)
	fs:SetWidth(width)
	fs:SetWordWrap(false)
	fs:SetJustifyH("LEFT")
end

local function Count(stop)
	return stop.zone and #stop.zone.quests or stop.count
end

-- A quest's level in its difficulty color.
local function LevelText(level)
	if not level or level <= 0 then return "" end
	local color = GetQuestDifficultyColor(level)
	return ("|cff%02x%02x%02x%d|r"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
		math.floor(color.b * 255 + 0.5), level)
end

-- The card's filter (the box at its top). `words` is what was typed, in lower case.
--
-- What in a stop has the words, the likeliest to be seen first: its name, a quest's name, a line of its guide
-- step, an objective, then the quest log's own words for a quest (its objectives' summary, then its story).
-- { where = what it is called on the card ("quest text"), text = the words it was found in } or nil.
function ZONE.Find(stop, words)
	local function Has(text) return text and UI.PlainText(text):lower():find(words, 1, true) ~= nil end
	local title = Describe(stop)
	if Has(title) then return { where = "name", text = title } end
	for _, action in ipairs(stop.actions or {}) do
		if Has(action.title) then return { where = "quest", text = action.title } end
	end
	for _, line in ipairs(stop.view and stop.view.lines or {}) do
		if Has(line.text) then return { where = "step", text = UI.PlainText(line.text) } end
	end
	local ids = {}
	for _, action in ipairs(stop.actions or {}) do
		if action.id then ids[#ids + 1] = action.id end
	end
	for _, id in ipairs(ids) do
		for _, goal in ipairs(L.Has(id) and L.Goals(id) or {}) do
			if Has(goal.text) then return { where = "objective", text = goal.text } end
		end
	end
	for _, id in ipairs(ids) do
		local said = L.Text(id)
		if said and Has(said.goal) then return { where = "objectives", text = said.goal } end
		if said and Has(said.story) then return { where = "quest text", text = said.story } end
	end
	return nil
end

-- `text` with the first stretch of `words` in it set in the accent (`every`: each stretch); escape codes (colors,
-- pictures, links) are stepped over, never cut. Returns the text, and whether the words were in it.
function ZONE.Light(text, words, every)
	if not text or text == "" then return text, false end
	local letters, at, i, n = {}, {}, 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if c == "|" then
			local kind = text:sub(i + 1, i + 1)
			local close = (kind == "T" and "|t") or (kind == "A" and "|a") or (kind == "H" and "|h") or nil
			if kind == "c" then
				i = i + 10
			elseif close then
				local stop = text:find(close, i + 2, true)
				i = stop and stop + 2 or n + 1
			else
				i = i + 2           -- |r, |h, ||
			end
		else
			letters[#letters + 1] = c
			at[#letters] = i
			i = i + 1
		end
	end
	local plain = table.concat(letters):lower()
	local out, last, found, from, to = {}, 1, false, plain:find(words, 1, true)
	while from do
		found = true
		local a, b = at[from], at[to]
		out[#out + 1] = text:sub(last, a - 1)
		out[#out + 1] = Shy.Theme.Wrap(C.hot, text:sub(a, b))
		last = b + 1
		if not every then break end
		from, to = plain:find(words, to + 1, true)
	end
	if not found then return text, false end
	out[#out + 1] = text:sub(last)
	return table.concat(out), true
end
-- (For the hovers of a filtered card's rows: CardHover.lua.)
ns.LightWords = ZONE.Light

-- A few words round where `words` stand in `text`, on one line: "...waits at the tram for his brother..." with
-- the words lit (ZONE.Light).
ZONE.before, ZONE.after = 14, 22
function ZONE.Snip(text, words)
	local flat = UI.PlainText(text):gsub("%s+", " ")
	local from, to = flat:lower():find(words, 1, true)
	if not from then return nil end
	local a, b = math.max(1, from - ZONE.before), math.min(#flat, to + ZONE.after)
	-- (On word breaks, where there is one near.)
	if a > 1 then a = (flat:find(" ", a, true) or a) + 1 end
	if a > from then a = from end
	if b < #flat then b = (flat:sub(1, b):match(".*() ") or b + 1) - 1 end
	if b < to then b = to end
	local snip = flat:sub(a, b)
	snip = (a > 1 and "..." or "") .. snip .. (b < #flat and "..." or "")
	return (ZONE.Light(snip, words))
end

-- A stop's title and lines as the filter shows them: its words lit where they are already on the card, or, where
-- what matched isn't (the quest's own text, a line past those shown), one line more over its lines: the glass, the
-- few words round the match, and where they were found at its right. `most`: lines the row shows.
ZONE.glass = "|TInterface\\Common\\UI-Searchbox-Icon:12:12:0:-1|t "
function ZONE.Shown(self, stop, title, lines, most)
	local words = self.filter
	if not words then return title, lines end
	local lit, seen = ZONE.Light(title, words)
	local out = {}
	for i, entry in ipairs(lines) do
		if entry.text and i <= (most or #lines) then
			local text, here = ZONE.Light(entry.text, words)
			if here then
				local copy = {}
				for key, value in pairs(entry) do copy[key] = value end
				copy.text = text
				entry = copy
				seen = true
			end
		end
		out[i] = entry
	end
	local hit = not seen and self.hits and self.hits[stop]
	local snip = hit and ZONE.Snip(hit.text, words)
	if snip then
		table.insert(out, 1, { text = ZONE.glass .. snip, color = C.dim, right = hit.where, rightColor = C.hot, found = true })
	end
	return lit, out
end

-- A zone's second line: how many quests, and at what levels.
function ZONE.Sub(zone)
	local text = zone.quests .. (zone.quests == 1 and " quest" or " quests")
	if zone.low then
		text = text .. "  \194\183  " .. (zone.low == zone.high and "level " .. LevelText(zone.low)
			or "levels " .. LevelText(zone.low) .. "-" .. LevelText(zone.high))
	end
	return text
end

-- A guide step's line that counts something, as the log has it now: a quest's objective (and its number), or
-- what is had and needed of an item to get. Nothing for a failed quest's line, or one that counts nothing.
function ZONE.Tally(line)
	if not line or (not line.done and line.failed) then return nil end
	if line.command == "complete" and line.id then
		local index = line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1
		local goal = ((L.entries[line.id] or {}).goals or {})[index]
		if goal and goal.need > 0 then return goal, nil, nil, index end
	elseif line.command == "collect" then
		local have, need = UI.PlainText(line.text):match(":%s*(%d+)/(%d+)%s*$")
		have, need = tonumber(have), tonumber(need)
		if need and need > 0 then return nil, have, need end
	end
	return nil
end

-- What stands under a count on the lead for the guide's note folded into it (G.Folds, "Kill Blackrock Grunt /
-- Blackrock Outrunner for Battleworn Axe"): who it is got from, in words ("Kill Blackrock Grunt or Outrunner"),
-- unless each of them has a chip standing there (`room`: GuideButtons.lua's, for this task) or the stop's own
-- name says it (`title`, in small letters); then what the note said aside ("Trade good: can be bought").
function ZONE.Under(fold, title, room)
	if not fold then return nil end
	local who
	if not fold.same and fold.names:lower() ~= title then
		local names, seen, chips = {}, {}, room ~= nil
		for name in (fold.names .. " / "):gmatch("(.-) / ") do
			if name ~= "" and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
				if not (room and room.names[name:lower()]) then chips = false end
			end
		end
		if not chips and #names > 0 then who = fold.verb .. " " .. R.Either(names) end
	end
	local aside = fold.aside
	if who then return aside and (who .. " (" .. aside .. ")") or who end
	return aside and (aside:gsub("^%l", string.upper)) or nil
end

-- The lines a row has room for (`most`): all of them, or the first of them and one line for the rest. That line
-- names the counts it leaves out ("Also Oslow's Toolbox and Token of Thievery"; past two of them, or with
-- other lines left out too, "Also Oslow's Toolbox, Token of Thievery and 2 more"), and says every line of them
-- on its hover (the lead's). A quest's name is never left as the last line, over nothing.
function ZONE.Cut(lines, most)
	if #lines <= most then return lines end
	local keep = most - 1
	while keep > 0 and lines[keep].cap do keep = keep - 1 end
	local out, rows, names = {}, {}, {}
	for i = 1, keep do out[i] = lines[i] end
	for i = keep + 1, #lines do
		local entry = lines[i]
		if not entry.cap then
			local text = strtrim(UI.PlainText(entry.text or ""))
			if entry.need then names[#names + 1] = text end
			rows[#rows + 1] = { text = text, right = entry.need and (entry.have .. "/" .. entry.need) or nil }
		end
	end
	if #rows == 0 then return out end
	local named = math.min(#names, #rows > 3 and 2 or 3)
	local rest = #rows - named
	local text
	if named == 0 then
		text = ("and %d more"):format(rest)
	elseif rest > 0 then
		text = ("Also %s and %d more"):format(table.concat(names, ", ", 1, named), rest)
	elseif named > 1 then
		text = "Also " .. table.concat(names, ", ", 1, named - 1) .. " and " .. names[named]
	else
		text = "Also " .. names[1]
	end
	-- (spill: on the lead it takes a second line before it is cut short, though it has a hover.)
	out[#out + 1] = { text = text, color = C.dim, tip = { "Also in this step", nil, rows }, spill = true }
	return out
end

-- An objective's words without its "3/8", which the line shows at its right.
local function Counted(text)
	text = (text or ""):gsub("^%s*%d+/%d+%s+", ""):gsub("%s*:%s*%d+/%d+%s*$", "")
	return text
end

-- A quest's name over its counts.
local function Cap(title, level)
	return { cap = true, text = title:upper() .. "  " .. LevelText(level) }
end

-- What an objective is got from, by the data, where the route has no camp for it (a finished one): the
-- creature for a kill, the first that drops or holds its item, the object for one to use.
local function SourceOf(goal)
	for _, token in ipairs(goal.tokens or {}) do
		local thing
		if token.kind == "c" or token.kind == "o" then
			thing = D.Thing(token.kind, token.id)
		elseif token.kind == "k" then
			thing = token.ids and token.ids[1] and D.Npc(token.ids[1])
		elseif token.kind == "i" then
			local item = D.Item(token.id)
			local source = item and item.sources[1]
			thing = source and D.Thing(source.kind, source.id)
		end
		if thing and thing.name and thing.name ~= "" then return thing.name end
	end
end

-- Whether the lead stands on an objective's ground: the one it leads with, or one of those it stands on too.
local function OnIt(stop, id, index)
	if not (stop and stop.among and stop.actions and stop.actions[1] and stop.actions[1].id == id) then return false end
	if stop.objective == index then return true end
	for _, each in ipairs(stop.also or {}) do
		if each.objective == index then return true end
	end
	return false
end

-- The objectives of a quest of several (ns.Objectives: each has a letter and a shade), each one unit. On
-- the lead (`whole`): the letter, the thing and its count, and under it, quiet, what it is got from and
-- where ("Here", or how far and which way to its best camp); those here first, then the nearest; finished
-- ones sink and go quiet. On a later row, a line each with the letter before it, in the quest's order.
local function Objectives(out, id, all, whole, stop)
	local where = whole and R.Objectives and R.Objectives(id) or {}
	local list = {}
	for index, goal in ipairs((L.entries[id] or {}).goals or {}) do
		local one = all[index]
		if one and goal.text and goal.text ~= "" then
			local counted = goal.need > 0
			local at = where[index] or {}
			-- (Here is where what it is named from is: R.Objectives. Only where that isn't known, the lead's grounds.)
			local here = not goal.finished and (at.here or (at.source == nil and OnIt(stop, id, index)))
			local entry = { text = Counted(goal.text), have = counted and goal.have or nil, need = counted and goal.need or nil,
				done = goal.finished, color = goal.finished and C.dim or C.text, letter = one, unit = whole or nil,
				objective = { id = id, index = index } }
			if whole then
				local source = at.source and at.source.name ~= "" and at.source.name or SourceOf(L.Goals(id)[index] or goal)
				entry.sub = source
				if here then
					entry.where, entry.whereColor = "Here", { one.shade[1] + (1 - one.shade[1]) * 0.35,
						one.shade[2] + (1 - one.shade[2]) * 0.35, one.shade[3] + (1 - one.shade[3]) * 0.35 }
				elseif not goal.finished and at.yards then
					entry.where = W.Yards(at.yards) .. (at.way and (" " .. at.way) or "")
				end
			end
			list[#list + 1] = { entry = entry, rank = goal.finished and 3 or here and 1 or 2, yards = here and 0 or at.yards or math.huge, index = index }
		end
	end
	if whole then
		table.sort(list, function(a, b)
			if a.rank ~= b.rank then return a.rank < b.rank end
			if a.yards ~= b.yards then return a.yards < b.yards end
			return a.index < b.index
		end)
	else
		table.sort(list, function(a, b)
			if (a.rank == 3) ~= (b.rank == 3) then return b.rank == 3 end
			return a.index < b.index
		end)
	end
	for _, each in ipairs(list) do out[#out + 1] = each.entry end
	if whole and list[1] and #out == #list then list[1].entry.first = true end
end

-- The objectives of a quest in the log as lines, done ones ticked.
local function Goals(out, id, whole, stop)
	local all = ns.Objectives and ns.Objectives(id)
	if all then return Objectives(out, id, all, whole, stop) end
	for index, goal in ipairs((L.entries[id] or {}).goals or {}) do
		if goal.text and goal.text ~= "" then
			local counted = goal.need > 0
			out[#out + 1] = { text = Counted(goal.text), have = counted and goal.have or nil, need = counted and goal.need or nil,
				done = goal.finished, color = goal.finished and C.dim or C.text, objective = { id = id, index = index } }
		end
	end
end

-- The quests the game has tracked, as a set.
local function Watching()
	local set = {}
	for index = 1, C_QuestLog.GetNumQuestWatches() do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
		if id then set[id] = true end
	end
	return set
end

-- What the card shows that the route's stops don't hold, as one text: the quests tracked (the game's and
-- by hand, ns.char.watch) and the quests waiting for a click. A route built the same again still has its
-- rows written anew when this changed: a tracked quest keeps a row, an offer is a line under the lead.
local function TrackedText()
	local parts = {}
	for index = 1, C_QuestLog.GetNumQuestWatches() do
		parts[#parts + 1] = C_QuestLog.GetQuestIDForQuestWatchIndex(index) or 0
	end
	parts[#parts + 1] = "|"
	for index = 1, GetNumAutoQuestPopUps() do
		local id, kind = GetAutoQuestPopUp(index)
		parts[#parts + 1] = tostring(id) .. tostring(kind)
	end
	parts[#parts + 1] = "|"
	local says = ns.char and ns.char.watch
	if says then
		local mine = {}
		for id, on in pairs(says) do mine[#mine + 1] = tostring(id) .. (on and "+" or "-") end
		table.sort(mine)
		for _, each in ipairs(mine) do parts[#parts + 1] = each end
	end
	return table.concat(parts, ",")
end

-- A stop for quests in the log, and whether one of them is tracked.
local function Logged(stop, watching)
	if stop.kind ~= "goal" and stop.kind ~= "turnin" then return false, false end
	local held, tracked = false, false
	for _, action in ipairs(stop.actions) do
		if action.kind ~= "pickup" and L.Has(action.id) then
			held = true
			if watching[action.id] then tracked = true end
		end
	end
	return held, tracked
end

-- A stop for a quest the player tracks by hand (Tracker.lua, ns.char.watch).
local function Pinned(stop)
	local says = ns.char and ns.char.watch
	for _, action in ipairs(says and stop.actions or {}) do
		if says[action.id] == true then return true end
	end
	return false
end

-- A micro map (a cave) counts as its parent zone.
local function Zone(map)
	local info = C_Map.GetMapInfo(map)
	for _ = 1, 4 do
		if not info or info.mapType ~= Enum.UIMapType.Micro or (info.parentMapID or 0) == 0 then break end
		map = info.parentMapID
		info = C_Map.GetMapInfo(map)
	end
	return map
end

-- Whether every quest of a stop is one zone mode leaves out (gray, not done: L.Ignored).
local function Grayed(stop)
	local any = false
	for _, action in ipairs(stop.actions) do
		if action.kind ~= "pickup" then
			if not L.Ignored(action.id) then return false end
			any = true
		end
	end
	return any
end

-- Where an untracked stop folds to: its zone's key and name, or the log's heading for it.
local function Fold(stop)
	if stop.map then
		local zone = Zone(stop.map)
		return zone, W.MapName(zone) or "Elsewhere"
	end
	local entry = stop.actions[1] and L.entries[stop.actions[1].id]
	local name = entry and entry.header or "Elsewhere"
	return name, name
end

-- The lines under a stop's title. An entry: { text, color, right, rightColor, rightSize, cap, have, need, done,
-- url, task, asked, failed }. `task` is the line's number when a click can aim the route at it.
-- `whole`: the lead, which also says what only matters once you are on your way to it.
-- `here`: the lead's caption already says that this is the ground it is done on.
local function Lines(stop, whole, here, rooms)
	local out, handIns = {}, {}
	local broken = false     -- a line is about a failed quest
	if stop.view then
		local capped
		-- A note restating the count under it ("Kill X for Y" over "Y: 0/1") is not a line of its own: the count
		-- says Y, and X is said once, under the count on the lead (ZONE.Under: in words, or by the chips that
		-- stand there, `rooms`) and on the row's hover. A count that isn't shown as one keeps its note.
		local folds, skip = G.Folds(stop.view.lines)
		for index, note in ipairs(stop.view.lines) do
			if skip[note] then
				local goal, _, need = ZONE.Tally(stop.view.lines[index + 1])
				if not (goal or need) then skip[note] = nil end
			end
		end
		-- (`said`: a further step of a place, written under its own name, Lines below.)
		local title = (stop.said or Describe(stop)):lower()
		local function Under(line)
			if not whole then return nil end
			return ZONE.Under(folds[line], title, rooms and rooms[G.TaskKey(stop.view, line.number)])
		end
		for _, line in ipairs(stop.view.lines) do
			-- (What a hand-in is worth stands at the line's right, in the column the counts and the distances
			-- keep: after the words it ran off the row with them.)
			local more, worth = "", nil
			if not line.done and line.command == "turnin" and line.id then
				worth = ns.XP.WorthRight(line.id)
				handIns[#handIns + 1] = line.id
			elseif not line.done and line.command == "xp" and line.can then
				more = ns.XP.ToGo(line.spec)
			end
			local task = line.at and line.can and not line.done and line.number or nil
			local asked = task and stop.aimed == task and ARROW:format(math.floor(C.hot[1] * 255), math.floor(C.hot[2] * 255), math.floor(C.hot[3] * 255)) or ""
			local failed = not line.done and line.failed or nil
			if failed then broken = true end
			-- A task that counts something: the quest's name once, then the count with its bar. An item to get
			-- counts as an objective does. (`number`: the task, for the chips that stand under it on the lead.)
			local goal, have, need, index = ZONE.Tally(line)
			if skip[line] then
				-- (Said by the count under it.)
			elseif goal then
				if capped ~= line.id then
					capped = line.id
					out[#out + 1] = Cap(L.entries[line.id].title, L.entries[line.id].level)
				end
				local done = line.done or goal.finished
				out[#out + 1] = { text = asked .. Counted(line.text), have = goal.have, need = goal.need, done = done,
					color = done and C.dim or C.text, task = task, asked = task ~= nil and stop.aimed == task,
					letter = ns.Objective and ns.Objective(line.id, index) or nil, objective = { id = line.id, index = index },
					number = line.number, sub = not done and Under(line) or nil }
			elseif need and (whole or not line.done) then
				out[#out + 1] = { text = asked .. Counted(line.text), have = math.min(have, need), need = need, done = line.done,
					color = line.done and C.dim or C.text, task = task, asked = task ~= nil and stop.aimed == task,
					number = line.number, sub = not line.done and Under(line) or nil }
			elseif whole or not line.done then
				-- A note for the spot itself (its `near` yards): said only that near the step's place.
				local near = line.command == "" and tonumber(line.spec) or nil
				if not (near and not whole and stop.yards and stop.yards > near) then
					out[#out + 1] = { text = asked .. ns.Bullet(line) .. line.text .. more,
						color = (line.done or line.soft) and C.dim or line.url and C.hot or C.text,
						right = worth, rightColor = worth and C.alert or nil, rightSize = worth and RIGHT.worth or nil,
						url = line.url, task = task, asked = task ~= nil and stop.aimed == task, failed = failed }
				end
			end
		end
		-- A place with several steps (Pins.lua): in Dungeon mode every one, each under its own name; elsewhere the
		-- first one's lines alone (the rest come up as each is done there: a line counting them only took a row).
		if stop.views and #stop.views > 1 and R.Running() then
			for v = 2, #stop.views do
				local view = stop.views[v]
				out[#out + 1] = { cap = true, text = (view.who or ("Step " .. (view.number or v))):upper() }
				for _, entry in ipairs(Lines({ kind = stop.kind, view = view, actions = view.actions or {}, said = view.who or "" }, false)) do
					-- (Its tasks are another step's: no chip of the leading step stands under them.)
					entry.number = nil
					out[#out + 1] = entry
				end
			end
		end
		if not whole then return out end
		if broken then out[#out + 1] = { text = "Click the failed quest to abandon it", color = C.alert } end
		if stop.manual then out[#out + 1] = { text = "Click when done", color = C.dim } end
		if stop.here then out[#out + 1] = { text = "Do it while you're here", color = C.dim } end
		-- Notes from Route.lua's GuideStops. Sent for an item first: what, and where it is had.
		local needs, from = R.Needs(stop)
		if needs then
			out[#out + 1] = { text = needs, color = C.alert }
			if from then out[#out + 1] = { text = from, color = C.dim } end
		end
		if stop.among then
			if not here then out[#out + 1] = { text = R.Found(stop), color = C.good } end
		end
		if stop.high then
			out[#out + 1] = { text = ("Level %d quest: %d above you"):format(stop.high, stop.high - L.Level()), color = C.alert }
		end
		-- An earlier step: a catch-up on the way (Guide.lua, Catchup), or one a later step can't do without
		-- (First): the row says which, and why.
		local why = ns.CATCH_WHY[stop.catch]
		if broken then
			-- already said above
		elseif why then
			out[#out + 1] = { text = why, color = C.alert }
		elseif stop.first then
			local name = stop.needed and D.Name("quests", stop.needed)
			out[#out + 1] = { text = name and ("A later step needs %s."):format(name) or "The next step needs this one.", color = C.alert }
		end
	else
		local title, lines, where = Describe(stop)
		-- A quest of several objectives says what each is got from on its own row: no loose line for one of them.
		local several = #stop.actions == 1 and stop.kind == "goal" and not stop.sample and ns.Objectives ~= nil
			and ns.Objectives(stop.actions[1].id) ~= nil
		-- (An errand that lays its lead out itself: stop.rows() gives the entries, in place of its lines.)
		local own = whole and not stop.sample and stop.rows and stop.rows() or nil
		for _, entry in ipairs(own or {}) do out[#out + 1] = entry end
		for i, text in ipairs(own and {} or lines) do
			local action = stop.actions[i]
			local have, need = text:match(":%s*(%d+)/(%d+)%s*$")
			if several and i > 1 and not action and not text:find("^Needs ") then
				-- (Said on the objective's row.)
			elseif action and action.kind == "goal" and not stop.sample and L.entries[action.id] then
				-- A quest in the log: its name unless the stop already wears it, then every count.
				if #stop.actions > 1 or title ~= action.title then out[#out + 1] = Cap(action.title, action.level) end
				Goals(out, action.id, whole, stop)
			elseif stop.sample and need then
				out[#out + 1] = { text = Counted(text), have = tonumber(have), need = tonumber(need), color = C.text }
			else
				local worth
				if action and action.kind == "turnin" and not stop.sample then
					worth = ns.XP.WorthRight(action.id)
					handIns[#handIns + 1] = action.id
				end
				local failed = action and action.failed and not stop.sample and action.id or nil
				if failed then broken = true end
				-- A zone's and an errand's lines say more than a later stop has room for.
				if whole or action or i == 1 then
					out[#out + 1] = { text = text, color = (whole or action) and C.text or C.dim, failed = failed,
						right = worth, rightColor = worth and C.alert or nil, rightSize = worth and RIGHT.worth or nil }
				end
			end
		end
		if broken and whole then out[#out + 1] = { text = "Click the failed quest to abandon it", color = C.alert } end
		-- A stop of your route taken in passing says what it is on the way to, or right by, in your color.
		if stop.along then out[#out + 1] = { text = stop.along, color = C.hot } end
		if where then out[#out + 1] = { text = where, color = C.dim } end
		if whole and stop.among and not here then out[#out + 1] = { text = R.Found(stop), color = C.good } end
	end
	if not whole then return out end
	local level = ns.XP.LevelsTo(handIns)
	if level then out[#out + 1] = { text = "Dings " .. level, color = C.alert } end
	-- A quest to accept with a full quest log.
	if not stop.sample and L.Full() then
		local taking = false
		for _, action in ipairs(stop.actions) do
			if action.kind == "pickup" and not action.failed then taking = true end
		end
		for _, line in ipairs(stop.view and stop.view.lines or {}) do
			if line.command == "accept" and line.can and not line.done and not line.failed then taking = true end
		end
		if taking then out[#out + 1] = { text = ns.RoomText(), color = C.alert } end
	end
	-- Lines registered by later files: ns.cardNotes[i](stop) returns text, color, and the mark to lead
	-- it (an errand's sign, or an objective's kind); or a line whole, { text, color, sign, right,
	-- rightColor, sub, tip }; or nil (Bags.lua). A line with a tip ({ title, text }) keeps to one line
	-- and says the rest on its hover. The countdown's plate stands
	-- between the stop's own lines and these (Fill).
	for _, note in ipairs(not stop.sample and ns.cardNotes or {}) do
		local text, color, sign = note(stop)
		local entry = type(text) == "table" and text or text and { text = text, color = color, sign = sign }
		if entry then
			entry.color, entry.note = entry.color or C.alert, true
			out[#out + 1] = entry
		end
	end
	return out
end

-- The level to show beside a stop's title: when the title is its one quest's name.
local function TitleLevel(stop, title)
	local only = #stop.actions == 1 and stop.actions[1]
	if only and only.title == title and not stop.who then return LevelText(only.level) end
	return ""
end

-- Rows

-- A row's i-th line, made when first needed: its words, what stands at its right, a bar and a tick.
local function Line(row, i)
	local line = row.lines[i]
	if line then return line end
	line = UI.Text(row, "", 12, false, C.text)
	line:SetJustifyH("LEFT")
	line:SetSpacing(1)
	line.cap = UI.Text(row, "", 10, false, C.dim)
	line.cap:SetWordWrap(false)
	line.right = UI.Text(row, "", RIGHT.size, false, C.text)
	line.right:SetJustifyH("RIGHT")
	line.rightSize = RIGHT.size
	-- (In whole screen pixels, on the pixel grid: three units are seldom whole pixels, and a bar wherever
	-- its line fell came out a pixel thinner than the next, or not at all.)
	line.track = row:CreateTexture(nil, "ARTWORK")
	UI.BoxFit(line.track, BAR, BAR_TALL)
	UI.Paint(line.track, C.rowEdge, 1)
	line.fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
	UI.BoxFit(line.fill, 1, BAR_TALL)
	UI.Paint(line.fill, Shy.Theme.Accent)
	line.check = row:CreateTexture(nil, "ARTWORK")
	line.check:SetSize(10, 10)
	line.check:SetTexture(ns.MEDIA .. "Check")
	UI.Tint(line.check, C.good)
	-- A note's second line: what its first is for, small, wrapping whole under it.
	line.sub = UI.Text(row, "", 11, false, C.dim)
	line.sub:SetJustifyH("LEFT")
	line.sub:SetWordWrap(true)
	row.lines[i] = line
	return line
end

local function Blank(line)
	-- (false: blank already.)
	if line.said == false then return end
	line.said = false
	line:Hide()
	line.cap:Hide()
	line.right:Hide()
	line.track:Hide()
	line.fill:Hide()
	line.check:Hide()
	if line.sign then line.sign:Hide() end
	if line.tile then line.tile:Hide() end
	if line.letter then line.letter:Hide() end
	if line.under then
		line.under:Hide()
		line.where:Hide()
	end
	line.sub:Hide()
end

-- What stands at a line's right, in its size: a count's, or the smaller one a line asks for. Returns how far
-- under a count's top it hangs, so the two stand on one baseline.
local function RightSize(line, size)
	size = size or RIGHT.size
	if line.rightSize ~= size then
		line.rightSize = size
		line.right:SetFont((GameFontHighlight:GetFont()), size, "")
	end
	return RIGHT.size - size
end

-- An objective of a quest of several, on the lead: one unit of two lines (Objectives). Its letter disc in
-- the rail's column, the thing and its count; under it, quiet, what it is got from and where that is.
local function WriteUnit(row, line, entry, y, width)
	-- (A little air between the caption and the first of them.)
	local air = entry.first and UNIT_AIR or 0
	y = y + air
	line.letter = line.letter or ns.CreateLetter(row, LETTER)
	line.letter:Set(entry.letter, entry.done)
	line.letter:ClearAllPoints()
	line.letter:SetPoint("CENTER", row, "TOPLEFT", RAIL, -y - LINE_MID)
	local taken = 0
	if entry.need then
		RightSize(line)
		line.right:SetText(("%s%s"):format(UI.Wrap(entry.done and C.good or C.text, entry.have), UI.Wrap(C.dim, "/" .. entry.need)))
		line.right:ClearAllPoints()
		line.right:SetPoint("TOPRIGHT", -PAD, -y - 1)
		line.right:Show()
		taken = line.right:GetStringWidth() + 6
	end
	line:SetWidth(width - GUTTER - PAD - taken)
	line:SetWordWrap(false)
	line:SetMaxLines(1)
	line:SetText(entry.text)
	UI.Ink(line, entry.color or C.text)
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", GUTTER, -y)
	line:Show()
	if not line.under then
		line.under = UI.Text(row, "", 10, false, C.dim)
		line.under:SetJustifyH("LEFT")
		line.under:SetWordWrap(false)
		line.where = UI.Text(row, "", 10, false, C.dim)
		line.where:SetJustifyH("RIGHT")
		line.where:SetWordWrap(false)
	end
	line.where:SetText(entry.where or "")
	UI.Ink(line.where, entry.whereColor or C.dim)
	line.where:ClearAllPoints()
	line.where:SetPoint("TOPRIGHT", -PAD, -y - UNIT_UNDER)
	line.where:SetShown(entry.where ~= nil)
	local far = entry.where and line.where:GetStringWidth() + 8 or 0
	line.under:SetText(entry.sub or "")
	UI.Ink(line.under, C.dim, entry.done and 0.6 or 1)
	line.under:SetWidth(width - GUTTER - PAD - far)
	line.under:ClearAllPoints()
	line.under:SetPoint("TOPLEFT", GUTTER, -y - UNIT_UNDER)
	line.under:SetShown(entry.sub ~= nil)
	return (entry.sub and UNIT or LINE + 3) + air
end

-- What a line is written with, as one string: a line given the same again is left as it stands. (A change
-- of font or theme makes every line and node say something new: words are measured, marks painted.)
local written = { epoch = 0 }
local function Print(entry, i, y, width, wrap)
	local letter, color, where = entry.letter, entry.whereColor, entry.icon
	return table.concat({ written.epoch, i > 1 and 1 or 0, y, width, wrap and 1 or 0, tostring(entry.text), tostring(entry.color),
		tostring(entry.have), tostring(entry.need), entry.done and 1 or 0, entry.cap and 1 or 0, entry.unit and 1 or 0,
		letter and (letter.letter .. tostring(letter.shade)) or "", tostring(entry.sign), tostring(where), tostring(entry.right),
		tostring(entry.rightColor), tostring(entry.rightSize), tostring(entry.sub), entry.note and 1 or 0, entry.tip and 1 or 0, tostring(entry.where),
		color and ("%.3f,%.3f,%.3f"):format(color[1], color[2], color[3]) or "", entry.first and 1 or 0 }, "\31")
end
function written.Over() written.epoch = written.epoch + 1 end
Shy:On("SHY_FONT", written.Over)
Shy:On("SHY_THEME", written.Over)

-- Writes `entry` as the row's i-th line, `y` under the row's top, in a row `width` wide. Returns
-- the height it takes. A line written with the same as last time is left as it stands.
local Writing
local function Write(row, i, entry, y, width, wrap)
	local line = Line(row, i)
	local said = Print(entry, i, y, width, wrap)
	if line.said == said then return line.tall end
	Blank(line)
	local tall = Writing(row, line, i, entry, y, width, wrap)
	line.said, line.tall = said, tall
	return tall
end
function Writing(row, line, i, entry, y, width, wrap)
	if entry.cap then
		-- A little air above a quest's name, unless it opens the row's lines.
		local air = i > 1 and 3 or 0
		line.cap:SetText(entry.text)
		line.cap:SetWidth(width - GUTTER - PAD)
		line.cap:ClearAllPoints()
		line.cap:SetPoint("TOPLEFT", GUTTER, -y - air - 1)
		line.cap:Show()
		-- Tests and the links read the line itself.
		line:SetText(entry.text)
		return 13 + air
	end
	if entry.unit then return WriteUnit(row, line, entry, y, width) end
	local x = GUTTER
	if entry.letter then
		-- An objective of a quest of several, on a line of its own: its letter before it (done, grey).
		line.letter = line.letter or ns.CreateLetter(row, LETTER)
		line.letter:Set(entry.letter, entry.done)
		line.letter:ClearAllPoints()
		line.letter:SetPoint("CENTER", row, "TOPLEFT", GUTTER + LETTER / 2, -y - LINE_MID)
		x = x + LETTER + 4
	elseif entry.need and entry.done then
		line.check:ClearAllPoints()
		line.check:SetPoint("TOPLEFT", GUTTER, -y - 2)
		line.check:Show()
		x = x + 13
	elseif entry.sign then
		-- A note's mark, as the countdown's plate wears one and in its column: an errand's sign, or the
		-- kind of an objective (an escort's face). Its words hang beside it; it stands at their middle.
		line.sign = line.sign or ns.CreateMark(row, ASIDE)
		if ns.SignColor(entry.sign) then line.sign:Set(entry.sign) else line.sign:Set("goal", false, nil, entry.sign) end
		line.sign:ClearAllPoints()
		line.sign:SetPoint("CENTER", row, "TOPLEFT", GUTTER + PLATE / 2, -y - LINE_MID)
		line.sign:Show()
		x = x + SIGN_ROOM
	elseif entry.icon then
		-- A spell's or an item's picture, in the signs' column: a slot.
		if not line.tile then
			line.tile = CreateFrame("Frame", nil, row)
			line.tile:SetSize(ASIDE - 2, ASIDE - 2)
			line.tile.icon = line.tile:CreateTexture(nil, "ARTWORK")
			line.tile.icon:SetAllPoints()
			line.tile.slot = Shy.Slot.New(line.tile, { icon = line.tile.icon, size = ASIDE - 2, hover = false })
		end
		line.tile.icon:SetTexture(entry.icon)
		line.tile:ClearAllPoints()
		line.tile:SetPoint("CENTER", row, "TOPLEFT", GUTTER + PLATE / 2, -y - LINE_MID)
		line.tile:Show()
		x = x + SIGN_ROOM
	end
	local taken = 0          -- what stands at the line's right
	local drop = 0           -- ... and how far under a count's top: smaller words hang lower, on the same baseline
	if entry.need then
		RightSize(line)
		line.right:SetText(("%d%s"):format(entry.have, UI.Wrap(C.dim, "/" .. entry.need)))
		UI.Ink(line.right, entry.done and C.dim or C.text)
		taken = 30
		if not entry.done then
			line.track:ClearAllPoints()
			line.track:SetPoint("TOPRIGHT", -PAD - taken - 2, -y - 6)
			line.track:Show()
			local share = math.max(0, math.min(1, entry.have / entry.need))
			line.fill:SetShown(share > 0)
			UI.BoxFit(line.fill, math.max(1, BAR * share), BAR_TALL)
			line.fill:ClearAllPoints()
			line.fill:SetPoint("TOPLEFT", line.track, "TOPLEFT")
			taken = taken + BAR + 6
		end
	elseif entry.right then
		drop = RightSize(line, entry.rightSize)
		line.right:SetText(entry.right)
		UI.Ink(line.right, entry.rightColor or C.dim)
		taken = line.right:GetStringWidth() + 6
	end
	if taken > 0 then
		line.right:ClearAllPoints()
		line.right:SetPoint("TOPRIGHT", -PAD, -y - 1 - drop)
		line.right:Show()
	end
	line:SetWidth(width - x - PAD - taken)
	-- (A line with a tip says the rest there.)
	local wraps = wrap and not entry.need and (not entry.tip or entry.spill == true)
	line:SetWordWrap(wraps)
	line:SetMaxLines(wraps and 3 or 1)
	line:SetText(entry.text)
	UI.Ink(line, entry.color or C.text)
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", x, -y)
	line:Show()
	if entry.need and wrap and entry.sub then
		-- A count on the lead, and under it, quiet, what its guide says of it (who it is got from: ZONE.Under).
		line.sub:SetWidth(width - x - PAD)
		line.sub:SetText(entry.sub)
		line.sub:ClearAllPoints()
		line.sub:SetPoint("TOPLEFT", x, -y - LINE)
		line.sub:Show()
		return LINE + math.floor(line.sub:GetStringHeight() + 0.5) + 2
	end
	if entry.need or not wrap then return LINE end
	local height = math.max(13, line:GetStringHeight()) + 1
	if entry.sub then
		line.sub:SetWidth(width - x - PAD)
		line.sub:SetText(entry.sub)
		line.sub:ClearAllPoints()
		line.sub:SetPoint("TOPLEFT", x, -y - height + 1)
		line.sub:Show()
		height = height + line.sub:GetStringHeight() + 1
	end
	local beside = entry.sign and line.sign or entry.icon and line.tile
	if beside then
		-- The mark at the middle of its words (one line or two); where it is the taller, the words stand
		-- at its middle instead and the line is its height.
		local tall = math.max(height, ASIDE)
		local drop = math.floor((tall - height) / 2)
		if drop > 0 then
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", x, -y - drop)
			if entry.sub then
				line.sub:ClearAllPoints()
				line.sub:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -1)
			end
		end
		beside:ClearAllPoints()
		beside:SetPoint("CENTER", row, "TOPLEFT", GUTTER + PLATE / 2, -y - drop - (height - 2) / 2)
		height = tall
	end
	if entry.note then height = height + 2 end
	return height
end

-- Rows and objective lines are lit the family's one way (UI.RowLight): under the mouse, and held while what they
-- stand for is open in the Quests window beside the map (LogRows.lua, ns.QuestOpened): the quest, or the one
-- objective of it a click flew the map to. The map shut, nothing is held.
local function Opened()
	if ns.QuestOpened then return ns.QuestOpened() end
end

-- Whether the lead shows a line for that objective (then the line is held, not the row).
local function LinkFor(row, id, objective)
	for _, link in pairs(row.links or {}) do
		if link:IsShown() and link.objective and link.objective.id == id and link.objective.index == objective then return true end
	end
	return false
end

-- The quest a click on a stop's row opens beside the map (ns.OpenQuest), or nil: its first, in your log or one
-- still ahead of you (a pickup, a hand-in to come) that the data knows. An errand keeps its own click.
function ns.OpensQuest(stop)
	local action = stop and stop.kind ~= "errand" and stop.actions and stop.actions[1]
	local id = action and action.id
	return id and (L.Has(id) or D.Quest(id) ~= nil) and id or nil
end

local function RowLit(row)
	local stop, held = row.stop, false
	local id, objective = Opened()
	if id and stop and stop.kind ~= "errand" and stop.actions and stop.actions[1] and stop.actions[1].id == id then
		held = (objective == nil or stop.objective == nil or stop.objective == objective) and not (objective and LinkFor(row, id, objective))
	end
	row.light:Set(row.over, held)
end

local function LinkLit(link)
	local id, objective = Opened()
	local own = link.objective
	link.light:Set(link.over, own ~= nil and objective ~= nil and own.id == id and own.index == objective)
end
-- (Reached through ns: the card's maker is at its limit of upvalues.)
ns.CardLit = { Row = RowLit, Link = LinkLit }

-- A stop's frame: its node on the rail (a numbered pin or a plain mark), title, level and distance.
-- The lead's node is the dial.
local function CreateRow(card, lead)
	local row = CreateFrame("Frame", nil, card)
	row.lines = {}
	row.node = lead and DIAL / 2 + 3 or PIN / 2      -- the node's middle under the row's top
	row.light = UI.RowLight(row)
	-- A stop you put on your route yourself: a wash of your color from the rail, fading out (Node.Show).
	row.mine = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	row.mine:SetAllPoints()
	row.mine:SetColorTexture(1, 1, 1, 1)
	row.mine:Hide()
	row.rail = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.rail:SetWidth(2)
	UI.Paint(row.rail, C.border, 1)
	row.pin = ns.CreateMark(row, PIN)
	row.pin:SetPoint("CENTER", row, "TOPLEFT", RAIL, -row.node)
	row.mark = ns.CreateMark(row, MARK)
	row.mark:SetPoint("CENTER", row, "TOPLEFT", RAIL, -row.node)
	-- What a numbered place is for, over the pin's lower right; on the lead, over the dial's while the way
	-- is pointed.
	row.tag = ns.CreateMark(row, TAG)
	row.tag:SetPoint("CENTER", row, "TOPLEFT", RAIL + (lead and DIAL_TAG or PIN_TAG_X), -row.node - (lead and DIAL_TAG or PIN_TAG_Y))
	row.tag:SetFrameLevel(row.pin:GetFrameLevel() + 2)
	row.tag:Hide()
	row.title = UI.Text(row, "", lead and 15 or 12, true)
	row.title:SetPoint("TOPLEFT", GUTTER, lead and -4 or -3)
	row.yards = UI.Text(row, "", lead and 13 or 11, lead, lead and C.hot or C.dim)
	-- On the title's baseline: a line's baseline is its font's ascender share of its size down (Lilita One
	-- 0.808, the game font 0.794), so the title at 3 has it 12.7 down (at 4 on the lead, 16.1).
	row.yards:SetPoint("TOPRIGHT", -PAD, lead and -5.6 or -4)
	return row
end

-- What a stop is for (Marks.lua).
local Sign = ns.StopSign

-- A stop's node on the rail: what it shows (Show) and how far under the row's top it stands (Seat).
local Node = {}

-- Where a stop's node shows: a pin with the place's number (or a zone's quest count), else its mark.
-- A numbered place also says what it is for: its mark stands
-- over the pin's lower right (row.tagged: that mark's kind). Every pin stands on the rail, its point on it.
function Node.Show(row, stop, place, bare)
	local kind = ns.StopMark(stop)
	local number = kind == "zone" and Count(stop) or (place and place.number) or (stop.sample and stop.number)
	local sign, tone
	if number and kind ~= "zone" then sign, tone = Sign(stop) end
	row.tagged = sign
	-- (The same node as last time: left as it stands.)
	local lit = number and (kind == "zone" and stop.chosen or (place and place.lit)) or stop.chosen
	Node.Mine(row, stop)
	local said = ("%s|%s|%s|%s|%s|%s|%s|%d"):format(kind, tostring(number), tostring(sign), tostring(tone), tostring(bare),
		tostring(lit), tostring(not number and ns.StopTone(stop)) .. tostring(ns.StopMood(stop)), written.epoch)
	if row.nodeSaid == said then return end
	row.nodeSaid = said
	row.pin:SetShown(number ~= nil)
	row.mark:SetShown(number == nil)
	row.tag:SetShown(sign ~= nil)
	if number then
		row.pin:Set(kind == "zone" and "zone" or "step", kind == "zone" and stop.chosen or (place and place.lit), number)
		if sign then row.tag:Set(sign, false, nil, tone) end
	else
		row.mark:Set(kind, stop.chosen, nil, ns.StopTone(stop))
		row.mark:SetMood(ns.StopMood(stop))
	end
end

-- A stop you put on your route yourself (a place of it, or a quest you picked): the row washed in your color
-- (the theme's accent) from the rail, fading out to the right.
function Node.Mine(row, stop)
	local mine = stop ~= nil and (stop.picked ~= nil or stop.kind == "way")
	local said = mine and written.epoch or false
	if row.mineSaid == said then return end
	row.mineSaid = said
	row.mine:SetShown(mine)
	if mine then
		local r, g, b = Shy.Theme.Accent()
		row.mine:SetGradient("HORIZONTAL", CreateColor(r, g, b, MINE.from), CreateColor(r, g, b, MINE.to))
	end
end

-- How far under the row's top its node stands (row.seat): a pin's head comes up to the top of the
-- title's letters; a mark over lines sits between the title and them, and a mark under a title alone
-- is level with the title's middle, inside the row. alone "bare": an errand's in the tray, on its line's middle.
function Node.Seat(row, alone)
	local seat = row.pin:IsShown() and PIN_SEAT or alone == "bare" and BARE_ROW / 2 or alone and MARK_SEAT or row.node
	if row.seat == seat then return end
	row.seat = seat
	row.pin:ClearAllPoints()
	row.pin:SetPoint("CENTER", row, "TOPLEFT", RAIL, -seat)
	row.mark:ClearAllPoints()
	row.mark:SetPoint("CENTER", row, "TOPLEFT", RAIL, -seat)
	row.tag:ClearAllPoints()
	row.tag:SetPoint("CENTER", row, "TOPLEFT", RAIL + PIN_TAG_X, -seat - PIN_TAG_Y)
end

-- The rail through a row: from `above` over its top (a heading it runs through) down to its foot,
-- or only to its node when the rail ends here. nil: the row is off the rail.
local function Rail(row, above, ends, height)
	local from = above and (row.dial and row.node or -above)
	local to = above and (ends and (row.seat or row.node) or height)
	local said = ("%s|%s"):format(tostring(from), tostring(to))
	if row.railSaid == said then return end
	row.railSaid = said
	row.rail:SetShown(above ~= nil)
	if not above then return end
	row.rail:SetShown(to > from)
	row.rail:ClearAllPoints()
	row.rail:SetPoint("TOPLEFT", RAIL - 1, -from)
	row.rail:SetHeight(math.max(1, to - from))
end

-- The card

ns.QUESTS_TIP = "Your quests and where to go for them."   -- the card's hover, and its tab's in the deck

function ns.CreateCard(parent, onResize)
	local width = WIDTH   -- current width; changed by card:Fit
	local card = CreateFrame("Frame", nil, parent)
	card:SetWidth(width)
	-- A console piece's panel with its own header (hud: following the core's background strength). ShyDock's deck
	-- has a header of its own, so there it is put away whole and the card's controls stand in the deck's (card:Dock).
	UI.Panel(card, { hud = true, title = STRIP })
	card.opened = {}      -- zones unfolded, by Fold's key

	-- The title bar, a click across all of it: it folds the quests away, down to this bar, and opens them again, as
	-- every piece folds (UI.FoldHead: the title, the caret after it). The tools in the bar (the pager and its step
	-- count, the lens, the notes) stand over it and keep their own clicks; a drag is still a drag, and the
	-- right button still the menu (SetupCard manages it). In ShyDock's deck its header does the same, the same way.
	-- Only the on-screen card folds (Lay); docked, the bar is put away and the deck's header stands for it.
	card.titlebar = CreateFrame("Button", nil, card)
	card.titlebar:SetPoint("TOPLEFT", 2, -2)
	card.titlebar:SetPoint("TOPRIGHT", -2, -2)
	card.titlebar:SetHeight(STRIP)
	card.titlebar:SetFrameLevel(card:GetFrameLevel() + 1)
	card.fold = UI.FoldHead(card.titlebar, card, { title = "Quests" })
	card.fold:SetFoldable(false)
	card.name, card.caret = card.fold.title, card.fold.caret
	card.titlebar:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or (card.wasDragged and card.wasDragged()) then return end
		ns.CollapseQuests(ns.char.questsShut ~= true)
	end)
	card.count = UI.Text(card, "", 10, false, C.dim)
	UI.OnHead(card.count, "RIGHT", card, "RIGHT", -PAD)
	-- Why the lead leads ("ON YOUR WAY"), under its title.
	card.caption = UI.Text(card, "", 10, false, C.dim)
	card.caption:SetWordWrap(false)

	-- The header's tools (the core's caret, rotated; the lens; the notes' i): glyphs in the strip in the family's make
	-- (UI.KeyPress, bare), so they answer as every header control does: a plate under the mouse, sunk a unit while
	-- held, the plate kept lit while on (the whole guide open, the finder open), dimmed and quiet when there is
	-- nothing to do. They act on a click only: a press may start a drag of the box (SetupCard), which
	-- card.wasDragged reports. `place(glyph)` anchors the glyph once (a press sinks it from there).
	local function StepButton(turn, act, title, help, place)
		local button = CreateFrame("Button", nil, card)
		button:SetSize(PAGER, PAGER)
		button:SetFrameLevel(card:GetFrameLevel() + 4)   -- over the title bar's own click
		button:SetMotionScriptsWhileDisabled(true)       -- out of use, its hover still says why
		local glyph = button:CreateTexture(nil, "ARTWORK")
		glyph:SetSize(9, 9)   -- as tall as the count's digits
		glyph:SetTexture(Shy.Skin.GLYPH.caret)
		glyph:SetRotation(turn)
		button.glyph = glyph
		if place then place(button, glyph) else glyph:SetPoint("CENTER") end
		button:SetScript("OnEnter", function(self)
			local name = title
			if type(name) == "function" then name = name() end
			UI.Tip(self, name, help(self.can), { side = "TOP" })
		end)
		button:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		button:SetScript("OnMouseUp", function(self, mouse)
			if mouse == "LeftButton" and self.can and not (card.wasDragged and card.wasDragged()) then
				UI.TipHide(self, true)
				act()
			end
		end)
		-- (The make hooks the scripts above: set none after it, or its hooks go with them.)
		UI.KeyPress(button, { fill = C.bg, glyphs = { glyph, button.bar }, sink = { glyph } })
		button:SetBare(true)
		-- Told at every layout: the make is dressed again only when a state changes.
		function button:Able(can)
			can = can and true or false
			if self.can == can then return end
			self.can = can
			self:SetEnabled(can)
			self:SetAlpha(can and 1 or 0.35)
		end
		function button:Lit(on)
			on = on and true or false
			if self.isOn == on then return end
			self.isOn = on
			self:SetOn(on)
		end
		button:Able(true)
		button:Hide()
		return button
	end
	card.skip = StepButton(math.pi / 2, function()
		-- The guide step shown, which isn't always the first row.
		local stop = card.guideStop
		if stop then G.Skip(stop.view.step.index, stop.view.guide) end
	end, "Skip this step", function(can)
		return can and "Skips this step. If it picks up a quest, you skip that quest's later steps too. Back undoes it."
			or "No step to skip."
	end, function(button, glyph)
		glyph:SetPoint("CENTER", -2, 0)
		-- The bar after the caret: a white texture the make tints with the glyph, riding along with it.
		button.bar = button:CreateTexture(nil, "ARTWORK")
		button.bar:SetColorTexture(1, 1, 1, 1)
		button.bar:SetSize(2, 7)
		button.bar:SetPoint("LEFT", glyph, "CENTER", 3, 0)
	end)
	card.back = StepButton(-math.pi / 2, function() G.Back() end, "Back a step", function(can)
		return can and "Goes back to the last step you haven't finished and stays there until you do it or skip it."
			or "No earlier step."
	end, function(_, glyph) glyph:SetPoint("CENTER", 2, 0) end)   -- both glyphs lean toward the count

	-- The step count between them is the whole guide's switch: a click lists every step of your guide with your
	-- progress, another only the steps ahead; its plate stays lit while every step is listed. The count stands on
	-- it, so the plate is the digits' own. (Only the on-screen card has the list, so the preview's count is words
	-- alone: Head.)
	card.steps = StepButton(0, function() ns.ToggleGuideWindow() end,
		function() return card.full and "The steps ahead" or "Every step" end,
		function()
			return card.full and "Back to the steps ahead of you." or "Every step of your guide, with your progress."
		end, function(_, glyph) glyph:Hide() end)
	card.count:SetParent(card.steps)
	card.steps:SetPoint("LEFT", card.count, "LEFT", -ZONE.steps, 0)
	card.steps:SetPoint("RIGHT", card.count, "RIGHT", ZONE.steps, 0)
	card.back:SetPoint("RIGHT", card.steps, "LEFT", -1, 0)
	function card.steps:Turn(full)
		full = full and true or false
		if self.full == full then return end
		self.full = full
		self:Lit(full)
	end
	card.steps:Turn(false)

	-- The lens before the pager opens the finder (Find.lua): the search box's own picture, lit while it is open.
	card.find = StepButton(0, function()
		if ns.Find then ns.Find.Toggle() end
	end, "Find anywhere", function()
		return "Find any quest, creature, object or item, or the nearest innkeeper, trainer or vendor. The box under the header only filters your own quests."
	end, function(_, glyph) glyph:SetPoint("CENTER", 0, -1) end)
	card.find.glyph:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	card.find.glyph:SetSize(11, 11)
	Shy:On("SHYQUEST_FINDER", function(open) card.find:Lit(open) end)

	-- The controls at the top of the open card: a switch between the two ways the card works (live: the setting
	-- is swapped at once), and a box that filters your own quests as you type. (The lens in the header is the
	-- other search: anything in the game.) Only the on-screen card has them (Lay).
	card.controls = CreateFrame("Frame", nil, card)
	card.controls:SetHeight(ZONE.controls)
	-- Dungeon: a mode of its own (Run.lua), only the steps to get one dungeon's quests. Picked, it asks which dungeon;
	-- Zone or Guide picked during a run ends it. (Without Run.lua loaded it does nothing: a file new to the TOC needs
	-- a restart.)
	card.style = UI.Segmented(card.controls, { "Zone", "Guide", "Dungeon" },
		function()
			if ns.Run and ns.Run.Doing() then return 3 end
			return ns.Following() and 2 or 1
		end,
		function(index)
			if index == 3 then
				if ns.Run then ns.Run.Pick(card.style) end
				card.style:Refresh()
				return
			end
			if index == 2 and ns.Run and ns.Run.Doing() then ns.Run.Stop(true) end
			T:SetQuestStyle(index == 2 and "guide" or "zone")
		end,
		{ width = ZONE.switch, height = 24, tips = {
			"The quests where you are, in the order you'll do them.",
			"Follow your leveling guide. Its steps come first, then nearby quests.",
			"Just the steps for one dungeon's quests, in that dungeon's colors." } })
	card.style:SetPoint("LEFT", PAD, 0)
	card.search = UI.Input(card.controls, nil, function() return card.filter or "" end, function(text)
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		card.filter = text ~= "" and text:lower() or nil
		card:Refill()
	end, { width = 120, live = true, placeholder = function() return "Filter quests" end })
	card.search:SetPoint("RIGHT", card.controls, "RIGHT", -PAD, 0)
	card.none = UI.Text(card.controls, "No quest matches that.", 11, false, C.dim)
	card.none:SetPoint("BOTTOMLEFT", PAD + 2, 4)
	card.none:Hide()
	card.controls:Hide()

	-- The guide's notes before the lens: shown only while something waits on you (quests in your log the guide has
	-- no use for: drop them?), an i in a ring and their count in gold. Following the guide as it goes (its skipped
	-- quests here, the earlier steps to catch up on the map) is no note: its hover mentions them alongside. A click
	-- opens the window that sorts them (Notice.lua). They once stood as a line of words at the foot of the steps.
	card.notes = StepButton(0, function() ns.OffGuide(true) end, "Guide notes", function()
		return (card.notes.tip or "") .. " Click to see them and choose what to do."
	end, function(button, glyph)
		glyph:SetPoint("LEFT", 1, 0)
		-- The count rides on the glyph, so a press sinks both.
		button.count = UI.Text(button, "", 10, true)
		button.count:SetPoint("LEFT", glyph, "RIGHT", 2, 0)
	end)
	local info = UI.MenuGlyph("info")[1]
	card.notes.glyph:SetTexture(info[1])
	card.notes.glyph:SetTexCoord(unpack(info.coords))
	card.notes.glyph:SetSize(11, 11)
	-- Its count in the glyph's ink: the rest's (the alert's while something waits on you), the head's lit.
	function card.notes:OnLook(state)
		UI.Ink(self.count, (state.over or state.on) and self.can and C.head or self.rest or C.dim)
	end
	-- Its color at rest: the alert's while something waits on you.
	function card.notes:Rest(color)
		if self.rest == color then return end
		self.rest = color
		self:SetRest(color)
	end
	card.notes:Rest(C.dim)

	-- In the whole guide the caption is the guide's name; this frame over it opens the guide list.
	local pick = CreateFrame("Frame", nil, card)
	pick:SetPoint("TOPLEFT", card.caption, "TOPLEFT", -3, 4)
	pick:SetPoint("BOTTOMRIGHT", card.caption, "BOTTOMRIGHT", 3, -4)
	pick:EnableMouse(true)
	pick:SetScript("OnEnter", function(self)
		UI.Ink(card.caption, C.hot)
		UI.Tip(self, G.current and G.current.name or "Your guide", "Pick another guide, or find your place in this one again.",
			{ side = "TOP", hints = { { "left", "Pick a guide" } } })
	end)
	pick:SetScript("OnLeave", function(self)
		UI.Ink(card.caption, C.dim)
		UI.TipHide(self)
	end)
	pick:SetScript("OnMouseUp", function(self, mouse)
		if mouse == "LeftButton" and ns.GuideList and not (card.wasDragged and card.wasDragged()) then ns.GuideList.Pick(self) end
	end)
	pick:Hide()
	card.pick = pick

	-- The lead: the dial, with the way to go turning in it.
	local first = CreateRow(card, true)
	first.wash = first:CreateTexture(nil, "BACKGROUND", nil, -1)
	first.wash:SetAllPoints()
	UI.Paint(first.wash, C.fill, 0.2)
	first.dial = first:CreateTexture(nil, "ARTWORK", nil, -1)
	first.dial:SetTexture(Shy.MEDIA .. "DialLead")
	first.dial:SetSize(DIAL_ART, DIAL_ART)
	first.dial:SetPoint("CENTER", first, "TOPLEFT", RAIL, -first.node)
	UI.Tint(first.dial, Shy.Theme.skin.metal)
	first.weave = Shy.Skin.Weave(first, 30, "ARTWORK", 0)
	first.weave:ClearAllPoints()
	first.weave:SetPoint("CENTER", first, "TOPLEFT", RAIL, -first.node)
	Shy.Skin.WeaveTint(first.weave, Shy.Theme.skin.metal)
	first.arrow = first:CreateTexture(nil, "OVERLAY")
	first.arrow:SetSize(WAY, WAY)
	first.arrow:SetPoint("CENTER", first, "TOPLEFT", RAIL, -first.node)
	first.arrow:SetTexture(ns.MEDIA .. "ArrowLead")
	UI.Concentric(first.dial, first.arrow)
	UI.Tint(first.arrow, C.hot)
	-- On the ground where the lead is done nothing points: the emblem of what is found there fills the
	-- dial, in its color as on any mark, and the dial's ring takes that color (the dial is its plate).
	first.here = first:CreateTexture(nil, "OVERLAY")
	first.here:SetSize(HERE, HERE)
	first.here:SetPoint("CENTER", first, "TOPLEFT", RAIL, -first.node)
	first.here:SetTexture(ns.MEDIA .. "Marks")
	UI.Concentric(first.here)
	first.here:Hide()
	first.pin:Hide()
	-- A click on the dial keeps the waypoint arrow on screen (Arrow.lua), following the steps as
	-- they are done; another puts it away. While it is up the dial's ring is lit.
	local way = CreateFrame("Frame", nil, first)
	way:SetSize(DIAL, DIAL)
	way:SetPoint("CENTER", first, "TOPLEFT", RAIL, -first.node)
	way:EnableMouse(true)
	way:SetScript("OnEnter", function(self)
		if not ns.Arrow then return end
		local up = ns.Arrow.Following()
		UI.Tip(self, "Waypoint arrow", up and "On screen, pointing at your current step. It moves on as you finish steps."
			or "Keeps an arrow on screen that points at your current step and moves on as you finish steps. Drag it where you like.",
			{ side = "LEFT", hints = { { "left", up and "Put it away" or "Keep it on screen" } } })
	end)
	way:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	way:SetScript("OnMouseUp", function(_, mouse)
		if mouse == "LeftButton" and ns.Arrow and not (card.wasDragged and card.wasDragged()) then ns.Arrow.Toggle() end
	end)
	first.way = way
	-- The countdown (GuideTimers.lua and Escort.lua, if loaded): a plate of its own under the first
	-- step's lines and over its notes, whatever the step is, or alone when there is no step. It wears
	-- the color of what is counted, as its mark does: a flight's wing, an escort's face; a guide's wait
	-- and a quest's own clock the gold of attention, with no mark. Who or where on the left, on a
	-- second line rather than cut (the plate grows for it); the time on the right, its "about" or "so
	-- far" small at the end of the bar of the share left.
	local timer = CreateFrame("Frame", nil, card)
	timer:SetSize(WIDTH - GUTTER - PAD, PLATE)
	timer.wash = timer:CreateTexture(nil, "BACKGROUND")
	timer.wash:SetAllPoints()
	timer.wash:SetColorTexture(1, 1, 1, 1)
	timer.mark = ns.CreateMark(timer, ASIDE)
	timer.mark:SetPoint("CENTER", timer, "LEFT", PLATE / 2, 0)
	timer.label = UI.Text(timer, "", 12, false, C.text)
	timer.label:SetWordWrap(true)
	timer.label:SetMaxLines(2)
	timer.left = UI.Text(timer, "", 13, true, C.alert)
	timer.words = UI.Text(timer, "", 10, false, C.dim)
	timer.track = timer:CreateTexture(nil, "ARTWORK")
	timer.track:SetHeight(3)
	UI.Paint(timer.track, C.rowEdge, 1)
	timer.fill = timer:CreateTexture(nil, "ARTWORK", nil, 1)
	timer.fill:SetPoint("TOPLEFT", timer.track, "TOPLEFT")
	timer.fill:SetHeight(3)
	-- What is counted: its color and its mark (the mark's kind and objective, as for a stop).
	local LOOKS = {
		flight = { color = ns.SignColor("flight"), mark = "flight" },
		sail = { color = ns.SignColor("sail"), mark = "sail" },   -- a boat (an airboat: the flight's)
		zeppelin = { color = ns.SignColor("zeppelin"), mark = "zeppelin" },
		tram = { color = ns.SignColor("tram"), mark = "tram" },
		escort = { color = ns.ToneColor("escort"), mark = "goal", tone = "escort" },
		wait = { color = C.alert },
	}
	function timer:Look(kind)
		if kind == self.kind then return end
		self.kind = kind
		local look = LOOKS[kind]
		local r, g, b = look.color[1], look.color[2], look.color[3]
		self.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.16), CreateColor(r, g, b, 0.03))
		UI.Paint(self.fill, look.color, 1)
		UI.Ink(self.left, look.color)
		self.mark:SetShown(look.mark ~= nil)
		if look.mark then self.mark:Set(look.mark, false, nil, look.tone) end
		local inset = look.mark and PLATE or PLATE_IN + 2
		self.inset = inset
		self.label:ClearAllPoints()
		self.label:SetPoint("TOPLEFT", inset, -6)
		self.track:ClearAllPoints()
		self.track:SetPoint("BOTTOMLEFT", inset, 7)
		self.said, self.face = nil, nil
		-- An escort's plate has something to say under the mouse (Escort.Quip), and a click shares the
		-- walk; the others neither.
		self:EnableMouse(kind == "escort")
		if kind == "escort" and not self.managed and card.manage then
			self.managed = true
			card.manage(self, function(root)
				if ns.Escort.Share then root:CreateButton("Share escort progress", ns.Escort.Share) end
			end)
			self:HookScript("OnMouseUp", function(plate, mouse)
				if mouse ~= "LeftButton" or plate.kind ~= "escort" or (card.wasDragged and card.wasDragged()) then return end
				if ns.Escort.Share then ns.Escort.Share() end
			end)
		end
	end
	-- The escort's face as the walk goes: weary, frazzled past its time, beaming at its end.
	function timer:Face(face)
		if face == self.face then return end
		self.face = face
		self.mark:SetEmblem(face)
		if self.hovered then self:Quip() end
	end
	function timer:Quip()
		UI.Tip(self, self.label:GetText(), ns.Escort.Quip(self.face),
			{ side = "LEFT", hints = card.manage and ns.Escort.Share and { { "left", "Share progress" } } or nil })
	end
	timer:SetScript("OnEnter", function(self)
		self.hovered = true
		self:Quip()
	end)
	timer:SetScript("OnLeave", function(self)
		self.hovered = false
		UI.TipHide(self)
	end)
	-- Lays out the time, the words that go with it at the bar's end under it ("about", "so far"), the
	-- label and the bar in the room they leave, and the plate's height round them. The clock's room is
	-- kept the same as it counts, so the label wraps only when it changes.
	function timer:Say(said)
		if said == self.said then return end
		self.said = said
		local before, clock, after = said:match("^(.-)%s*(%d+:%d%d)%s*(.*)$")
		if not clock then before, clock, after = "", said, "" end
		local words = before ~= "" and before or after
		self.left:SetText(clock)
		self.left:ClearAllPoints()
		self.left:SetPoint("TOPRIGHT", -PLATE_IN, -5)
		self.words:SetText(words)
		self.words:ClearAllPoints()
		self.words:SetPoint("RIGHT", self, "BOTTOMRIGHT", -PLATE_IN, 8.5)
		local room = self:GetWidth() - self.inset - PLATE_IN
		self.label:SetWidth(math.max(20, room - math.max(CLOCK_ROOM, self.left:GetStringWidth()) - 8))
		self.span = math.max(20, room - (words ~= "" and self.words:GetStringWidth() + 5 or 0))
		self.track:SetWidth(self.span)
		self:SetHeight(math.max(PLATE, math.floor(self.label:GetStringHeight() + 0.5) + 18))
	end
	function timer:Tick()
		local stop = first:IsShown() and first.stop or nil
		local label, left, share, said, face
		local kind = "wait"
		if ns.GuideTimers then
			label, left, share, said = ns.GuideTimers.Running(stop ~= nil and stop.kind == "guide", not (stop and stop.sample))
			if label and not (stop and stop.sample) then
				-- A flight, or a crossing (its own sign: a boat's sail, a zeppelin).
				if ns.GuideTimers.Flying() then
					kind = "flight"
				elseif ns.GuideTimers.Sailing then
					kind = ns.GuideTimers.Sailing() or kind
				end
			end
		end
		-- Or an escort being walked (Escort.lua, if loaded).
		if not label and ns.Escort and not (stop and stop.sample) then
			label, left, share, said, face = ns.Escort.Running()
			if label then kind = "escort" end
		end
		-- Otherwise the first step's quest timer (R.Clock).
		if not label and stop and not stop.sample and stop.actions then label, left, share = R.Clock(stop) end
		if not label then
			self:Hide()
			return false
		end
		self:Look(kind)
		if kind == "escort" then self:Face(face) end
		if label ~= self.label:GetText() then
			self.label:SetText(label)
			self.said = nil
		end
		self:Say(said or ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)))
		-- No bar when the duration is unknown (a flight being timed for the first time).
		self.fill:SetShown(share > 0)
		self.fill:SetWidth(math.max(1, self.span * share))
		return true
	end
	timer:Hide()
	first.timer = timer

	-- Clickable lines: a link (its address is offered for copying), a failed quest (abandon it), or a
	-- task with its own place (aim the route at it: R.Aim). A note with a tip only says it on hover.
	first.links = {}
	local function Link(i)
		local link = first.links[i]
		if not link then
			link = CreateFrame("Frame", nil, first)
			link:EnableMouse(true)
			-- (Its light is the lead's own regions, under the line's words.)
			link.light = UI.RowLight(link, { left = UI.ROW_INSET, right = 2 }, first)
			link:SetScript("OnEnter", function(self)
				self.over = true
				ns.CardLit.Link(self)
				-- An objective: what it is after, the creature turning over its facts (CardHover.Objective),
				-- and its own ground lit on the open map.
				if self.objective and not self.url and not self.failed and ns.CardHover and ns.CardHover.Objective then
					ns.CardHover.Objective(self, first.stop, self.objective.id, self.objective.index, card)
					if ns.LightObjective then ns.LightObjective(self.objective.id, self.objective.index) end
					return
				end
				if self.url then
					UI.Tip(self, "A link from your guide", "Copy the address and paste it into a browser.",
						{ side = "TOP", hints = { { "left", "Copy address" } } })
				elseif self.failed then
					-- A failed quest stays in the log until abandoned, and can't be accepted again before that.
					UI.Tip(self, "Quest failed", "Abandon it, then accept it again from the quest giver. The card points you there.",
						{ side = "TOP", hints = { { "left", "Abandon" } } })
				elseif self.asked then
					UI.Tip(self, "Heading here", "You picked this one to do first.",
						{ side = "TOP", hints = { { "left", "Let the guide choose" } } })
				elseif self.tip then
					-- (A line that stands for several, ZONE.Cut: each of them, as rows.)
					UI.Tip(self, self.tip[1], self.tip[2], { side = "TOP", sections = self.tip[3] and { { rows = self.tip[3] } } or nil })
				else
					UI.Tip(self, "This task", "Points the arrow and the map here.",
						{ side = "TOP", hints = { { "left", "Show the way" } } })
				end
			end)
			link:SetScript("OnLeave", function(self)
				self.over = false
				ns.CardLit.Link(self)
				UI.TipHide(self)
				if self.objective and ns.CardHover and ns.CardHover.Objective then
					ns.CardHover.Hide(self)
					if ns.LightObjective then ns.LightObjective(nil) end
				end
			end)
			link:SetScript("OnMouseUp", function(self, mouse)
				if mouse ~= "LeftButton" or (card.wasDragged and card.wasDragged()) then return end
				if self.objective and not self.url and not self.failed and not self.task then
					-- An objective of a quest in your log: the map opens with the quest's page beside it, flown to
					-- where that objective is done, lit.
					local id = self.objective.id
					if id and L.Has(id) and ns.OpenQuest then ns.OpenQuest(id, self.objective.index) end
					return
				end
				if self.url then
					UI.ShowCopyBox("A link from your guide", self.url)
				elseif self.failed then
					L.AbandonFailed(self.failed)
				elseif self.task and first.stop and first.stop.kind == "guide" then
					R.Aim(first.stop, self.task)
				end
			end)
			if card.manage then card.manage(link) end
			first.links[i] = link
		end
		return link
	end
	card.first = first

	-- Headings between kinds of rows ("YOUR GUIDE", "ERRANDS", "OTHER QUESTS", "WHERE NEXT"), one line
	-- each, with a hairline running on to the card's edge.
	-- Under the lead, everything scrolls: the steps after it, the places ahead, the errands, the zones and their
	-- quests, as one body in the room the card's place leaves it. The lead (and the guide's buttons docked
	-- under it) and ShyXP's strip at the foot stand still. (Its shades fade into the card's own surface; its
	-- thumb wears the accent; the wheel is the card's only while there is something to scroll.)
	card.body = UI.ScrollArea(card, WIDTH, 1, { smooth = true, shades = C.hud, quiet = true,
		onScroll = function(_, now) card:Pin(now) end })
	card.body:Hide()
	local body = card.body.content

	card.headings = {}
	for i = 1, 5 do
		local heading = UI.Text(body, "", 10, false, C.dim)
		heading:SetWordWrap(false)
		heading:SetJustifyH("LEFT")
		heading.rule = body:CreateTexture(nil, "ARTWORK")
		heading.rule:SetHeight(1)
		UI.Paint(heading.rule, C.rowEdge, 0.8)
		heading:Hide()
		heading.rule:Hide()
		card.headings[i] = heading
	end

	-- The later stops
	card.rows = { first }
	for i = 2, MAX_ROWS + MAX_TRACKED + MAX_ZONES + MAX_GUIDE + MAX_AHEAD + MAX_ERRANDS do
		card.rows[i] = CreateRow(card, false)
	end

	-- A zone's line (its name over what is in it), as the real ones and the pinned copy of the one being read are
	-- both made: a band of its own under a hairline, so where a zone begins is plain at any length of list.
	-- A click opens its quests, or folds them.
	-- (The family's group head, UI.GroupHead: what unfolds it is the family's fold mark, a mark among the marks on
	-- the rail, pointing on while shut and down while open.)
	local function NewHead(parent)
		local head = UI.GroupHead(parent, { height = ZONE.height, rail = RAIL, gutter = GUTTER, right = PAD, foldSize = MARK,
			tip = function(self)
				return self.name, self.aside and "Quests out of your way for now. You'll get them when you pass nearby."
					or self.open and "Quests you aren't tracking, by zone."
					or "Quests in your log for other zones. You'll see them again when you get there.",
					{ side = "LEFT", hints = { { "left", self.open and "Fold" or "Show them" } } }
			end,
			click = function(self, mouse)
				if mouse ~= "LeftButton" or not self.key or (card.wasDragged and card.wasDragged()) then return end
				card.opened[self.key] = not card.opened[self.key] or nil
				card:Refill()
				-- Opened, it glides into view: its line and as much under it as there is room for.
				local fold = card.folds[self.index]
				if card.opened[self.key] and fold and fold.top then card.body:Reveal(fold.top, fold.bottom) end
			end })
		head.chip = head.fold
		return head
	end

	-- The zones stand at the body's foot. An open zone's quests are a group: a faint wash of the accent behind
	-- them and a rail of it down the left, from the zone's button to the last of them (the head's Hang).
	card.folds = {}
	for i = 1, MAX_FOLDS do
		local fold = NewHead(body)
		fold.index = i
		fold:Hide()
		card.folds[i] = fold
	end

	-- The zone being read: while its quests scroll under the body's top, its line stays there (a copy of it,
	-- the real one having gone up), so which zone a quest belongs to is never lost. It goes when the next line
	-- comes up under it. (Set by Pin, as the body scrolls and as it is laid out.)
	card.pin = NewHead(card)
	card.pin:SetFrameLevel(card.body:GetFrameLevel() + 12)
	card.pin:Hide()
	card.pin.glow:SetAlpha(1)
	function card:Pin(now)
		local pin, at = self.pin, nil
		now = now or self.body:At()
		for _, fold in ipairs(self.folds) do
			if fold:IsShown() and fold.open and fold.top and fold.bottom and fold.top < now - 0.5
				and now < fold.bottom - ZONE.height * 0.6 then
				at = fold
			end
		end
		if not at or not self.body:IsShown() then
			pin:Hide()
			pin.key = nil
			return
		end
		if pin.key ~= at.key or pin.said ~= at.said then
			pin.key, pin.said, pin.index = at.key, at.said, at.index
			pin.name, pin.open, pin.aside = at.name, true, at.aside
			pin.chip:Set("open")
			pin.text:SetText(at.text:GetText())
			pin.text:SetWidth(width - GUTTER - PAD)
			pin.sub:SetText(at.sub:GetText())
			pin.sub:SetWidth(width - GUTTER - PAD)
		end
		-- (Anchored to the card's top, where the body's is.)
		if pin.at ~= self.bodyTop or pin.wide ~= width then
			pin.at, pin.wide = self.bodyTop, width
			pin:ClearAllPoints()
			pin:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(self.bodyTop or 0))
			pin:SetWidth(width)
		end
		pin:Show()
	end

	-- A quest waiting for a click: one an item offers, or one that can be completed where you stand.
	card.notices = {}
	for i = 1, MAX_NOTICES do
		local notice = CreateFrame("Frame", nil, body)
		notice:SetHeight(ZONE.row)
		notice.sign = ns.CreateMark(notice, MARK)
		notice.sign:SetPoint("CENTER", notice, "LEFT", RAIL, 0)
		notice.text = UI.Text(notice, "", 12, false, C.alert)
		notice.text:SetPoint("LEFT", GUTTER, 0)
		notice.text:SetWordWrap(false)
		notice.glow = notice:CreateTexture(nil, "BACKGROUND")
		notice.glow:SetAllPoints()
		UI.Paint(notice.glow, C.alert, 0.1)
		notice:EnableMouse(true)
		notice:SetScript("OnEnter", function(self)
			UI.Tip(self, self.title, self.offer and "An item in your bags starts this quest." or "You can complete this quest here.",
				{ side = "LEFT", hints = { { "left", self.offer and "Read the quest" or "Complete it" } } })
		end)
		notice:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		notice:SetScript("OnMouseUp", function(self, mouse)
			if mouse ~= "LeftButton" or not self.id or (card.wasDragged and card.wasDragged()) then return end
			ns.OpenQuestPopup(self.id, self.offer)
		end)
		notice:Hide()
		card.notices[i] = notice
	end

	-- Turn the arrow toward the first step (while dead that is the way back to the body, Death.lua).
	-- With no way to show,
	-- the stop's own mark stands in the dial: and standing on the ground where what it asks for is
	-- found (stop.among, Route.lua), the emblem of that fills the dial (first.here), since there is
	-- nowhere more to be led. The arrow points along the way the maps draw (W.Heading), as the waypoint
	-- arrow's hand does. elapsed: seconds since the last frame, for it to come round to a new bearing.
	local function Point(elapsed)
		local stop = first.stop
		first.keep = first.keep or {}
		local turn = stop and stop.north and W.Heading(stop.continent, stop.north, stop.west, first.keep, elapsed)
		if stop and stop.sample then turn = stop.turn end
		local among = stop ~= nil and stop.among ~= nil
		-- (Every frame: each thing is told only what changed. The turn, past a hair of it.)
		local arrowOn = turn ~= nil and (stop.yards or ARRIVED) >= ARRIVED and not among
		if arrowOn and (first.turned == nil or math.abs(first.turned - turn) > 0.002) then
			first.turned = turn
			first.arrow:SetRotation(turn)
		end
		if first.arrow:IsShown() ~= arrowOn then first.arrow:SetShown(arrowOn) end
		-- The dial's ring is the arrow's alone: a mark or an emblem has its own plate, and stands bare.
		if first.dial:IsShown() ~= arrowOn then
			first.dial:SetShown(arrowOn)
			first.weave:SetShown(arrowOn)
		end
		if first.here:IsShown() ~= among then first.here:SetShown(among) end
		local markOn = not among and not arrowOn
		if first.mark:IsShown() ~= markOn then first.mark:SetShown(markOn) end
		-- While the way is pointed, what the stop is for stands over the dial's lower right.
		local tagOn = arrowOn and first.tagged ~= nil
		if first.tag:IsShown() ~= tagOn then first.tag:SetShown(tagOn) end
	end

	-- Apply `width` (ShyDock may put the card in a column of another width).
	local function Widths()
		card:SetWidth(width)
		timer:SetWidth(width - GUTTER - PAD)
		timer.said = nil
	end

	function card:Fit(w)
		if math.abs(w - width) < 0.5 then return end
		width = w
		Widths()
		if self.all then self:Fill(self.all) end
	end

	-- In ShyDock's deck the column draws the panel and its header holds the pager: `column` is that panel (the
	-- card's controls stand in its header through UI.OnHead, as they do in the card's own; nil: it stands alone).
	function card:Dock(on, column)
		self.docked, self.column = on, on and column or nil
		self.shyBg:SetShown(not on)
		self.shyEdge:SetShown(not on)
		for _, bracket in ipairs(self.shyBrackets) do bracket:SetShown(not on) end
		UI.PanelHead(self, not on)
		-- Docked, the deck is the housing: the card wears no look of its own; alone, the theme's again.
		if on then UI.SetLook(self, false) else UI.SetLook(self, nil) end
		if self.all then self:Fill(self.all) end
	end

	-- The header: the pager round the count, at the right of the card's own strip or of the deck's.
	-- Whether the card follows a leveling guide (guide mode), or just lists the quests (zone mode).
	local function Following()
		return ns.Following() and G.current ~= nil
	end

	local function Head(self, guided, total, stop)
		local column = self.column
		-- Steps and the whole guide are for following one: in zone mode the header has neither. The step count is
		-- the whole guide's switch where there is a list to show (not the preview's, nor a dungeon run's).
		local mode = self.list ~= nil and Following() and not G.current.run
		self.steps:SetShown(guided)
		self.steps:EnableMouse(mode)
		self.steps:Turn(mode and self.full)
		if guided then
			-- Counted among this character's steps.
			self.count:SetText(("%d / %d"):format(G.Number(self.guideStop.view.step.index, self.guideStop.view.guide)))
		else
			self.count:SetText("")
		end
		self.skip:ClearAllPoints()
		self.count:ClearAllPoints()
		-- On the middle of the header the card stands in: its own, or the deck's.
		local host = column or self
		UI.OnHead(self.skip, "RIGHT", host, "RIGHT", -PAD + 4)
		if guided then
			self.count:SetPoint("RIGHT", self.skip, "LEFT", -1 - ZONE.steps, 0)
			self.back:Able(G.CanBack())
			self.skip:Able(true)
		else
			UI.OnHead(self.count, "RIGHT", host, "RIGHT", -PAD)
		end
		self.back:SetShown(guided)
		self.skip:SetShown(guided)
		-- The finder's lens stands before the pager, or before the count where there is none. Only the
		-- on-screen card has it, as with the chevron.
		local words = self.count:GetText()
		self.find:ClearAllPoints()
		self.find:SetPoint("RIGHT", guided and self.back or self.count, "LEFT", (guided or (words and words ~= "")) and -4 or 0, 0)
		self.find:SetShown(self.list ~= nil and ns.Find ~= nil)
		self.notes:ClearAllPoints()
		self.notes:SetPoint("RIGHT", self.find, "LEFT", -2, 0)
	end

	-- On the ground where the lead is done, its caption says so in place of why it leads, in what is
	-- found there's color: "LOOT HERE", and on grounds lying over one another "KILL AND LOOT HERE".
	-- nil where the caption is someone else's: what can't wait and an errand say it in their own
	-- words, and the whole guide's caption is its name.
	local function Here(self, stop)
		if not (stop and stop.among) or stop.urgent or stop.found or self.full then return nil end
		local words, seen = {}, {}
		for _, each in ipairs(stop.amongAll or { { kind = stop.among } }) do
			local kind = ns.KIND[each.kind]
			if kind and not seen[each.kind] then
				seen[each.kind] = true
				words[#words + 1] = kind.word:upper()
			end
		end
		if #words == 0 then return nil end
		local last = table.remove(words)
		return (#words > 0 and (table.concat(words, ", ") .. " AND ") or "") .. last .. " HERE", ns.ToneColor(stop.among)
	end

	-- The lead's caption: why it leads.
	local function Caption(self, stop)
		if stop and stop.urgent then
			-- What can't wait says so itself, whatever the card is showing.
			return stop.caption or "ON YOUR WAY"
		elseif self.full then
			return ns.Run and ns.Run.Caption(G.current) or G.current and G.current.name:upper() or "YOUR GUIDE"
		elseif stop and stop.kind == "guide" and stop.view.guide.run and ns.Run then
			return ns.Run.Caption(stop.view.guide, stop.view.step.index)
		elseif stop and stop.kind == "guide" and stop.here then
			return "RIGHT HERE  \194\183  FROM YOUR GUIDE"
		elseif stop and stop.kind == "guide" then
			return ((stop.catch and "CATCHING UP" or "GUIDE") .. "  \194\183  %s"):format(stop.view.guide.name:upper())
		elseif stop then
			return (stop.kind == "way" or stop.picked) and stop.caption or stop.kind == "errand" and (stop.caption or "ON YOUR WAY")
				or stop.chosen and "HEADING TO" or stop.kind == "zone" and "WHERE NEXT" or stop.kind == "fly" and (stop.heading or "FLY THERE")
				or stop.clock and "ON A TIMER" or stop.detour == "failed" and "FAILED QUEST"
				or stop.detour == "grind" and "BETTER THAN GRINDING" or stop.detour == "class" and "FOR YOUR CLASS"
				or stop.switched == "handin" and "HAND IN FIRST" or stop.switched == "turned" and "YOU TURNED THIS WAY"
				or stop.detour and "ON YOUR WAY" or "UP NEXT"
		end
		return ""
	end

	-- The stops that get a row, the zones the rest of the log folds into, and the errands off the way,
	-- which stand in a tray of their own (Lay).
	-- db.rows steps; guide steps and zones come on top, and so does every tracked quest.
	-- With a guide, a quest after its steps is not on the way (the route puts what is before them): the card
	-- leaves it to the quest log, no row and no line counting it, and it comes onto the road when the route has
	-- it there. Only one the player tracks by hand keeps a row (stop.aside "pinned").
	local function Choose(self, all)
		local db = T.db.card
		local stops, folds, total, steps = {}, {}, 0, 0
		local tray, room = {}, MAX_ERRANDS
		local pinned, open = {}, {}
		local guided, zoned, tracked = 0, 0, 0
		local sample = all[1] ~= nil and all[1].sample
		local watching = not sample and self.manage and Watching() or nil
		local past = false       -- the guide's steps are behind: what follows is not on the road
		local words = self.filter       -- what the box asks for (lower case): only what has them, zones open
		self.hits = self.hits or {}
		wipe(self.hits)                 -- what in each stop has them (ZONE.Find), for ZONE.Shown
		for i, stop in ipairs(all) do
			local hit = words and ZONE.Find(stop, words)
			if words then self.hits[stop] = hit end
			if words and not hit then
				-- (Not what is asked for: left out, whatever it is.)
			elseif stop.kind == "zone" then
				if zoned < MAX_ZONES then
					zoned = zoned + 1
					stops[#stops + 1] = stop
				end
			elseif stop.kind == "guide" then
				past = not sample
				if guided < MAX_GUIDE then
					guided = guided + 1
					stops[#stops + 1] = stop
				end
			elseif i > 1 and stop.kind == "errand" and not stop.taken and not stop.urgent then
				-- Not taken: no stop of the road, and it takes none of the steps asked for.
				if #tray < room then tray[#tray + 1] = stop end
			else
				total = total + 1
				local held, mine = false, false
				if watching then held, mine = Logged(stop, watching) end
				local aside = past and stop.kind ~= "errand" and stop.kind ~= "fly" and not stop.chosen and not stop.detour and not stop.clock
				local kept = aside and Pinned(stop)
				stop.aside = nil
				local key, name
				if aside and not kept then
					-- Not on the way while a guide leads: the quest log's, not the card's.
					key = false
				elseif held and not mine and i > 1 and not stop.chosen and not stop.detour and not stop.clock and Grayed(stop) then
					-- Gray, and zone mode leaves those to the quest log.
					key = false
				elseif held and not mine and i > 1 and not stop.chosen and not stop.detour and not stop.clock then
					key, name = Fold(stop)
				end
				if key == false then
					-- (Left to the quest log.)
				elseif key and not kept then
					-- Its zone's line holds it: counted there, and when the zone is open, laid under it (Lay).
					local fold = folds[key]
					if not fold then
						fold = { key = key, name = name, quests = 0, aside = aside, open = (self.opened[key] or words ~= nil) or nil }
						if fold.open then fold.stops = {} end
						folds[key] = fold
						folds[#folds + 1] = fold
					end
					fold.quests = fold.quests + #stop.actions
					for _, action in ipairs(stop.actions) do
						local level = action.level
						if level and level > 0 then
							fold.low = math.min(fold.low or level, level)
							fold.high = math.max(fold.high or level, level)
						end
					end
					if fold.open then fold.stops[#fold.stops + 1] = stop end
				elseif kept or steps < db.rows or (mine and tracked < MAX_TRACKED) then
					if kept then
						if #pinned < MAX_TRACKED then
							stop.aside = "pinned"
							pinned[#pinned + 1] = stop
						end
					elseif aside then
						stop.aside = "open"
						open[#open + 1] = stop
					else
						if steps < db.rows then steps = steps + 1 else tracked = tracked + 1 end
						stops[#stops + 1] = stop
					end
				end
			end
		end
		-- What is not on the road stands together, before the zones to go to: what the player tracks,
		-- then what a click opened.
		local at = #stops + 1
		for index = #stops, 1, -1 do
			if stops[index].kind ~= "zone" then break end
			at = index
		end
		for _, list in ipairs({ pinned, open }) do
			for _, stop in ipairs(list) do
				table.insert(stops, at, stop)
				at = at + 1
			end
		end
		return stops, folds, total, tray
	end

	-- The map's numbered places (Pins.lua): for a route stop, for a guide step, and the guide's
	-- places still ahead of the steps shown.
	local function Places(self, stops)
		local byStop, byStep, ahead = {}, {}, {}
		local live = false
		for _, stop in ipairs(stops) do
			if stop.kind == "guide" and not stop.sample then live = true end
		end
		if not (live and self.manage and ns.RoutePlaces) then return byStop, byStep, ahead end
		local shown = {}
		for _, stop in ipairs(stops) do
			if stop.kind == "guide" then shown[stop.view.step.index] = true end
		end
		for _, place in ipairs(ns.RoutePlaces()) do
			if place.own then
				byStop[place.own] = place
			else
				local here = false
				for _, view in ipairs(place.views) do
					byStep[view.step.index] = byStep[view.step.index] or place
					if shown[view.step.index] then here = true end
				end
				-- (In Dungeon mode the run's places take the rows nearby quests and errands would.)
				local most = R.Running and R.Running() and MAX_AHEAD + MAX_ERRANDS - 1 or MAX_AHEAD
				if not here and not self.full and #ahead < most then ahead[#ahead + 1] = place end
			end
		end
		return byStop, byStep, ahead
	end

	-- Writes a row's distance and gives its title the room that leaves. The distance is rewritten as
	-- the player moves (card:Measure), so between fills its room only grows: a title never stands under
	-- it, and doesn't shift each time the distance gets shorter.
	local function Far(row, fresh)
		-- On the ground where it is found there is no distance to say: "Here", in the color of what is
		-- found there (a later stop), or nothing where the lead's caption says it.
		local among = row.stop.among
		-- (A zone to head for says its quests, not how far it is.)
		local said = among and (row.hereSaid and "" or "Here") or row.stop.kind ~= "zone" and W.Far(row.stop) or ""
		if not row.dial and (among or false) ~= (row.farAmong or false) then
			row.farAmong = among
			UI.Ink(row.yards, among and ns.ToneColor(among) or C.dim)
		end
		-- (Asked every frame: the same words are neither set nor measured again. Fresh, with the same words
		-- and the title's room as fresh left it at this width, neither.)
		if said == row.farSaid and (not fresh or row.farFresh == width) then return end
		row.farSaid = said
		row.yards:SetText(said)
		local wide = row.yards:GetStringWidth()
		if fresh or wide > (row.far or 0) then
			row.far = wide
			row.farFresh = fresh and width or nil
			OneLine(row.title, width - GUTTER - PAD - wide - 6)
		end
	end

	-- A row's place under the card's top and its height, set only when they change; Lay's Hide forgets them.
	local function Place(row, y, height)
		if row.placedY ~= y then
			row.placedY = y
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetPoint("TOPRIGHT", 0, -y)
		end
		if height and row.placedH ~= height then
			row.placedH = height
			row:SetHeight(height)
		end
		if not row.placed then
			row.placed = true
			row:Show()
		end
	end
	local function Unplace(row)
		row.placedY, row.placedH, row.placed = nil, nil, nil
		row:Hide()
	end

	-- The countdown's plate `y` under the top of `to`, anchored again only when that changes.
	local function Hang(plate, to, y)
		if plate.hungTo ~= to or plate.hungY ~= y then
			plate.hungTo, plate.hungY = to, y
			plate:ClearAllPoints()
			plate:SetPoint("TOPLEFT", to, "TOPLEFT", GUTTER, -y)
		end
		plate:Show()
	end

	-- A font string's words, set only when they change.
	local function Say(fs, text)
		if fs.saidText == text then return end
		fs.saidText = text
		fs:SetText(text)
	end

	-- A later stop's row at `y`. `above`: see Rail. bare: its title alone (an errand in the tray, whose
	-- title says what it is for). Returns the row's height.
	local function Stop(self, row, stop, place, y, above, ends, bare)
		row.stop = stop
		ns.CardLit.Row(row)
		local title = Describe(stop)
		local level = TitleLevel(stop, title)
		level = level ~= "" and ("  " .. level) or ""
		Far(row, true)
		Node.Show(row, stop, place, bare)
		if bare then Node.Seat(row, "bare") end
		-- An errand's line: its title and how far, centered on the line's middle with its sign (the hover lights
		-- the line evenly round them); a stop's title hangs from the top over its lines.
		if row.bare ~= (bare and true or false) then
			row.bare = bare and true or false
			row.title:ClearAllPoints()
			row.yards:ClearAllPoints()
			if bare then
				row.title:SetPoint("LEFT", row, "TOPLEFT", GUTTER, -row.seat)
				row.yards:SetPoint("RIGHT", row, "TOPRIGHT", -PAD, -row.seat)
			else
				row.title:SetPoint("TOPLEFT", GUTTER, -3)
				row.yards:SetPoint("TOPRIGHT", -PAD, -4)
			end
		end
		local lines = bare and {} or Lines(stop, false)
		local at, most = ROW_HEAD, not self.manage and 1 or R.Running() and ZONE.runLines or ROW_LINES
		-- Filtered: what matched lit, or a line saying why it is here (ZONE.Shown). An errand's line is its title.
		local shown
		shown, lines = ZONE.Shown(self, stop, title, lines, most)
		if bare then lines = {} end
		Say(row.title, shown .. level)
		if most == 1 then
			-- One line a stop: the first thing still to do there.
			local open
			for _, entry in ipairs(lines) do
				if not entry.cap and not entry.done then open = open or entry end
			end
			lines = { open }
		end
		lines = ZONE.Cut(lines, most)
		for i = 1, math.max(#row.lines, #lines) do
			local entry = lines[i]
			if entry then
				at = at + Write(row, i, entry, at, width, false)
			elseif row.lines[i] then
				Blank(row.lines[i])
			end
		end
		Node.Seat(row, bare and "bare" or at == ROW_HEAD)
		-- As tall as its lines, and as its node: a pin to its point, with what it is for over its lower
		-- right to that; an errand in the tray is its one line.
		local node = row.tagged and PIN_SEAT + PIN_TAG_Y + TAG / 2 + 1 or row.pin:IsShown() and PIN_SEAT + PIN / 2 + 1 or ZONE.row
		local height = bare and BARE_ROW or math.max(node, at + 1)
		Place(row, y, height)
		Rail(row, above, ends, height)
		return height
	end

	-- A heading at `y`; returns its height.
	-- A heading's row between kinds of rows, and its words' drop into it.
	local HEADING_ROW, HEADING_LIP = 14, 3
	local function Heading(self, at, text, y, onRail)
		local heading = self.headings[at]
		heading.used = true
		local said = ("%s|%s|%s|%s"):format(text, y, tostring(onRail), width)
		if heading.said == said then return HEADING_ROW end
		heading.said = said
		local x = onRail and GUTTER or PAD
		heading:SetText(text)
		heading:SetWidth(0)
		if heading:GetStringWidth() > width - x - PAD then heading:SetWidth(width - x - PAD) end
		heading:ClearAllPoints()
		heading:SetPoint("TOPLEFT", x, -y - HEADING_LIP)
		heading:Show()
		local from = x + math.min(heading:GetStringWidth(), width - x - PAD) + 6
		heading.rule:SetShown(from < width - PAD - 8)
		heading.rule:ClearAllPoints()
		heading.rule:SetPoint("TOPLEFT", self.body.content, "TOPLEFT", from, -y - HEADING_LIP - 5)
		heading.rule:SetPoint("TOPRIGHT", self.body.content, "TOPRIGHT", -PAD, -y - HEADING_LIP - 5)
		return HEADING_ROW
	end

	-- Where the guide's own steps begin under the lead: no words (the lead and the header say whose guide it is),
	-- a hairline across the row, the headings' own, in RULE_ROW.
	local RULE_ROW = 7
	local function Rule(self, at, y, onRail)
		local heading = self.headings[at]
		heading.used = true
		local said = ("rule|%s|%s"):format(y, tostring(onRail))
		if heading.said == said then return RULE_ROW end
		heading.said = said
		heading:SetText("")
		heading:Hide()
		heading.rule:Show()
		heading.rule:ClearAllPoints()
		heading.rule:SetPoint("TOPLEFT", self.body.content, "TOPLEFT", onRail and GUTTER or PAD, -y - RULE_ROW / 2)
		heading.rule:SetPoint("TOPRIGHT", self.body.content, "TOPRIGHT", -PAD, -y - RULE_ROW / 2)
		return RULE_ROW
	end

	-- A row stands on the card (the lead), or in the body that scrolls under it: moved, it is placed afresh.
	local function Into(row, parent)
		if row.home == parent then return end
		row.home = parent
		row:SetParent(parent)
		row.placedY = nil
	end

	-- The zones at `y` in the body, each line with its open quests right under it on a rail from its button to
	-- the last of them. RowFor: Lay's, for the rows they take. Returns the y under them.
	local function Zones(self, folds, y, RowFor)
		for i, fold in ipairs(self.folds) do
			local zone = folds[i]
			local top = y
			local said = zone and ("%s|%s|%s|%s|%d|%s|%s|%s|%s|%d"):format(tostring(zone.key), tostring(zone.name), tostring(zone.open),
				tostring(zone.aside), zone.quests, tostring(zone.low), tostring(zone.high), y, width, written.epoch) or false
			local fresh = fold.said ~= said
			if fresh then
				fold.said = said
				fold:SetShown(zone ~= nil)
			end
			if zone then
				if fresh then
					fold.key, fold.name, fold.open, fold.aside = zone.key, zone.name, zone.open, zone.aside
					fold.chip:Set(zone.open and "open" or "shut")
					fold.text:SetText(zone.aside and "Not on your way" or zone.name)
					fold.text:SetWidth(width - GUTTER - PAD)
					fold.sub:SetText(ZONE.Sub(zone))
					fold.sub:SetWidth(width - GUTTER - PAD)
					fold:ClearAllPoints()
					fold:SetPoint("TOPLEFT", 0, -y)
					fold:SetPoint("TOPRIGHT", 0, -y)
				end
				fold.top = y
				y = y + ZONE.height
				local reach
				for _, stop in ipairs(zone.stops or {}) do
					local row = RowFor(stop)
					if not row then break end
					local at = y
					y = y + Stop(self, row, stop, nil, y, nil, false, false)
					reach = at + (row.seat or row.node)
				end
				if reach then y = y + ZONE.gap end
				fold.bottom = y
				-- The group's wash runs under its quests, down to where the group ends; the rail to the last one's mark.
				if reach then
					fold:Hang(y - top - ZONE.height, { reach - top })
				else
					fold:Hang()
				end
			end
		end
		return y
	end

	-- The body at `top` on the card, `tall` high laid out: all of it where there is room, else the room the
	-- card's place leaves under `top` less `below` (what stands under it), and it scrolls. Never less than
	-- BODY_LEAST, so a card crowded to the screen's foot still shows a few lines to scroll. Returns its height.
	local BODY_LEAST = 96
	local function Body(self, top, tall, below)
		local area = self.body
		self.bodyTop = top
		if tall <= 0 then
			area:Hide()
			self:Pin()
			return 0
		end
		local room = self.room and self.room()
		local view = tall
		if room then view = math.max(math.min(tall, BODY_LEAST), math.min(tall, room - top - below)) end
		local said = ("%s|%s|%s|%s"):format(top, view, tall, width)
		if area.said ~= said then
			area.said = said
			area:ClearAllPoints()
			area:SetPoint("TOPLEFT", 0, -top)
			area:SetSize(width, view)
			area.content:SetSize(width, tall)
		end
		area:Show()
		area:Update()   -- (which sets the pinned line, Pin)
		return view
	end

	-- Lays the card out from a list of stops; returns its height.
	local function Lay(self, all)
		-- Folded, standing alone: the title bar alone, a plain rectangle with its tools, no accent line under it
		-- and nothing below. (Docked, the deck's header is the bar and the box is put away: Shown.)
		local folded = self.list ~= nil and ns.char.questsShut == true and not self.docked
		-- (What the lead says to GuideButtons.lua of its counts: none until it has laid them.)
		self.claims, self.slots = nil, nil
		self.titlebar:SetShown(not self.docked)
		self.fold:SetFoldable(self.list ~= nil)
		self.fold:Set(not folded)
		-- (Docked, the card wears none of its own header: card:Dock has it put away.)
		if not self.docked then UI.FoldLine(self, not folded) end
		if folded then
			Unplace(first)
			self.caption:Hide()
			self.pick:Hide()
			self.body:Hide()
			self.pin:Hide()
			if self.controls then self.controls:Hide() end
			if self.strip then self.strip:Hide() end
			if self.list then ns.GuideList.Hide(self) end
			timer:Hide()
			local guide
			for _, each in ipairs(all) do
				if each.kind == "guide" and not each.sample then
					guide = each
					break
				end
			end
			self.guideStop, self.full, self.stops = guide, false, {}
			Head(self, guide ~= nil, #all, all[1])
			return UI.FOLDED
		end

		local stops, folds, total, tray = Choose(self, all)
		local filtered = self.filter ~= nil
		-- (No more than there are rows for, with those the places ahead and the errands take.)
		local shown = math.min(#stops, #self.rows - MAX_AHEAD - MAX_ERRANDS)
		self.stops = stops

		local stop = stops[1]
		-- Leading with the route's own first stop: a filter may put another in the lead, or none. GuideButtons.lua's
		-- strip is for the route's (ns.CardLeads), so it stands, and the lead makes room for it, only then.
		self.leads = stop ~= nil and stop == all[1]
		-- card.dock: height GuideButtons.lua's secure strip needs under the lead's head.
		local dock = stop and not stop.sample and self.leads and self.dock or 0
		-- Only the on-screen card has self.list (GuideWindow.lua); the preview has none.
		-- (The whole guide is for following one: in zone mode there are no steps to list.)
		-- (A dungeon run is the next steps alone, in its own theme: the list waits for your guide.)
		self.full = self.list ~= nil and ns.char.guideFull == true and Following() and not G.current.run
		-- Under the card's own strip, or right under the deck's header. Docked with no header to
		-- put the pager in, it gets a line of its own over the lead.
		local top = not self.docked and STRIP + 6 or self.column and 4 or PAGER + 6
		-- The controls (the mode switch and the quest filter) first, under it; only on the on-screen card.
		local bar = self.controls
		local barTall = 0
		if bar then
			barTall = self.list ~= nil and (ZONE.controls + ((filtered and #stops == 0) and ZONE.row or 0)) or 0
			bar:SetShown(barTall > 0)
			if barTall > 0 then
				local said = ("%s|%s|%s"):format(top, barTall, width)
				if bar.said ~= said then
					bar.said = said
					bar:ClearAllPoints()
					bar:SetPoint("TOPLEFT", 0, -top)
					bar:SetPoint("TOPRIGHT", 0, -top)
					bar:SetHeight(barTall)
					self.search:SetWidth(width - PAD * 2 - ZONE.switch - 8)
					self.search.box:SetWidth(width - PAD * 2 - ZONE.switch - 8)
				end
				self.style:Refresh()
				self.search:Refresh()
				self.none:SetShown(filtered and #stops == 0)
			end
			top = top + barTall
		end
		local progress = 0
		if self.full then
			progress = ns.GuideList.Progress(self, top)
		elseif self.list then
			ns.GuideList.Hide(self)
		end
		local y = top + progress
		-- A dungeon run's banner (Run.lua; a file new to the TOC needs a restart), on the on-screen card only.
		if ns.Run and ns.Run.Banner and self.list ~= nil then y = y + ns.Run.Banner(self, y, width) end
		-- For GuideButtons.lua: where its strip stands under the box's top.
		self.dockAt = y + LEAD_HEAD

		-- The guide's main step, wherever it is on the card (a side step or a nearby stop may lead):
		-- the pager always acts on it.
		local guide
		for _, each in ipairs(stops) do
			if each.kind == "guide" and not each.sample and (not guide or (guide.side and not each.side)) then guide = each end
		end
		self.guideStop = guide
		local guided = guide ~= nil
		local byStop, byStep, ahead = Places(self, stops)
		-- The rail runs to the guide's last step shown, or without a guide to the last stop that isn't a zone.
		local last = 0
		for i, each in ipairs(stops) do
			if (guided and each.kind == "guide") or (not guided and each.kind ~= "zone") then last = i end
		end
		local railEnds = #ahead > 0 and 0 or last   -- the row the rail ends at; 0: it runs on into the places ahead

		local here, hereColor = Here(self, stop)
		Say(self.caption, here or Caption(self, stop))
		UI.Ink(self.caption, hereColor or C.dim)
		self.caption:SetShown(stop ~= nil)
		self.pick:SetShown(self.full and G.current ~= nil and stop ~= nil and not stop.urgent)
		Node.Mine(first, stop)
		if stop then
			first.stop = stop
			ns.CardLit.Row(first)
			-- What it is for: in the dial where nothing points, over the dial's lower right while the
			-- arrow has the dial (Point).
			local sign, tone = Sign(stop)
			first.tagged = sign
			if sign then first.tag:Set(sign, false, nil, tone) end
			-- (The caption says "here": the distance's place says nothing, Far.)
			first.hereSaid = here ~= nil
			if stop.among then
				-- On its ground: the emblem of what is found here, in the dial (Point shows it).
				first.here:SetTexCoord(unpack(ns.MarkPicture(ns.ToneSign(stop.among))))
				UI.Tint(first.here, ns.ToneColor(stop.among))
			elseif sign and stop.view then
				-- A guide's step: its task's mark, not the plain banner.
				first.mark:Set(sign, stop.chosen, nil, tone)
			else
				first.mark:Set(ns.StopMark(stop), stop.chosen, Count(stop), ns.StopTone(stop))
			end
			-- The dial's ring: the color of what is found here while on its ground; else lit while the
			-- waypoint arrow is up and following (Arrow.lua).
			local following = self.manage ~= nil and ns.Arrow ~= nil and ns.Arrow.Following()
			local ring = stop.among or following
			if ring ~= first.lit then
				first.lit = ring
				local face = stop.among and ns.ToneColor(stop.among) or following and C.hot or Shy.Theme.skin.metal
				UI.Tint(first.dial, face)
				Shy.Skin.WeaveTint(first.weave, face)
			end
			first.way:SetShown(self.manage ~= nil and ns.Arrow ~= nil)
			local title = Describe(stop)
			local level = TitleLevel(stop, title)
			Far(first, true)
			if self.caption.heldFor ~= width then
				self.caption.heldFor = width
				self.caption:ClearAllPoints()
				self.caption:SetPoint("TOPLEFT", first, "TOPLEFT", GUTTER, -20)
				self.caption:SetWidth(width - GUTTER - PAD)
			end
			-- The step's creatures stand as chips under the count each is killed for (GuideButtons.lua's, secure,
			-- so not the card's own): `rooms` is the room each group takes, by its task (G.TaskKey); the card
			-- says which counts it shows (self.claims) and where each one's room starts under the dock's top
			-- (self.slots). In a fight the chips can't be moved: a group stays where it stands (`stood`) and
			-- its count keeps above it. Where that can't be (the step changed, a line over them grew), the
			-- chips keep their whole ground as one block over the lines, which say in words who to look for.
			local strip = stop.view and not stop.sample and self.leads and self.rooms and ns.GuideButtons or nil
			local fight = strip ~= nil and InCombatLockdown()
			-- (In Dungeon mode the lead says all of its step: ZONE.runLines.)
			local most = R.Running() and ZONE.runLines or MAX_LINES
			local ticking = timer:Tick()
			local shown
			local function Rows(dock, rooms, stood)
				local lines = Lines(stop, true, here ~= nil, rooms)
				-- Filtered: what matched lit, or a line saying why it leads the list (ZONE.Shown).
				shown, lines = ZONE.Shown(self, stop, title, lines, most)
				lines = ZONE.Cut(lines, most)
				local at = LEAD_HEAD + dock
				-- The countdown's plate: after the stop's own lines, before its notes.
				local plate = ticking
				local claims, slots, clash = {}, {}, false
				for i = 1, math.max(#first.lines, #lines) do
					local entry = lines[i]
					local link = first.links[i]
					if plate and (not entry or entry.note) then
						plate = false
						Hang(timer, first, at + PLATE_AIR)
						at = at + timer:GetHeight() + PLATE_AIR * 2
					end
					if entry then
						local from = at
						at = at + Write(first, i, entry, at, width, true)
						if entry.url or entry.task or entry.failed or entry.objective or entry.tip then
							link = Link(i)
							link.url, link.task, link.asked, link.failed = entry.url, entry.task, entry.asked, entry.failed
							link.objective, link.tip = entry.objective, entry.tip
							ns.CardLit.Link(link)
							if link.from ~= from or link.to ~= at then
								link.from, link.to = from, at
								link:ClearAllPoints()
								link:SetPoint("TOPLEFT", GUTTER, -from)
								link:SetPoint("BOTTOMRIGHT", first, "TOPRIGHT", -PAD, -at)
							end
							link:Show()
						elseif link then
							link:Hide()
						end
						local key = entry.number and G.TaskKey(stop.view, entry.number)
						if key then claims[key] = true end
						local room = key and rooms and rooms[key]
						local was = stood and stood[key]
						if room and (was or not stood) then
							if was then
								if at - LEAD_HEAD > was + 0.5 then clash = true end
								at = math.max(at, LEAD_HEAD + was)
							end
							slots[key] = at - LEAD_HEAD
							at = at + room.tall
						end
					else
						if first.lines[i] then Blank(first.lines[i]) end
						if link then link:Hide() end
					end
				end
				for key in pairs(stood or {}) do
					if not slots[key] then clash = true end
				end
				if plate then
					Hang(timer, first, at + PLATE_AIR)
					at = at + timer:GetHeight() + PLATE_AIR
				end
				return at, claims, slots, clash
			end
			local at, claims, slots, clash = Rows(dock, strip and self.rooms, fight and strip.Stood() or nil)
			if clash then
				at, claims = Rows(math.max(dock, strip.Extent()))
				slots = {}
			end
			self.claims, self.slots, self.fought = claims, slots, fight or self.fought
			Say(first.title, shown .. (level ~= "" and ("  " .. level) or ""))
			local height = math.max(DIAL + 8, at + 2)
			-- (The lead stands on the card itself, never in the body under it.)
			Into(first, self)
			Place(first, y, height)
			Rail(first, 0, railEnds == 1 or (last <= 1 and #ahead == 0), height)
			y = y + height
			Point()
		else
			Unplace(first)
			-- No step, but a flight to count down.
			if timer:Tick() then
				Hang(timer, self, y + PLATE_AIR)
				y = y + timer:GetHeight() + PLATE_AIR * 2
			end
		end
		Head(self, guided, total, stop)

		-- The body: all from here is laid in the scroll area under the lead, from its own top (Body).
		local bodyTop = y
		y = 0

		-- Quests waiting for a click, right under the lead.
		local waiting = self.manage and ns.QuestPopups and ns.QuestPopups() or {}
		for i, notice in ipairs(self.notices) do
			local popup = waiting[i]
			notice:SetShown(popup ~= nil)
			if popup then
				notice.id, notice.offer, notice.title = popup.id, popup.offer, popup.title
				notice.sign:Set(popup.offer and "pickup" or "turnin")
				notice.text:SetText(popup.offer and ("New quest: " .. popup.title) or (popup.title .. ": click to complete"))
				notice.text:SetWidth(width - GUTTER - PAD)
				notice:ClearAllPoints()
				notice:SetPoint("TOPLEFT", 0, -y)
				notice:SetPoint("TOPRIGHT", 0, -y)
				y = y + ZONE.row
			end
		end

		local headings = 0
		for _, heading in ipairs(self.headings) do heading.used = false end
		-- The whole guide's step list, once: after the guide's rows, before what is nearby.
		local listed = false
		local function List()
			if listed or not self.full then return end
			listed = true
			y = y + ns.GuideList.Layout(self, y)
		end
		-- Rows in the card's order: a stop's i-th row, then the places ahead and the tray in the rows after them.
		-- (A row given what it showed before is left as it stands: Stop and Write set only what changed.)
		-- The first row is the lead's alone: with nothing leading (a filter that only an errand or a zone's quest
		-- matches), the body still starts at the second, or the lead would be laid in the body and stay there.
		local used = math.max(shown, 1)
		local function RowFor(_, i)
			local row
			if i then row = self.rows[i] else
				used = used + 1
				row = self.rows[used]
			end
			if row then Into(row, self.body.content) end
			return row
		end
		-- The guide's places ahead, once: where the rail runs on after its steps.
		local function Ahead()
			for i, place in ipairs(ahead) do
				local row = RowFor(place.stop)
				if not row then break end
				y = y + Stop(self, row, place.stop, place, y, 0, i == #ahead)
			end
			ahead = {}
		end
		-- The errands off the way, once, where the rail ends: a line each under their own heading.
		local trayLast = false    -- the tray is the last thing laid: what follows keeps a little off it
		local function Tray()
			if #tray > 0 and headings < #self.headings then
				headings = headings + 1
				y = y + Heading(self, headings, "ERRANDS", y, false)
			end
			for _, errand in ipairs(tray) do
				local row = RowFor(errand)
				if not row then break end
				y = y + Stop(self, row, errand, nil, y, nil, false, true)
				trayLast = true
			end
			tray = {}
		end
		-- Your own route (Plan.lua) goes first: the guide's steps then wait for it, and their heading says so.
		local routed = false
		for i = 1, shown do
			if stops[i].kind == "way" then routed = true end
		end
		for i = 2, shown do
			local after = stops[i]
			local row = RowFor(after, i)
			local prior = stops[i - 1]
			local before = prior.kind
			if i == last + 1 then
				Ahead()
				List()
				Tray()
			end
			-- Where the guide's own steps begin: a line, not their guide's name again.
			local guided = after.kind == "guide" and not after.here and (before ~= "guide" or prior.here) and not after.side
			local text = (after.kind == "zone" and before ~= "zone" and "WHERE NEXT")
				or (after.kind == "way" and before ~= "way" and before ~= "fly" and "YOUR ROUTE")
				or (after.aside and after.aside ~= prior.aside and (after.aside == "pinned" and "TRACKED BY YOU" or "NOT ON YOUR WAY"))
				or (guided and true)
				or (after.kind == "guide" and after.side and not after.here and (before ~= "guide" or prior.here or not prior.side)
					and "ALONG THE WAY")
			local onRail = i <= last
			local above = onRail and 0 or nil
			if text and headings < #self.headings then
				headings = headings + 1
				local tall = text == true and Rule(self, headings, y, onRail) or Heading(self, headings, text, y, onRail)
				y = y + tall
				if onRail then above = tall end
			end
			local place = byStop[after] or (after.kind == "guide" and byStep[after.view.step.index]) or nil
			y = y + Stop(self, row, after, place, y, above, i == railEnds)
			trayLast = false
		end
		Ahead()
		List()
		Tray()
		-- (Those headings not laid this time go; the rest stand as they were laid, or as Heading and Rule left them.)
		for _, heading in ipairs(self.headings) do
			if not heading.used and heading.said ~= false then
				heading.said = false
				heading:Hide()
				heading.rule:Hide()
			end
		end

		-- The rest of the log, a line a zone, at the body's foot; the body then takes its room, and ShyXP's strip
		-- stands under it.
		-- (The errands' marks reach their line's foot: what follows, or the card's own, keeps a little off them.)
		if trayLast then y = y + 4 end
		y = Zones(self, folds, y, RowFor)
		local strip = ns.XP.Strip(self)
		y = bodyTop + Body(self, bodyTop, y, strip and ns.XP.Height() + 4 or 6)
		for i = used + 1, #self.rows do
			local row = self.rows[i]
			row.stop = nil
			if row.placed ~= false then Unplace(row) end
			row.placed = false
		end

		-- The guide's notes (the header's button): only the strays in the log wait on you; the quests here the guide
		-- skips and the catch-up steps off the route (Guide.lua, Catchup; the map marks those) are said with them.
		local here = guided and R.offGuide and R.skipped or 0
		local held = guided and #R.Strays() or 0
		local catch = guided and #R.offered or 0
		self.notes:SetShown(held > 0 and self.list ~= nil)
		if held > 0 then
			local tip = {}
			if here + held > 0 then tip[1] = "Following your guide." end
			if catch > 0 then
				tip[#tip + 1] = ("%d earlier step%s %s still worth doing, a bit off your route. %s marked on the map.")
					:format(catch, catch == 1 and "" or "s", catch == 1 and "is" or "are", catch == 1 and "It's" or "They're")
			end
			if here > 0 then
				tip[#tip + 1] = ("%d other quest%s in this zone %s not in your guide, so the card and map hide %s and won't accept %s for you.")
					:format(here, here == 1 and "" or "s", here == 1 and "is" or "are", here == 1 and "it" or "them", here == 1 and "it" or "them")
			end
			if held > 0 then
				tip[#tip + 1] = ("%d quest%s in your log %s not in your guide. Drop %s?")
					:format(held, held == 1 and "" or "s", held == 1 and "is" or "are", held == 1 and "it" or "them")
			end
			self.notes.tip = table.concat(tip, " ")
			self.notes.count:SetText(held > 9 and "9+" or held)
			self.notes:SetWidth(PAGER + self.notes.count:GetStringWidth() + 2)
			self.notes:Rest(C.alert)
		end

		-- ShyXP's level progress
		if strip then
			if shown > 0 then y = y + 4 end
			strip.rule:SetShown(shown > 0)
			strip:ClearAllPoints()
			strip:SetPoint("TOPLEFT", 0, -y)
			strip:SetPoint("TOPRIGHT", 0, -y)
			strip:Refresh()
			strip:Show()
			y = y + ns.XP.Height() - 6
		end

		return y + 6
	end

	-- Fill the card from a list of stops (the route, or the sample). Everything is laid out whole, once: what the
	-- room the card's place leaves it (card.room) can't hold scrolls in the body under the lead (Body).
	function card:Fill(all)
		self.all = all
		local height = Lay(self, all)
		self:SetHeight(height)
		if onResize then onResize(width, height) end
		self:Lit()
	end

	-- Each row and objective line lit as it stands: held while what it stands for is open beside the map (RowLit).
	function card:Lit()
		for _, row in ipairs(self.rows) do ns.CardLit.Row(row) end
		for _, link in pairs(first.links) do ns.CardLit.Link(link) end
	end
	Shy:On("SHY_QUEST_OPENED", function() card:Lit() end)

	-- Laid again from the stops it has, for a change on the card itself (the filter, a zone opened): the on-screen
	-- card's whole fill (card.refill), which places GuideButtons.lua's strip again too.
	function card:Refill()
		if self.refill then self.refill() else self:Fill(self.all) end
	end

	-- Distances only: the player moved, the stops didn't change.
	function card:Measure()
		for _, row in ipairs(self.rows) do
			if row.stop and row:IsShown() then Far(row) end
		end
	end

	-- (The arrow comes round every frame; the timer's words change by the second and its bar slowly: asked
	-- four times a second, not a hundred.) The card made room for the plate as it stood: when the countdown
	-- ends, or its words take another line, the card is laid out again round it.
	local sinceTimer = 0
	card:SetScript("OnUpdate", Shy.Clocked("frame: card", function(_, elapsed)
		if first.stop and first:IsShown() then Point(elapsed) end
		sinceTimer = sinceTimer + (elapsed or 1)
		if sinceTimer >= 0.25 and timer:IsShown() then
			sinceTimer = 0
			local tall = timer:GetHeight()
			if not timer:Tick() or timer:GetHeight() ~= tall then card:Refill() end
		end
	end))

	ns.cards[card] = true
	return card
end

-- The on-screen box

local box, card

-- "Quest log full (40/40). Drop: X (pays 10%)."
function ns.RoomText()
	local spare = L.Spare(G.current and G.Uses or nil)[1]
	local text = ("Quest log full (%d/%d)."):format(L.held, L.most)
	if spare then text = text .. (" Drop: %s (%s)."):format(spare.entry.title, spare.why) end
	return text
end

-- Shown with stops, the XP strip, the whole guide open, or a flight or a crossing to count down.
local function Shown()
	local db = T.db.card
	local timers = ns.GuideTimers
	-- (Folded, in ShyDock's deck the box goes and the deck's header stays; alone it stays as its title bar.)
	return db.shown and not (ns.char.questsShut == true and card ~= nil and card.docked) and (#R.stops > 0 or ns.XP.StripWanted() or ns.char.guideFull == true
			or (timers ~= nil and (timers.Flying() or (timers.Sailing ~= nil and timers.Sailing() ~= nil))))
		and not (db.hideInCombat and InCombatLockdown())
end

-- "Point the way" everywhere it is offered: the arrow (Arrow.lua), or without it the game's super-track.
function ns.PointTheWay(stop)
	if ns.Arrow then ns.Arrow.ToStop(stop) else R.Go(stop) end
end
local PointTheWay = ns.PointTheWay

-- The right-click menu, in sections. First the row's own, under a heading naming what it stands for
-- (the step, the errand, the quests): the way there, done or skipped, a group for it, its quests. Then
-- "Card": where to be taken, the guide, what the card shows, the errands it adds on its own, the
-- options, hiding it. The box's own (size, lock, place) follow under "Window" (Shy.HUD). A file that
-- adds a switch registers it through ns.CardSwitch(section, write) (ShyQuest.lua): section "errands"
-- (what the route adds on its own), "suggestions" (what the card speaks up about) or "offers" ("Take
-- me to"). Section headings with nothing under them are dropped by the menu itself.

-- A glyph on a menu row's rail (UI.MenuGlyph's sheet), so each entry is known at a glance.
local function Glyph(name)
	return UI.MenuGlyph(name, C.dim)
end

-- An entry with its glyph.
local function Row(root, text, glyph, click)
	local entry = root:CreateButton(text, click)
	entry:SetIcon(Glyph(glyph))
	return entry
end

-- A quest in the log the game says needs a group: its suggested group size, else 0.
local function GroupSize(id)
	if not (id and L.Has(id)) then return 0 end
	local ok, n = pcall(C_QuestLog.GetSuggestedGroupSize, id)
	if not ok or type(n) ~= "number" or issecretvalue(n) then return 0 end
	return n
end
ns.GroupSize = GroupSize

-- Where a stop is, as its map shares it, for the pin that ends a chat line.
local function Spot(stop)
	if stop and stop.map and stop.x then return stop.map, stop.x / 10000, stop.y / 10000 end
end

-- The line that asks for help with a quest, then the pin. Alone you look for a group: "LFG [The Defias
-- Brotherhood] in Westfall". In one you look for more, as many as the quest's group still lacks: "LF2M ...".
local function HelpLine(id, title, stop)
	local link = GetQuestLink and GetQuestLink(id) or ("[" .. title .. "]")
	local zone = stop and stop.map and W.MapName(stop.map)
	local ask = "LFG "
	if IsInGroup() then
		local lacks = GroupSize(id) - GetNumGroupMembers()
		ask = lacks > 0 and ("LF%dM "):format(lacks) or "LFM "
	end
	local words = ask .. link
	if zone then words = words .. " in " .. zone end
	return words
end

-- Help with a quest: a tell menu over the chats, the usual one first (T.db.help.chat, remembered from the
-- last pick), and a group for it through ShyGroup when it is loaded. A quest the game says needs a
-- group says so under the entry. `named`: the entries name the quest (they stand among other quests');
-- else they stand under the quest's own heading or in its own submenu.
local function HelpMenu(root, id, title, stop, named)
	local tell = UI.TellMenu(root, named and ("Ask for help with " .. title) or "Ask for help",
		function() return HelpLine(id, title, stop) end, function() return Spot(stop) end,
		{ usual = T.db.help.chat, remember = function(key) T.db.help.chat = key end })
	tell:SetIcon(Glyph("help"))
	local n = GroupSize(id)
	if n > 1 and not UI.ChatLocked() then tell:SetSub(("Needs a group of %d"):format(n)) end
	if Shy.addons.Group then
		Row(root, named and ("Find a group for " .. title) or "Find a group", "group", function() ns.RecruitFor(id, title, stop) end)
	end
end

-- A quest in the log: its page, tracking, sharing, help with it, abandoning. Written into `root`: flat
-- under a row's own heading when the row stands for the one quest, or into the quest's own submenu.
-- Its page: in the Quests window beside ShyMaps' own map while that is the map you use (LogRows.lua, T:QuestPage),
-- else the game's map at its log. page: the menu is the Quests window's own, its page a click away already.
-- (stop: the route's stop it was opened from, for a quest not in your log yet. True when something opened.)
local function OpenQuest(id, objective, stop)
	if T.QuestPage and T:QuestPage(id, objective, stop) then return true end
	if not L.Has(id) then return false end
	QuestMapFrame_OpenToQuestDetails(id)
	return true
end
ns.OpenQuest = OpenQuest
local function QuestActions(root, id, title, stop, page)
	if not page then Row(root, "Open quest page", "log", function() OpenQuest(id) end) end
	if C_QuestLog.GetQuestWatchType(id) ~= nil then
		Row(root, "Stop tracking", "track", function() C_QuestLog.RemoveQuestWatch(id) end)
	else
		Row(root, "Track", "track", function() C_QuestLog.AddQuestWatch(id) end)
	end
	if C_QuestLog.IsPushableQuest(id) and IsInGroup() then
		-- The game only lets an addon share a quest out of a fight.
		local fight = InCombatLockdown()
		local share = Row(root, "Share with your group", "share", function()
			if not InCombatLockdown() then QuestUtil.ShareQuest(id) end
		end)
		share:SetEnabled(not fight)
		if fight then share:SetSub("After the fight") end
	end
	HelpMenu(root, id, title, stop, false)
	root:CreateDivider()
	Row(root, "Abandon", "abandon", function() QuestMapQuestOptions_AbandonQuest(id) end)
end

ns.QuestActions = QuestActions

local function QuestMenu(root, id, title, stop)
	local quest = Row(root, title, "log")
	QuestActions(quest, id, title, stop)
	return quest
end

-- The quests a stop is for, once each however many of its lines the stop holds (a step may both work a
-- quest and hand it in). A row that stands for one quest in the log has the quest's actions right under
-- its own heading; a row with several folds each into its own submenu, two of a chain that share a name
-- told apart by their level, and one the game says needs a group has its help lifted out to stand on
-- its own. `heading`: what the row's section is already called.
local function QuestMenus(root, stop, heading)
	local seen, named, twice = {}, {}, {}
	local quests = {}
	for _, action in ipairs(stop.actions) do
		if action.id and not seen[action.id] then
			seen[action.id] = true
			quests[#quests + 1] = action
			if named[action.title] then twice[action.title] = true end
			named[action.title] = true
		end
	end
	local one = #quests == 1 and quests[1]
	if one and one.kind ~= "pickup" and L.Has(one.id) then
		if heading ~= one.title then root:CreateSection(one.title) end
		QuestActions(root, one.id, one.title, stop)
		return
	end
	for _, action in ipairs(quests) do
		if action.kind ~= "pickup" and GroupSize(action.id) > 1 then HelpMenu(root, action.id, action.title, stop, true) end
	end
	for _, action in ipairs(quests) do
		local entry
		if action.kind == "pickup" then
			if stop.kind ~= "guide" then
				entry = Row(root, "Never suggest " .. action.title, "hide", function() ns.HideQuest(action.id, action.title) end)
			end
		elseif L.Has(action.id) then
			entry = QuestMenu(root, action.id, action.title, stop)
		elseif stop.kind ~= "guide" then
			entry = Row(root, "Open " .. action.title, "log", function() OpenQuest(action.id) end)
		end
		if entry and twice[action.title] then
			local quest = D.Quest(action.id)
			if quest and quest.level then entry:SetDetail("level " .. quest.level) end
		end
	end
end

-- The quests in the log the game says need a group, by name, each with the route's stop for it (for the
-- pin and the zone in a line asking for help).
local function GroupQuests()
	local out = {}
	for id, entry in pairs(L.entries or {}) do
		if type(id) == "number" and GroupSize(id) > 1 then
			local stop
			for _, each in ipairs(R.stops) do
				for _, action in ipairs(each.actions or {}) do
					if action.id == id and each.map then stop = stop or each end
				end
			end
			out[#out + 1] = { id = id, title = entry.title or D.Name("quests", id) or ("Quest " .. id), stop = stop }
		end
	end
	table.sort(out, function(a, b) return a.title < b.title end)
	return out
end

-- What a row's section is headed: the step's number, else what the route calls the stop.
local function Heading(stop)
	if stop.kind == "guide" then
		local number = stop.view and stop.view.number
		return number and ("Step " .. number) or "This step"
	end
	local ok, title = pcall(R.Describe, stop)
	return ok and type(title) == "string" and title or nil
end

-- Which floor a stop is led to, where the place has more than one (a hall under a mountain, a cave under a
-- hill, an upper storey): what Shy takes it for, and yours to put right. What you pick is kept for the
-- account and leads there from then on (W.Learn); "Pick it for me" forgets it.
local FLOORS = { [0] = "On the ground", "Underground", "Up a level" }
local function FloorMenu(root, stop)
	if not (stop.north and stop.continent) then return end
	local look, how = W.Floor(stop)
	if not how then return end
	local entry = Row(root, "Which floor", "info")
	-- (No floor the ground knows, over the roof of one it does: the straight line leads until you say.)
	local words = look and (FLOORS[look] or "No floor known") or "Whichever is quickest"
	entry:SetSub(how == "said" and ("You said: " .. words:lower()) or how == "guess" and ("Best guess: " .. words:lower()) or words)
	-- No "On the ground" in a city's halls. Nothing there stands on the ground above.
	for pick = W.Halls(stop) and 1 or 0, 2 do
		entry:CreateRadio(FLOORS[pick], function() return look == pick end, function() W.Learn(stop, pick) end)
	end
	if how == "said" then
		entry:CreateDivider()
		entry:CreateButton("Pick it for me", function() W.Learn(stop, nil) end)
	end
end

-- What a right-click does with an errand: it leads only when you take it. nil: not one to take (what
-- can't wait, or one you asked for or chose, whose menu has its own way back).
function ns.TakeHint(stop)
	if not (stop and stop.kind == "errand") or stop.urgent or stop.yours or R.Asked(stop.errand) then return nil end
	if stop.taken then return "Back to my route" end
	return stop.map and "Take me there" or "Do this now"
end

-- A row's menu is StopMenu then CardMenu; GuideWindow.lua's rows put their own entries over CardMenu
-- through card.manage.
local function StopMenu(root, stop)
	if not stop or stop.sample then return end
	local heading = Heading(stop)
	if heading then root:CreateSection(heading) end
	if stop.kind == "guide" then
		local index = stop.view.step.index
		Row(root, "Point the way", "point", function() PointTheWay(stop) end)
		Row(root, "This step is done", "done", function() G.MarkDone(index, true, stop.view.guide) end)
		Row(root, "Skip this step", "skip", function() G.Skip(index, stop.view.guide) end)
		-- A quest the step takes that its giver doesn't offer (an object with nothing to give opens no window, so
		-- nothing was heard of it): let go as when a giver's list leaves it out, every step of it with it.
		for _, line in ipairs(stop.view.lines or {}) do
			if line.command == "accept" and line.id and not line.done and not line.dropped and ns.NotOffered then
				Row(root, "Not offered? Skip " .. (D.Name("quests", line.id) or "it"), "skip", function() ns.NotOffered(line.id) end)
			end
		end
		Row(root, "Back a step", "back", function() G.Back() end):SetEnabled(G.CanBack())
		-- A dungeon step: ShyGroup can recruit for it, and it can be put off until you're ready.
		local dungeon = ns.Detour(G.Dungeon(index, stop.view.guide))
		if ns.CanRecruit(dungeon) then
			Row(root, "Find a group for " .. dungeon.name, "group", function() ns.Recruit(dungeon) end)
		end
		-- During a dungeon run (Run.lua), any of its steps leads back to your guide instead.
		if G.current and G.current.run and ns.Run then
			Row(root, ns.Run.BackWords(), "back", ns.Run.Stop)
		elseif dungeon then
			local low = ns.DungeonRange(dungeon)
			local level = UnitLevel("player")
			local until_ = level < low and low or level + 2
			local later = Row(root, "Put off " .. dungeon.name, "later")
			later:CreateButton("For a couple of hours", function() ns.Snooze(dungeon, "hours") end)
			later:CreateButton("Until level " .. until_, function() ns.Snooze(dungeon, "level", until_) end)
			later:CreateButton("For good: skip its quests", function() ns.Snooze(dungeon, "off") end)
		end
		for _, link in ipairs(stop.view.links or {}) do
			Row(root, "Copy the link: " .. link.text, "link", function() UI.ShowCopyBox("A link from your guide", link.url) end)
		end
		QuestMenus(root, stop, heading)
	elseif stop.kind == "fly" then
		Row(root, "Point the way", "point", function() PointTheWay(stop) end)
	elseif stop.kind == "errand" or stop.kind == "way" then
		-- An errand leads only when you take it. One you asked for has its own way back (stop.menu).
		local take = ns.TakeHint(stop)
		if take then
			Row(root, take, stop.taken and "back" or "route", function() R.Take(stop, not stop.taken) end)
		end
		-- One click puts an errand away for good; the card's Errands menu brings it back.
		if stop.kind == "errand" and R.CanHush(stop.errand) then
			Row(root, "Stop showing this", "hide", function() R.Hush(stop.errand, true) end):SetSub("Turn it back on under Errands")
		end
		if stop.map then Row(root, "Point the way", "point", function() PointTheWay(stop) end) end
		if stop.menu then stop.menu(root) end
	else
		Row(root, stop.chosen and "Remove from my route" or "Go here next", stop.chosen and "hide" or "route", function() R.Go(stop) end)
		if stop.map then Row(root, "Point the way", "point", function() PointTheWay(stop) end) end
		QuestMenus(root, stop, heading)
	end
	-- Any stop with a place can go to someone as a route of theirs.
	if stop.map and stop.x and ns.ShareMenu then ns.ShareMenu(root, stop) end
	FloorMenu(root, stop)
	root:CreateDivider()
end

-- The switches other files registered for one section (ns.CardSwitch). pcall: one file's error must
-- not break the menu. keptOnly: only those that still act without levelling help.
local function Switches(root, section, keptOnly)
	for _, switch in ipairs(ns.cardSwitches or {}) do
		if switch.section == section and (switch.kept or not keptOnly) then
			local ok, err = pcall(switch.write, root)
			if not ok then geterrorhandler()(err) end
		end
	end
end

-- The card's section: each entry says what it holds on a second line.
local function CardMenu(root)
	root:CreateSection("Card")
	Switches(root, "offers")

	-- The quests in the log that need a group: help with any of them, from any row.
	local groups = GroupQuests()
	if #groups > 0 then
		local menu = root:CreateButton("Group quests")
		menu:SetSub(#groups == 1 and groups[1].title or (#groups .. " in your log. Ask chat for help or find a group"))
		menu:SetIcon(Glyph("group"))
		for _, quest in ipairs(groups) do QuestMenu(menu, quest.id, quest.title, quest.stop) end
	end

	-- The game's quest log, on the map.
	local log = root:CreateButton("Quest log", function() ToggleQuestLog() end)
	log:SetSub("All your quests, on the map")
	log:SetIcon(Glyph("log"))

	-- At the top level the guide, pickups, zones and errands (levelling help) are this character's to take back;
	-- without them the Guide entry is left out, and Errands keeps what still acts.
	if ns.AtTop() then
		local help = root:CreateCheckbox("Leveling help", ns.Levelling, function() ns.SetTopHelp(not ns.Levelling()) end)
		help:SetSub("The guide, quests to pick up and errands")
	end
	local levelling = ns.Levelling()

	if levelling then
		-- The guide: whole or next steps, which one, your place in it, and what it leaves out here.
		local guide = root:CreateButton("Guide")
		guide:SetSub("Pick a guide, find your place, see what it skips")
		guide:SetIcon(Glyph("guide"))
		guide:CreateCheckbox("Follow a leveling guide", function() return T:QuestStyle() == "guide" end, function()
			T:SetQuestStyle(T:QuestStyle() == "guide" and "zone" or "guide")
		end)
		if T:QuestStyle() == "guide" and G.current ~= nil then
			guide:CreateCheckbox("Show the whole guide", function() return ns.char.guideFull == true end, function()
				ns.ToggleGuideWindow()
			end)
		end
		if ns.GuideList then
			guide:CreateDivider()
			ns.GuideList.Menu(guide)
		end
		if G.current and not G.finished then
			guide:CreateDivider()
			guide:CreateCheckbox("This zone's other quests too", function() return R.Extras() end, function()
				if W.map then ns.char.zones[W.map] = not R.Extras() end
				ns.Apply()
			end)
			guide:CreateButton("Quests my guide skips...", function() ns.OffGuide(true) end)
		end
	end

	-- What the card lists and shows.
	local shows = root:CreateButton("What the window shows")
	shows:SetSub("Steps listed, pickups, buttons, the arrow")
	shows:SetIcon(Glyph("shows"))
	local steps = shows:CreateButton("Steps listed")
	for count = 1, MAX_ROWS do
		steps:CreateRadio(tostring(count), function() return T.db.card.rows == count end, function()
			T.db.card.rows = count
			ns.Apply()
		end)
	end
	if levelling then
		shows:CreateCheckbox("Include quests to pick up", function() return T.db.pickups end, function()
			T.db.pickups = not T.db.pickups
			ns.Apply()
		end)
		shows:CreateCheckbox("Nearby quests before the guide step", function() return T.db.guide.nearby ~= false end, function()
			T.db.guide.nearby = T.db.guide.nearby == false
			ns.Apply()
		end)
	end
	if G.current and not G.finished then
		-- GuideButtons.lua's strip
		local buttons = shows:CreateButton("Target and use buttons")
		local function Flag(label, key)
			buttons:CreateCheckbox(label, function() return T.db.guide[key] ~= false end, function()
				T.db.guide[key] = T.db.guide[key] == false
				ns.Apply()
			end)
		end
		Flag("Show them here", "buttons")
		Flag("Mark who I target", "marks")
		Flag("Alert when a rare is up", "scan")
	end
	if ns.Arrow then
		shows:CreateCheckbox("Waypoint arrow follows my steps", function() return ns.Arrow.Following() end, function()
			ns.Arrow.Toggle()
		end)
	end
	shows:CreateCheckbox("Hide during combat", function() return T.db.card.hideInCombat end, function()
		T.db.card.hideInCombat = not T.db.card.hideInCombat
		ns.Apply()
	end)

	-- What the route adds on its own, and what the card speaks up about (registered by the files that do it).
	-- Without levelling help only the errands for the quests you have and getting back to life are left.
	local errands = root:CreateButton("Errands")
	errands:SetSub(levelling and "Stops added for you: vendors, trainers, flights"
		or "Stops added for you: your bank, the mailbox")
	errands:SetIcon(Glyph("errands"))
	errands:CreateSection("Errands")
	Switches(errands, "errands", not levelling)
	errands:CreateSection("Suggestions")
	Switches(errands, "suggestions")

	root:CreateDivider()
	Row(root, "Settings", "options", function() T:OpenOptions() end)
	Row(root, "Hide this window", "hide", function()
		T.db.card.shown = false
		ns.Apply()
		T:Print("quest window hidden, and the game's tracker is back. Turn it on again with /shy quest window.")
	end)
end

local function RowMenu(root, row)
	StopMenu(root, row.stop)
	CardMenu(root)
end

-- For GuideButtons.lua: its secure buttons can't be the card's children, so it needs the card's box,
-- whether it is shown, and room under the lead's head (card.dock). CARD_HEAD is how far under the
-- box's top that room starts, kept current by every fill; CARD_DOCK_LEFT is where it starts across.
ns.CARD_WIDTH, ns.CARD_PAD, ns.CARD_HEAD, ns.CARD_DOCK_LEFT = WIDTH, PAD, STRIP + 6 + LEAD_HEAD, GUTTER
function ns.CardBox() return box, box ~= nil and Shown() end
-- Whether the on-screen card leads with the route's first stop (not another a filter put there).
function ns.CardLeads() return card ~= nil and card.leads ~= false end

function ns.CardWidth() return card and card:GetWidth() or WIDTH end

-- (laid: the card has just laid itself out, at a new width: only what follows a fill.)
local function Fill(laid)
	if not laid then card:Fill(R.stops) end
	ns.CARD_HEAD = card.dockAt
	-- Folded away it is its header alone: nothing to size, so no handles to size it by.
	if box then Shy.HUD.Folded(box, ns.char.questsShut == true and not card.docked) end
	-- GuideButtons.lua's strip is placed by hand: it goes where the card now has room for it.
	local buttons = ns.GuideButtons
	if buttons and buttons.Stand then buttons.Stand() end
end

-- height: the strip's block under the lead's head. rooms: what each group of chips takes under its count on the
-- lead, by its task ({ tall, names }; `said` is all of them as one text, to tell a change by). A card that was
-- laid in a fight, round chips that could not be moved (card.fought), is laid again whatever these say.
function ns.SetCardDock(height, rooms, said)
	if not card or (card.dock == height and card.roomsSaid == said and not card.fought) then return end
	card.dock, card.rooms, card.roomsSaid, card.fought = height, rooms, said, nil
	Fill()
end

-- For GuideButtons.lua: the counts the lead shows, by their tasks (G.TaskKey), and where the room under each one
-- starts, under the strip's top.
function ns.CardClaims() return card and card.claims or nil end
function ns.CardSlots() return card and card.slots or nil end

-- The card folded away (ns.char.questsShut), or open again.
function ns.CollapseQuests(shut)
	ns.char.questsShut = shut and true or false
	ns.Apply()
end

function ns.ApplyCard()
	if not box then return end
	Fill()
	Shy.HUD.Update(box)
end

function ns.SetupCard()
	-- The card's size is yours: a side sets how wide it is, the foot (or the top) how tall it may get, and what
	-- it can't hold then scrolls under the lead (card.room, Body). It flows; its scale is left to its menu. Both
	-- are kept with its place (the box's entry, as w and h, so "Reset size" gives them up): w its width standing
	-- alone, h the most it reaches (none: as tall as its quests need, down to what its place leaves it).
	-- In ShyDock's deck the column says how wide it is, and it is held by its foot alone.
	local SIZE = { least = 230, most = 520, short = 120, slack = 6, past = 5, foot = { "BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT" } }
	local given          -- the width its place gives it (ShyDock's column), while it gives one
	local shaping        -- a handle is dragged: the size it had as it was pressed (w, h), the one asked (wide, tall)
	local worn = false   -- the height it may reach, as it was last laid out for
	local function Kept()
		local hud = Shy.core and Shy.core.db and Shy.core.db.hud
		return hud and hud[box.id]
	end
	-- Its width is its own: no place says it. (A deck with no column to go by is as wide as the card was made.)
	local function Free()
		return not given and not card.docked
	end
	local function Wide()
		if not Free() then return given or WIDTH end
		local kept = Kept()
		return shaping and shaping.wide or kept and kept.w or WIDTH
	end
	-- (shaping.tall false: none, while a drag asks how tall the card is by itself.)
	local function Most()
		if shaping and shaping.tall ~= nil then return shaping.tall or nil end
		local kept = Kept()
		return kept and kept.h or nil
	end
	-- The size it should have, put on: laid out again only when it changed.
	local function Wear()
		if not card then return end
		local wide, most = Wide(), Most()
		local fit = math.abs(card:GetWidth() - wide) >= 0.5
		if not fit and most == worn then return end
		worn = most
		if fit then card:Fit(wide) end
		Fill(fit)
	end
	-- A handle dragged (Shy.HUD.Grip's shape): so much wider and taller than it was when pressed.
	local function Reshape(wider, taller, phase, point)
		if phase == "start" then
			shaping = { w = card:GetWidth(), h = card:GetHeight() }
			-- (In a deck its place is the deck's, which stacks again as it changes: nothing of its own to hold still.)
			if not card.docked then shaping.hold = Shy.HUD.Hold(box, point) end
		end
		local s = shaping
		if not s then return end
		-- (Whole units: the card's lines are laid by them.)
		if wider and Free() then s.wide = math.floor(math.max(SIZE.least, math.min(SIZE.most, s.w + wider)) + 0.5) end
		if taller then s.tall = math.floor(math.max(SIZE.short, s.h + taller) + 0.5) end
		Wear()
		if phase == "stop" then
			local kept = Kept()
			local wide = s.wide or kept and kept.w or WIDTH
			-- A height is kept only where it cuts the card short. Let go past what its quests need, or its place has
			-- room for (a corner dragged to make it wider goes a little up or down too), it is as tall as they need
			-- again: laid out once with none, to see how tall that is.
			local tall = kept and kept.h or nil
			if s.tall then
				tall, s.tall = s.tall, false
				Wear()
				if tall >= card:GetHeight() - SIZE.slack then tall = nil end
			end
			if tall or math.abs(wide - WIDTH) >= 0.5 then
				kept = Shy.HUD.Act.Keep(box)
				kept.w, kept.h = wide, tall
			elseif kept then
				kept.w, kept.h = nil, nil
			end
			shaping = nil
			Wear()
		end
		if s.hold then s.hold(phase == "stop") end
	end

	box = Shy.HUD.Create({
		id = "shyquest",
		title = "ShyQuest: quests",
		width = WIDTH,
		height = 120,
		-- Under the minimap, where the game's tracker stands
		point = { "TOPRIGHT", "TOPRIGHT", -40, -230 },
		shown = Shown,
		-- Its options' "Show the quest window".
		switch = {
			get = function() return T.db.card.shown ~= false end,
			set = function(on)
				T.db.card.shown = on
				ns.Apply()
				if ns.RefreshOptions then ns.RefreshOptions() end
			end,
			hint = "Your next step and your quests",
		},
		hang = true,   -- grows downward, so the heading stays put
		-- ShyDock's deck tab: the card is the quests, and this folds it away, or opens it again.
		toggle = {
			label = "Quests",
			caret = true,
			tip = ns.QUESTS_TIP,
			onText = "Fold the quests away",
			offText = "Open the quests",
			get = function() return ns.char.questsShut ~= true end,
			set = function(on) ns.CollapseQuests(not on) end,
		},
		-- ShyDock's column says how wide it is while it stands in it (own: no longer; it wears its own again).
		fit = function(_, w, own)
			given = not own and w or nil
			Wear()
		end,
		-- In ShyDock's deck the column draws the panel, so the card's own is hidden; the pager
		-- moves into the deck's header.
		docked = function(_, on)
			local dock = Shy.addons.Dock
			if on and dock and dock.DeckHeader then
				card:Dock(true, dock:DeckHeader())
			else
				card:Dock(on)
			end
			Wear()
			ns.CARD_HEAD = card.dockAt or ns.CARD_HEAD
			-- Its handles: all round standing alone, its foot's in a deck.
			local grip = Shy.HUD.Grip and Shy.HUD.Grip(box)
			if grip then grip:Follow() end
		end,
	})
	-- The card keeps watch while the HUD is faded: the next step stays readable.
	local immersion = Shy.Immersion
	if immersion and immersion.Watch then immersion.Watch("quest", box) end
	-- The XP strip drags and right-clicks like a row; Shift-click shares, as in ShyXP.
	ns.XP.onStrip = function(owner, strip)
		if owner ~= card then return end
		Shy.HUD.Manage(box, strip, function(root) RowMenu(root, strip) end)
		strip:HookScript("OnMouseUp", function(_, button)
			if button == "LeftButton" and IsShiftKeyDown() and not Shy.HUD.WasDragged(box) then ns.XP.Share() end
		end)
	end
	card = ns.CreateCard(box, function(w, h) Shy.HUD.Resize(box, w, h) end)
	card:SetPoint("TOPLEFT")
	card.refill = Fill
	-- card.manage(frame, menu): make a child frame drag the box and open the card's menu.
	card.wasDragged = function() return Shy.HUD.WasDragged(box) end
	card.manage = function(frame, menu)
		Shy.HUD.Manage(box, frame, function(root)
			if menu then menu(root) else StopMenu(root, card.first.stop) end
			CardMenu(root)
		end)
	end
	card.manage(card.titlebar)
	if ns.GuideList then ns.GuideList.Create(card) end
	-- The height its place leaves the card: ShyDock's column says how much; standing alone, down
	-- to a little above the screen's foot.
	-- No taller than you made it (Most).
	card.room = function()
		local dock = Shy.addons.Dock
		local room = card.docked and dock and dock.DeckRoom and dock:DeckRoom(box)
		if not room then
			local top = box:GetTop()
			room = top and math.max(240, top - 60) or nil
		end
		local most = Most()
		if most then room = room and math.min(room, most) or most end
		return room
	end
	Wear()
	-- Held by its foot's corners and every side (the top's corners stay small: the header's tools stand there),
	-- a side a little past its edge, where nothing else is clicked.
	if Shy.HUD.Grip then
		Shy.HUD.Grip(box, {
			over = card, shape = Reshape, corners = "foot", past = SIZE.past,
			points = function() return card.docked and SIZE.foot or nil end,
			tip = function() return card.docked and "Drag to make your quests taller or shorter." or "Drag to make your quests wider or taller." end,
		})
		-- Placed again (a reset, another layout, "Reset size"): the size kept for it now.
		hooksecurefunc(Shy.HUD, "Apply", function(placed)
			if placed == box then Wear() end
		end)
	end

	Shy.HUD.Manage(box, card, function(root) RowMenu(root, card.first) end)
	for _, link in pairs(card.first.links) do card.manage(link) end
	card.manage(card.back)
	card.manage(card.skip)
	card.manage(card.steps)
	card.manage(card.find)
	card.manage(card.pick)
	card.manage(card.first.way)
	for _, fold in ipairs(card.folds) do card.manage(fold) end
	for _, notice in ipairs(card.notices) do card.manage(notice) end
	for _, row in ipairs(card.rows) do
		Shy.HUD.Manage(box, row, function(root) RowMenu(root, row) end)
		row:SetScript("OnEnter", function(self)
			self.over = true
			ns.CardLit.Row(self)
			-- CardHover.lua if loaded and it has a form for the stop, else Tips.lua's lines.
			if self.stop and not (ns.CardHover and ns.CardHover.Show(self, self.stop, card)) then Tips.ShowStop(self, self.stop) end
			-- Pins.lua draws the route to this row's stop on the open world map.
			local from = debugprofilestop()
			if self.stop and ns.RevealWay then ns.RevealWay(self.stop) end
			-- An errand whose click must be the game's own lays a button of its own over the row (Spec.lua).
			if self.stop and self.stop.over then self.stop.over(self) end
			Shy.Clock("card: a row's way lit on the map, its own button laid"):Lap(debugprofilestop() - from)
		end)
		row:SetScript("OnLeave", function(self)
			self.over = false
			ns.CardLit.Row(self)
			if ns.CardHover then ns.CardHover.Hide(self) end
			if ns.RevealWay then ns.RevealWay(nil) end
		end)
		-- A click on a quest in your log opens the map with its page beside it, flown to its ground (ns.OpenQuest:
		-- the Quests window's page, T:QuestPage); on a stop with an objective of its own, to that objective's ground.
		-- Else it toggles the pin on the row's hover (CardHover.Pin); a stop with no hover (a zone) is headed for
		-- instead. An errand with a click of its own keeps it. With the chat box open, a Shift-click writes the
		-- stop's quest into it.
		row:HookScript("OnMouseUp", function(self, button)
			local stop = self.stop
			if button ~= "LeftButton" or not stop or Shy.HUD.WasDragged(box) then return end
			local quest = stop.actions[1] and L.Has(stop.actions[1].id) and stop.actions[1].id
			local opens = ns.OpensQuest(stop)
			if quest and ChatFrameUtil.TryInsertQuestLinkForQuestID(quest) then
				return
			elseif opens and ns.OpenQuest and ns.OpenQuest(opens, stop.kind == "goal" and stop.objective or nil, stop) then
				return
			elseif stop.kind == "errand" and stop.click then
				stop.click()
			elseif not (ns.CardHover and ns.CardHover.Pin(self, stop, card)) then
				R.Go(stop)
			end
		end)
	end

	-- A quest's count moved and the route did not (a kill, a drop that is not the last). The rows are
	-- written again from the log; the stops are not chosen again.
	-- (Once a frame however many ask: a kill's count, its XP and its loot come in the same frame.)
	function ns.Recount()
		if ns.recountSoon then return end
		ns.recountSoon = true
		C_Timer.After(0, function()
			ns.recountSoon = false
			for card in pairs(ns.cards) do
				if card.all then card:Fill(card.all) end
			end
		end)
	end

	ns.OnRoute(function(rebuilt, measuredOrChanges)
		if rebuilt then
			local tracked = TrackedText()
			if measuredOrChanges and measuredOrChanges.same and tracked == card.tracked then
				card:Measure()
			else
				card.tracked = tracked
				Fill()
			end
			Shy.HUD.Update(box)
		elseif measuredOrChanges ~= false then
			card:Measure()
		end
	end, true)

	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function() Shy.HUD.Update(box) end)
end

-- The options preview: the live route if there is one, else the sample.
function ns.FillPreview(preview)
	preview:Fill(#R.stops > 0 and R.stops or Sample())
end
