-- The map's quest log (QuestScrollFrame), tied to the route and the map beside it:
--
--   the order          each zone's quests in the order the route takes them, where the game lists them
--                      by level and offers no other order.
--   a quest's mark     where the game stands its marker button, which it only does while the map's
--                      "Show Quest Objectives" is on: the quest's mark as the card and the map have it.
--                      The number of its place on the route where it has one (Pins.lua, ns.RoutePlaces),
--                      else a "?" to hand in or the emblem of what it asks for next; lit while it leads.
--   an objective       the emblem of its kind where the line's dash was.
--   under the mouse    a row, its mark or one objective lights that ground on the open map, as a pin does,
--                      and the row keeps its own light wherever on it the mouse is.
--   a click            on a mark or an objective keeps that light, with the note at the top of the map,
--                      and turns the map to where it is; a second click lets go. A right click on a mark
--                      heads there first, as a click on the card's row does. A click on the row opens the
--                      quest's page as ever, and the quest stays lit for as long as the page is open.
--
-- No field is written on a Blizzard frame or table: what is drawn is our own frames on theirs, kept in
-- weak tables, and every hook is a post-hook. What is touched of the game's: an objective line's dash
-- (its alpha) and words (their color while the mouse is on them), a row's own light (shown and hidden),
-- and, for the order, a row's one anchor (see "The order").
--
-- The game shows no Lua errors, so everything the game calls here runs under Safe: a failure is said
-- once in chat and kept for the report.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, Tips = ns.Data, ns.World, ns.Log, ns.Route, ns.Tips
local C = Shy.UI.colors

local Rows = {}
ns.LogRows = Rows

local MARK = 20                        -- the game's marker button, which stands 6 in and 4 down a row
local MARK_X, MARK_Y = 6, -4
local EMBLEM = 16                      -- an objective's emblem: its picture's cell (the emblem fills two thirds of it)
local EMBLEM_X = 6                     -- its middle, left of where the line's words begin
local LIT = 0.45                       -- a lit emblem: this far from its color toward white
local AFTER, LAST = 1000, 100000       -- a quest's turn: after the numbered places, and with no turn at all

local marks = setmetatable({}, { __mode = "k" })     -- row -> our mark
local hits = setmetatable({}, { __mode = "k" })      -- objective line -> our button over it
local left = setmetatable({}, { __mode = "k" })      -- rows with our leave hook
-- What a click keeps lit on the map: { id, objective (nil: the whole quest), key (its stop's), page (the
-- quest's page keeps it, and lets go when it closes) }.
local kept
local lighter                          -- the frame whose hover lights the map now
local turning                          -- the map is being turned for an open page (PageShown)
local failed                           -- the last error, for the report

local function On()
	return T.db.logMarks ~= false
end

-- fn as something the game can call: an error is said once and kept, never lost.
local function Safe(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if ok then return end
		turning = nil
		if failed ~= err then
			failed = err
			T:Print("the quest log's marks hit an error. |cff888888/shyquest rows|r has the details.")
		end
	end
end

-- A quest as a stop

-- Where a finished quest is handed in: the nearest of those who take it, as { map, x, y, who }.
local function Ender(id)
	local quest = D.Quest(id)
	local best, least
	for _, token in ipairs(quest and quest.ends or {}) do
		local thing = (token.kind == "n" or token.kind == "o") and D.Thing(token.kind, token.id)
		if thing and (token.kind == "o" or L.Friendly(thing)) then
			local map, x, y, yards = W.Nearest(thing.places)
			if map and (not best or (yards and (not least or yards < least))) then
				best, least = { map = map, x = x, y = y, who = thing.name }, yards or least
			end
		end
	end
	return best
end

-- A quest of the log as a stop the map can light and name (Pins.lua, ns.LightQuest): what is left of it,
-- or its one `objective`; a finished quest is where it is handed in.
local function StopOf(id, objective)
	local entry = L.entries[id]
	if not entry then return nil end
	if entry.complete then
		local at = Ender(id)
		return { log = id, kind = "turnin", key = "log" .. id .. ":in", who = at and at.who or entry.title,
			places = at and { at } or nil, exact = true, how = "gives",
			actions = { { kind = "turnin", id = id, title = entry.title, level = entry.level } } }
	end
	return { log = id, kind = "goal", key = "log" .. id .. ":" .. (objective or 0), who = entry.title, objective = objective,
		actions = { { kind = "goal", id = id, title = entry.title, level = entry.level } } }
end

-- The map to turn to for a stop: none while the shown map has a place of it, else its nearest place's.
local function MapOf(stop)
	-- (The map shown by whatever draws it: the game, or ShyMaps' view.)
	local shown = Shy.Maps.ShownMap()
	local best, least
	for _, point in ipairs(stop.places or (R.Where(stop.log, stop.objective))) do
		if point.map == shown then return nil end
		local yards = W.Distance(point.map, point.x, point.y)
		if not best or (yards and (not least or yards < least)) then best, least = point.map, yards or least end
	end
	if not best then
		-- Nothing in the data: the map the game has for the quest.
		local map = GetQuestUiMapID(stop.log)
		if map and map ~= 0 and map ~= shown then best = map end
	end
	return best
end

-- The route's own stop for a quest (not a guide's step), if it has one.
local function RouteStop(id)
	for _, stop in ipairs(R.stops) do
		if stop.kind == "goal" or stop.kind == "turnin" or stop.kind == "pickup" then
			for _, action in ipairs(stop.actions) do
				if action.id == id then return stop end
			end
		end
	end
end

-- The numbered place of the route a quest is next done at, if it has one.
local function PlaceOf(id)
	for _, place in ipairs(ns.RoutePlaces and ns.RoutePlaces() or {}) do
		if place.own then
			for _, action in ipairs(place.own.actions or {}) do
				if action.id == id and action.kind ~= "pickup" then return place end
			end
		else
			for _, view in ipairs(place.views) do
				for _, action in ipairs(view.actions) do
					if action.id == id and action.kind ~= "pickup" and not action.done then return place end
				end
			end
		end
	end
end

-- The quests of the stop that leads.
local function Leading()
	local ids = {}
	local stop = R.Lead()
	for _, action in ipairs(stop and (stop.view and stop.view.actions or stop.actions) or {}) do
		if action.kind ~= "pickup" and not action.done then ids[action.id] = true end
	end
	return ids
end

-- The order
-- The game lists a zone's quests by level and has no setting for it. After it has laid the list out,
-- the rows under each zone's heading trade places among themselves: by their turn on the route (a
-- numbered place's number, then the route's other stops in their order), the rest as the game had them.
-- Only a row's one anchor is set, at the places the game itself gave that zone's rows (their heights
-- differ, so each stands under the one before by the game's own gap); its objectives and marker hang
-- from the row and go with it. The next layout is the game's again, and this runs after it. Switched
-- off, the same code stands the rows as the game had them.

local turns = {}                       -- quest -> its turn when the list was last put in order
local gap                              -- between two quests' rows, as the game lays them

local function Sorted()
	return On() and T.db.logSort ~= false
end

local function Turns()
	local out = {}
	local function Take(actions, turn)
		for _, action in ipairs(actions or {}) do
			if action.kind ~= "pickup" and not action.done and not out[action.id] then out[action.id] = turn end
		end
	end
	for _, place in ipairs(ns.RoutePlaces and ns.RoutePlaces() or {}) do
		if place.own then
			Take(place.own.actions, place.number)
		else
			for _, view in ipairs(place.views) do Take(view.actions, place.number) end
		end
	end
	for index, stop in ipairs(R.stops) do
		if stop.kind == "goal" or stop.kind == "turnin" or stop.kind == "pickup" then
			for _, action in ipairs(stop.actions) do
				out[action.id] = out[action.id] or (AFTER + index)
			end
		end
	end
	return out
end

-- One zone's rows, rows[from] to rows[to] as the game listed them.
--   fresh: the game has just stood them, so the gap between two is measured.
local function Stand(rows, from, to, fresh)
	local at, top = {}, nil
	for i = from, to do
		local row = rows[i]
		if InCombatLockdown() and row:IsProtected() then return end
		local point, anchor, toPoint, x, y = row:GetPoint(1)
		if not (point and y) then return end
		at[row] = { point, anchor, toPoint, x, y }
		if not top or y > top then top = y end
	end
	if fresh then gap = at[rows[from]][5] - rows[from]:GetHeight() - at[rows[from + 1]][5] end
	if not gap then return end
	local zone = {}
	for i = from, to do zone[#zone + 1] = rows[i] end
	table.sort(zone, function(a, b)
		local ta, tb = turns[a.questID] or LAST, turns[b.questID] or LAST
		if ta ~= tb then return ta < tb end
		return a.layoutIndex < b.layoutIndex
	end)
	local y = top
	for _, row in ipairs(zone) do
		local was = at[row]
		if math.abs(was[5] - y) > 0.01 then
			row:ClearAllPoints()
			row:SetPoint(was[1], was[2], was[3], was[4], y)
		end
		y = y - row:GetHeight() - gap
	end
end

local function Sort(fresh)
	local scroll = QuestScrollFrame
	local rows = {}
	for row in scroll.titleFramePool:EnumerateActive() do
		if row.layoutIndex and row.questID then rows[#rows + 1] = row end
	end
	if #rows < 2 then return end
	table.sort(rows, function(a, b) return a.layoutIndex < b.layoutIndex end)
	if not Sorted() then
		wipe(turns)
	elseif not (scroll:IsMouseOver() and next(turns)) then
		-- (While the mouse is on the list the order holds: nothing moves from under it.)
		turns = Turns()
	end
	-- The rows of one zone follow one another in the game's layout; a heading comes between two zones.
	local from = 1
	for i = 1, #rows do
		if i == #rows or rows[i + 1].layoutIndex ~= rows[i].layoutIndex + 1 then
			if i > from then Stand(rows, from, i, fresh) end
			from = i + 1
		end
	end
end

-- What is kept

-- Whether what a click kept is still what the map keeps (its note, or a pin, may have been clicked since).
local function Holding()
	return kept ~= nil and ns.KeptQuest() == kept.key
end

-- Keeps a quest (or one objective of it) lit on the map; nil lets go.
--   page: its page in the log keeps it. still: the map stays as it is.
local function Keep(id, objective, page, still)
	local stop = id and StopOf(id, objective)
	if not stop then
		kept = nil
		ns.KeepQuest(nil)
		return
	end
	local same = ns.KeptQuest() == stop.key
	kept = { id = id, objective = objective, key = stop.key, page = page or nil }
	local map = not still and MapOf(stop)
	if map and not InCombatLockdown() then OpenWorldMap(map) end
	if not same then ns.KeepQuest(stop) end
end

-- After the route was built again: a kept quest that left the log is let go of, a kept objective that
-- is finished gives way to the rest of its quest, and a quest now ready is where it is handed in.
local function Settle()
	if not Holding() then return end
	local id, objective = kept.id, kept.objective
	if not L.entries[id] then
		Keep(nil)
		return
	end
	local goal = objective and L.Goals(id)[objective]
	if objective and not (goal and not goal.finished) then objective = nil end
	if StopOf(id, objective).key ~= kept.key then Keep(id, objective, kept.page, true) end
end

-- Under the mouse

local function Light(frame, id, objective)
	local stop = StopOf(id, objective)
	if not stop then return end
	lighter = frame
	ns.LightQuest(stop)
end

local function Unlight(frame)
	if frame and lighter ~= frame then return end
	lighter = nil
	ns.LightQuest(nil)
end

local function RowOf(id)
	for row in QuestScrollFrame.titleFramePool:EnumerateActive() do
		if row.questID == id then return row end
	end
end

-- The row's own light. The game puts it out when the mouse leaves the row, which it does for a mark
-- or an objective of ours on that row: there it is kept on.
local function Glow(frame, on)
	local row = frame.glows
	if on then row = RowOf(frame.id) end
	frame.glows = on and row or nil
	local glow = row and row.HighlightTexture
	if glow then glow:SetShown(on) end
end

-- Shows `lines` beside a quest's row (beside `frame` where the row can't be found).
local function Say(frame, lines, hints)
	if T.db.tips == false or #lines == 0 then return end
	frame.said = RowOf(frame.id) or frame
	Tips.Open(frame.said, lines, { side = "RIGHT", hints = hints })
end

local function Hush(frame)
	if frame.said then Tips.Close(frame.said) end
	frame.said = nil
end

-- A quest's mark

local function MarkEnter(self)
	self:SetHovered(true)
	Glow(self, true)
	Light(self, self.id)
	local lines = Tips.Lines()
	Tips.Quest(lines, self.id, true)
	local held = Holding() and kept.id == self.id and not kept.objective
	local stop = RouteStop(self.id)
	Say(self, lines, { { "left", held and "Hide where to look" or "Show where to look" },
		{ "right", stop and stop.chosen and "Let the route choose" or "Head here first" } })
end

local function MarkLeave(self)
	self:SetHovered(false)
	Glow(self, false)
	Hush(self)
	Unlight(self)
end

-- A right click: first on the route, as a click on its row of the card; a second lets the route choose.
local function Head(id)
	local stop = RouteStop(id)
	if stop then
		R.Go(stop)
	else
		-- A quest the guide's steps cover: the game's own arrow.
		Shy.Waypoint.Quest(Shy.Waypoint.QuestID() == id and 0 or id)
	end
end

local function MarkClick(self, button)
	if not self.id then return end
	if button == "LeftButton" then
		if Holding() and kept.id == self.id and not kept.objective then Keep(nil) else Keep(self.id) end
	elseif button == "RightButton" then
		Head(self.id)
	else
		return
	end
	if self:IsMouseMotionFocus() then MarkEnter(self) end
end

local function NewMark(row)
	local mark = ns.CreateMark(row, MARK, "small")
	mark:SetPoint("TOPLEFT", row, "TOPLEFT", MARK_X, MARK_Y)
	mark:SetMouseMotionEnabled(true)
	mark:SetMouseClickEnabled(true)
	mark:SetScript("OnEnter", Safe(MarkEnter))
	mark:SetScript("OnLeave", Safe(MarkLeave))
	mark:SetScript("OnMouseUp", Safe(MarkClick))
	marks[row] = mark
	return mark
end

-- show: the row gets our mark (the game shows none of its own). leading: from Leading.
local function PaintRow(row, show, leading)
	local id = row.questID
	local entry = show and id and L.entries[id]
	local mark = marks[row]
	if not entry then
		if mark then mark:Hide() end
		return
	end
	mark = mark or NewMark(row)
	mark.id = id
	local place = PlaceOf(id)
	if place then
		mark:Set("step", place.lit, place.number)
	elseif entry.complete then
		mark:Set("turnin", leading[id])
	else
		mark:Set("goal", leading[id], nil, ns.QuestKind(id))
	end
	mark:SetPicked(Holding() and kept.id == id)
	mark:Show()
end

-- An objective's line

-- A line's words with the numbers out: the game may have counted on since the log was last read.
local function Blank(text)
	return (text:gsub("%d+", "#"))
end

-- Which objective of its quest a line shows, by its words. nil for a line that is none (money to pay).
local function IndexOf(id, text)
	if not text or text == "" then return nil end
	local want = Blank(text)
	for index, goal in ipairs(L.Goals(id)) do
		if goal.text and Blank(goal.text) == want then return index end
	end
end

-- The emblem in its kind's color, lighter under the mouse or while kept; a finished quest's line wears
-- the gold "?".
local function Ink(hit)
	local held = Holding() and kept.id == hit.id and (kept.objective == nil or kept.objective == hit.index)
	local color = hit.done and ns.MARK.gold or ns.ToneColor(hit.kind)
	local by = (hit.over or held) and LIT or 0
	hit.emblem:SetTexCoord(unpack(ns.MarkPicture(hit.done and "?" or ns.ToneSign(hit.kind))))
	hit.emblem:SetVertexColor(color[1] + (1 - color[1]) * by, color[2] + (1 - color[2]) * by, color[3] + (1 - color[3]) * by)
	-- A line that can be clicked is a button under the mouse: a pane in the accent with a bar at its left,
	-- and while kept the bar stays, so the line reads as the one the map is showing.
	local accent = Shy.Theme.Accent
	hit.back:SetShown(hit.over or held)
	hit.bar:SetShown(hit.over or held)
	Shy.UI.Tint(hit.back, accent, hit.over and 0.18 or 0.10)
	Shy.UI.Tint(hit.bar, accent, held and 1 or 0.7)
end

local function LineEnter(self)
	self.over = true
	Ink(self)
	Glow(self, true)
	-- Its words bright, as the row's are under the mouse; the color they had comes back on leaving.
	local text = self:GetParent().Text
	if not self.was then
		self.was = { text:GetTextColor() }
		text:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
	Light(self, self.id, self.index)
	local lines = Tips.Lines()
	if self.index then Tips.Goal(lines, self.id, self.index) else Tips.Quest(lines, self.id, true) end
	local held = Holding() and kept.id == self.id and kept.objective == self.index
	Say(self, lines, { { "left", held and "Hide where to look" or "Show where to look" }, { "right", "Quest options" } })
end

local function LineLeave(self)
	self.over = false
	Ink(self)
	Glow(self, false)
	if self.was then
		self:GetParent().Text:SetTextColor(self.was[1], self.was[2], self.was[3])
		self.was = nil
	end
	Hush(self)
	Unlight(self)
end

local function LineClick(self, button)
	if not self.id then return end
	if button == "RightButton" then
		-- The row's own menu: the line lies over it.
		local row = RowOf(self.id)
		if row then row:Click("RightButton") end
		return
	end
	if Holding() and kept.id == self.id and kept.objective == self.index then Keep(nil) else Keep(self.id, self.index) end
	if self:IsMouseMotionFocus() then LineEnter(self) end
end

local function NewHit(line)
	local hit = CreateFrame("Button", nil, line)
	hit:SetAllPoints(line)
	hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local x = EMBLEM_X + EMBLEM / 2 + 4
	hit.back = hit:CreateTexture(nil, "BACKGROUND")
	hit.back:SetColorTexture(1, 1, 1, 1)
	hit.back:SetPoint("TOPLEFT", hit, "TOPLEFT", -x, 2)
	hit.back:SetPoint("BOTTOMRIGHT", hit, "BOTTOMRIGHT", 4, -2)
	hit.bar = hit:CreateTexture(nil, "BORDER")
	hit.bar:SetColorTexture(1, 1, 1, 1)
	hit.bar:SetWidth(2)
	hit.bar:SetPoint("TOPLEFT", hit.back, "TOPLEFT")
	hit.bar:SetPoint("BOTTOMLEFT", hit.back, "BOTTOMLEFT")
	hit.emblem = hit:CreateTexture(nil, "ARTWORK")
	hit.emblem:SetSize(EMBLEM, EMBLEM)
	hit.emblem:SetTexture(ns.MARKS_SMALL)
	hit:SetScript("OnEnter", Safe(LineEnter))
	hit:SetScript("OnLeave", Safe(LineLeave))
	hit:SetScript("OnClick", Safe(LineClick))
	hits[line] = hit
	return hit
end

local function PaintLine(line, on)
	local hit = hits[line]
	local id = line.questID
	local entry = on and id and L.entries[id]
	local index = entry and not entry.complete and IndexOf(id, line.Text:GetText()) or nil
	if not (entry and (entry.complete or index)) then
		if hit then
			hit:Hide()
			line.Dash:SetAlpha(1)
		end
		return
	end
	hit = hit or NewHit(line)
	hit.id, hit.index, hit.done = id, index, entry.complete or nil
	hit.kind = index and ns.QuestKind(id, index) or nil
	-- On the first line of the words, where the dash was.
	line.Dash:SetAlpha(0)
	hit.emblem:ClearAllPoints()
	hit.emblem:SetPoint("CENTER", line.Text, "TOPLEFT", -EMBLEM_X, -line.Text:GetLineHeight() / 2)
	Ink(hit)
	hit:Show()
end

-- The list

-- fresh: the game has just built and laid out the list.
local SafeDraw = Safe(function(fresh)
	local scroll = QuestScrollFrame
	local on = On()
	if kept and not kept.page and not Holding() then kept = nil end
	-- The list is the game's to build again at any time: a light whose row has gone goes with it.
	if lighter and not (lighter:IsVisible() and lighter:IsMouseOver()) then Unlight() end
	Sort(fresh)
	local show = on and not C_CVar.GetCVarBool("questPOI")
	local leading = show and Leading() or nil
	for row in scroll.titleFramePool:EnumerateActive() do PaintRow(row, show, leading) end
	for line in scroll.objectiveFramePool:EnumerateActive() do PaintLine(line, on) end
end)

-- Draws the list's marks again. always: also while the log is out of sight (the game has just built it).
function Rows.Paint(always, fresh)
	if always or QuestScrollFrame:IsVisible() then SafeDraw(fresh) end
end

-- The row under the mouse (the game says when it is entered; the leave is our hook on the row).
local function RowLeave(row)
	local mark = marks[row]
	if mark then mark:SetHovered(false) end
	Unlight(row)
end
local SafeRowLeave = Safe(RowLeave)

local function RowEnter(_, row, id)
	if not (On() and row and id) then return end
	if not left[row] then
		left[row] = true
		row:HookScript("OnLeave", SafeRowLeave)
	end
	local mark = marks[row]
	if mark and mark:IsShown() then mark:SetHovered(true) end
	Light(row, id)
end

-- A quest's page

-- After the game has shown a quest's page in the log, which it does again at every change of the log.
-- The game turns the map to the quest's own map where it has one, and closes a page whose map is left.
-- So where it has none, the map is turned to where the quest is and the page opened again there.
local function PageShown(id)
	if turning or not On() or not L.entries[id] then return end
	-- What was let go of on the map while the page was open stays let go.
	if kept and kept.page and kept.id == id and not Holding() then return end
	local map = GetQuestUiMapID(id) == 0 and not InCombatLockdown() and MapOf(StopOf(id))
	if map then
		turning = true
		OpenWorldMap(map)
		if QuestMapFrame_GetFocusedQuestID() ~= id then QuestMapFrame_ShowQuestDetails(id) end
		turning = nil
	end
	Keep(id, nil, true, true)
	Rows.Paint()
end

local function PageClosed()
	if turning or not (kept and kept.page) then return end
	if Holding() then Keep(nil) else kept = nil end
end

-- What became of the last clicks on the list's rows, for the report: each click, each page shown and each
-- page closed (with who closed it), the newest last.
local heard = {}
local HEARD = 12
local function Heard(what)
	local search = QuestScrollFrame.SearchBox:GetText()
	heard[#heard + 1] = ("%.1f %s%s"):format(GetTime(), what, search ~= "" and (" (searching \"" .. search .. "\")") or "")
	while #heard > HEARD do table.remove(heard, 1) end
end

local rebuilt = { count = 0 }   -- times the game built the list; last: who asked, as last heard
local clicks = setmetatable({}, { __mode = "k" })   -- rows with our click hook
local SafeClicked = Safe(function(row, button)
	Heard(("click %s on %s, page %s"):format(tostring(button), tostring(row.questID),
		QuestMapFrame.DetailsFrame:IsShown() and ("open on " .. tostring(QuestMapFrame_GetFocusedQuestID())) or "closed"))
end)
local function HearClicks(row)
	if clicks[row] then return end
	clicks[row] = true
	row:HookScript("OnClick", SafeClicked)
end

-- What the log's rows wear, as text.
function Rows.Report()
	local out = { ("Quest log marks: %s   the game's own markers (Show Quest Objectives): %s"):format(On() and "on" or "off",
		C_CVar.GetCVarBool("questPOI") and "on, so the rows keep them" or "off") }
	out[#out + 1] = ("order: %s   gap between rows: %s"):format(Sorted() and "the route's" or "the game's", tostring(gap))
	out[#out + 1] = ("kept on the map: %s   by the log: %s"):format(tostring(ns.KeptQuest()),
		kept and (kept.key .. (kept.page and " (its page)" or "")) or "nothing")
	out[#out + 1] = "last error: " .. tostring(failed)
	out[#out + 1] = ("the list was built %d times since the reload"):format(rebuilt.count)
	out[#out + 1] = "the last clicks on the list, pages shown and closed:"
	for _, line in ipairs(heard) do out[#out + 1] = "  " .. line end
	local rows, lines = 0, 0
	for row in QuestScrollFrame.titleFramePool:EnumerateActive() do
		rows = rows + 1
		local id, mark = row.questID, marks[row]
		local place = id and PlaceOf(id)
		local _, _, _, _, y = row:GetPoint(1)
		out[#out + 1] = ("  %s %s: %s%s, listed %s by the game, turn %s, at %s"):format(tostring(id),
			id and L.entries[id] and L.entries[id].title or "(not read yet)",
			mark and mark:IsShown() and "marked" or "no mark", place and (", place " .. place.number) or "",
			tostring(row.layoutIndex), tostring(id and turns[id]), y and ("%.0f"):format(y) or "?")
	end
	for line in QuestScrollFrame.objectiveFramePool:EnumerateActive() do
		lines = lines + 1
		local hit = hits[line]
		out[#out + 1] = ("    %s \"%s\": %s"):format(tostring(line.questID), tostring(line.Text:GetText()),
			hit and hit:IsShown() and ("objective " .. tostring(hit.index or "handed in") .. ", " .. tostring(hit.kind or "-")) or "left as it is")
	end
	table.insert(out, 5, ("%d rows and %d objective lines in the list now:"):format(rows, lines))
	return table.concat(out, "\n")
end

-- For whoever dresses the map and writes its menus (ShySkin), entry by entry on the menu it is given:
--   T:MapMenu(root)        the map's filter: our pins and objectives, which stand in for the game's own
--                          quest markers. Returns true.
--   T:LogMenu(root)        the quest log's settings.
--   T:QuestMenu(root, id)  a quest's own menu. Returns true when it wrote anything.

-- A setting's row: a check that switches it, live.
local function Switch(root, key, text, tip)
	local entry = root:CreateCheckbox(text, function() return T.db[key] ~= false end, Safe(function()
		T.db[key] = T.db[key] == false
		ns.Apply()
	end))
	entry:SetTooltip(tip)
end

function T:MapMenu(root)
	Switch(root, "mapPins", "Quest pins", "Quest givers, turn-ins and the numbered places of your route.")
	Switch(root, "goals", "Quest objectives", "A mark on each unfinished objective. Point at one to see where to look.")
	if ns.KEPT then
		local services = root:CreateButton("Town services")
		for _, kind in ipairs(ns.SERVICES or {}) do
			services:CreateCheckbox(ns.KEPT[kind], function() return T.db.services[kind] == true end, Safe(function()
				T.db.services[kind] = not T.db.services[kind] or nil
				ns.Apply()
			end))
		end
	end
	return true
end

function T:LogMenu(root)
	Switch(root, "logMarks", "Marks and map lights", "Marks each quest and objective, and lights up the map where the one under your mouse is.")
	Switch(root, "logSort", "Quests in route order", "Each zone's quests in the order your route takes them, instead of by level.")
end

function T:QuestMenu(root, id)
	if not (On() and L.entries[id]) then return false end
	local held = Holding() and kept.id == id and not kept.objective
	root:CreateButton(held and "Hide where to look" or "Show where to look", Safe(function()
		if held then Keep(nil) else Keep(id) end
	end))
	local stop = RouteStop(id)
	root:CreateButton(stop and stop.chosen and "Let the route choose" or "Head here first", Safe(function() Head(id) end))
	return true
end

ns.OnRoute(Safe(function(rebuilt)
	if rebuilt then Settle() end
end))

-- A setting changed: off lets go of what the log kept, and the rows are drawn and stood again either way.
ns.OnApply(Safe(function()
	if not On() then
		Unlight()
		if kept then Keep(nil) end
	end
	Rows.Paint(true)
end))

Shy:On("SHY_LOGIN", function()
	hooksecurefunc("QuestLogQuests_Update", function()
		Rows.Paint(true, true)
		for row in QuestScrollFrame.titleFramePool:EnumerateActive() do HearClicks(row) end
		-- (How often the game builds the list again, and who asked: a list built under a click loses it.)
		rebuilt.count = rebuilt.count + 1
		local by = (debugstack(3, 8, 0) or ""):gsub("Interface/AddOns/", ""):gsub("%s*\n%s*", " < ")
		if by ~= rebuilt.last then
			rebuilt.last = by
			Heard("list built by " .. by)
		end
	end)
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", Safe(PageShown))
	hooksecurefunc("QuestMapFrame_CloseQuestDetails", Safe(PageClosed))
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", Safe(function(id)
		Heard(("page shown for %s, map %s"):format(tostring(id), tostring(Shy.Maps.ShownMap())))
		-- (What is on screen a moment later: the page, or the list over it.)
		C_Timer.After(0.25, Safe(function()
			local page, list = QuestMapFrame.DetailsFrame, QuestScrollFrame
			Heard(("a moment later: page %s (alpha %.2f, level %d), list %s (alpha %.2f, level %d), log %s"):format(
				page:IsVisible() and "visible" or (page:IsShown() and "shown, not visible" or "hidden"), page:GetEffectiveAlpha(), page:GetFrameLevel(),
				list:IsVisible() and "visible" or (list:IsShown() and "shown, not visible" or "hidden"), list:GetEffectiveAlpha(), list:GetFrameLevel(),
				QuestMapFrame:IsVisible() and "visible" or "not visible"))
		end))
	end))
	hooksecurefunc("QuestMapFrame_CloseQuestDetails", Safe(function()
		local stack = (debugstack(3, 6, 0) or ""):gsub("Interface/AddOns/", ""):gsub("%s*\n%s*", " < ")
		Heard("page closed by " .. stack)
	end))
	EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", Safe(RowEnter), Rows)
end)
