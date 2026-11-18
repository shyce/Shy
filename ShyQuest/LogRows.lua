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
--   page: its page in the log keeps it. still: the map stays as it is. turn(map): how the map is turned to
--   where it is (our own list beside ShyMaps' window turns that view: the game's map opening would close it).
local function Keep(id, objective, page, still, turn)
	local stop = id and StopOf(id, objective)
	if not stop then
		kept = nil
		ns.KeepQuest(nil)
		return
	end
	local same = ns.KeptQuest() == stop.key
	kept = { id = id, objective = objective, key = stop.key, page = page or nil }
	local map = not still and MapOf(stop)
	if map and turn then
		turn(map)
	elseif map then
		Shy.Maps.Open(map)
	end
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
		{ "right", stop and stop.chosen and "Remove from my route" or "Go here next" } })
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
	root:CreateButton(stop and stop.chosen and "Remove from my route" or "Go here next", Safe(function() Head(id) end))
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

-- Your quests beside ShyMaps' own map window ---------------------------------------------------------------
-- The game's quest log lives in the game's map, and opening it closes ShyMaps' window: beside that window your
-- quests stand in a window of ours, docked on its right as the bank stands beside the bags (Shy.HUD's `dock`):
-- dragged away it stands free, dragged back near either side it docks there again, and docked it is as tall as the
-- map. ShyMaps' toggle at the map's right edge shows and hides it (T:QuestList); it comes and goes with that window
-- (T:QuestListFollow), as you left it (T.db.mapQuests).
--   Your quests by zone, the zone you are in first; in a zone, those with a place on the route by its number, then
--   the rest as the log has them. A quest's row: its mark as in the game's log (its place on the route, a hand-in,
--   what it asks for next), its name in its difficulty's color, its level, and what is left of it with each count.
--   The mouse on a row lights its ground on the map; a click keeps that light and turns the map to it; Shift-click
--   links it in chat; a right click: where to look, your route, and the quest's own actions (its page, tracking,
--   sharing, help, abandoning).
--   T:QuestList([on]) -> shown     on true or false, or nil to switch it; the setting is kept
--   T:QuestListFollow(open)        ShyMaps' window opened or closed: the list goes with it
--   T:QuestListShown() -> bool
--   T:QuestPage(id) -> opened      a quest's page in it, the map opened and flown to it (false: the game's map is yours)
-- Bus: SHY_QUEST_LIST (shown) as it shows or hides (ShyMaps' toggle points the way it would go).

local UI = Shy.UI
local LIST = {
	wide = 300, tall = 560, least = { 240, 260 },
	pad = 8, mark = 16, name = 12, small = 11, caps = 10,
	row = 18, line = 14, heading = 22, apart = 6, gap = 4, most = 4,
	switch = 132, control = 22, between = 6,   -- the Zone | Guide switch, the filter box, and the room between rows of them
	detail = 3, button = 22, aside = 0.55,     -- a quest's details: lines of its text before they are cut; its buttons; a quest off your guide, faded
}
local list            -- the window, made when first asked for
local ListHide        -- (it shut with the map: below)
local listRows, listHeadings = {}, {}
local listPage        -- the quest whose page the window shows (nil: the list)
local listFilter      -- what the filter box asks for, lower case (nil: everything)

-- A quest's ground, framed on the map of ShyMaps' view: on the map your route takes you to for it (its stop on the
-- route), else the one with most of its places; a hand-in, where it is handed in. The game's map is never opened.
local function Focus(id)
	local maps = Shy.addons.Maps
	if not (maps and maps.Frame) then return end
	local entry = L.entries[id]
	local points = {}
	if entry and entry.complete then
		local at = Ender(id)
		if at then points[1] = at end
	else
		for _, point in ipairs((R.Where(id))) do points[#points + 1] = point end
	end
	local stop = RouteStop(id)
	local map = stop and stop.map
	if not map then
		local count, most = {}, 0
		for _, point in ipairs(points) do
			count[point.map] = (count[point.map] or 0) + 1
			if count[point.map] > most then map, most = point.map, count[point.map] end
		end
	end
	if not map then
		local game = GetQuestUiMapID(id)
		map = game and game ~= 0 and game or nil
	end
	if not map then return end
	local on = {}
	for _, point in ipairs(points) do
		if point.map == map then on[#on + 1] = { x = point.x / 10000, y = point.y / 10000 } end
	end
	if stop and stop.map == map and stop.x then on[#on + 1] = { x = stop.x / 10000, y = stop.y / 10000 } end
	if #on == 0 then
		if maps.Open then maps:Open(map) end
		return
	end
	maps:Frame(map, on)
end

-- Whether a quest has `words` (lower case) in its name, its zone, what it asks for, or its own text.
local function Matches(entry, words)
	local function Has(text) return text ~= nil and text:lower():find(words, 1, true) ~= nil end
	if Has(entry.title) or Has(entry.header) then return true end
	for _, goal in ipairs(L.Goals(entry.id)) do
		if Has(goal.text) then return true end
	end
	local text = L.Text(entry.id)
	return text ~= nil and (Has(text.goal) or Has(text.story))
end

-- "Harvest Watcher slain: 3/20" as its words and its count.
local function Counted(text)
	local words, have, need = (text or ""):match("^(.-):?%s*(%d+)/(%d+)%s*$")
	if words and words ~= "" then return words, have .. "/" .. need end
	return text or "", nil
end

local function ListMenu(row)
	local id = row.id
	local entry = id and L.entries[id]
	if not entry then return end
	UI.ContextMenu(row, function(root)
		root:CreateTitle(entry.title)
		local held = Holding() and kept.id == id and not kept.objective
		root:CreateButton(held and "Hide where to look" or "Show where to look", Safe(function()
			if held then
				Keep(nil)
			else
				Keep(id, nil, nil, true)
				Focus(id)
			end
		end))
		local stop = RouteStop(id)
		root:CreateButton(stop and stop.chosen and "Remove from my route" or "Go here next", Safe(function() Head(id) end))
		if ns.QuestActions then
			root:CreateDivider()
			ns.QuestActions(root, id, entry.title, stop, true)
		end
	end)
end

local ListFill, ListOpen   -- below

local function ListRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row.glow = row:CreateTexture(nil, "BACKGROUND")
	row.glow:SetAllPoints()
	UI.Paint(row.glow, C.hot, 0.08)
	row.glow:Hide()
	row.mark = ns.CreateMark(row, LIST.mark, "small")
	row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.mark:EnableMouse(false)
	row.name = UI.Text(row, "", LIST.name)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", LIST.mark + LIST.apart, -2)
	row.name:SetWordWrap(false)
	row.name:SetJustifyH("LEFT")
	row.level = UI.Text(row, "", LIST.small, false, C.dim)
	row.level:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -3)
	row.level:SetJustifyH("RIGHT")
	row.lines, row.counts = {}, {}
	row:SetScript("OnEnter", Safe(function(self)
		self.glow:Show()
		if self.id then Light(self, self.id) end
	end))
	row:SetScript("OnLeave", Safe(function(self)
		self.glow:Hide()
		Unlight(self)
	end))
	row:SetScript("OnClick", Safe(function(self, button)
		local id = self.id
		if not id then return end
		if button == "RightButton" then
			ListMenu(self)
			return
		elseif IsModifiedClick("CHATLINK") and ChatFrameUtil.TryInsertQuestLinkForQuestID(id) then
			return
		end
		-- Its page; its ground is lit and the map flies to it.
		ListOpen(id)
	end))
	return row
end

-- A row's i-th line of what is left: its words at the left, its count at the right.
local function ListLine(row, i, words, count, color)
	local text, right = row.lines[i], row.counts[i]
	if not text then
		text = UI.Text(row, "", LIST.small, false, C.dim)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		right = UI.Text(row, "", LIST.small, false, C.text)
		right:SetJustifyH("RIGHT")
		row.lines[i], row.counts[i] = text, right
	end
	local y = -(LIST.row + (i - 1) * LIST.line)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", row, "TOPLEFT", LIST.mark + LIST.apart, y)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, y)
	right:SetText(count or "")
	text:SetWidth(math.max(20, row:GetWidth() - LIST.mark - LIST.apart - (count and right:GetStringWidth() + 8 or 0)))
	text:SetText(words)
	UI.Ink(text, color or C.dim)
	text:Show()
	right:Show()
end

-- A quest's row, `wide` across. Returns its height. aside: a quest your guide has no use for, faded.
local function ListPaint(row, entry, wide, leading, aside)
	local id = entry.id
	row.id = id
	row:SetWidth(wide)
	row:SetAlpha(aside and LIST.aside or 1)
	local place = PlaceOf(id)
	if place then
		row.mark:Set("step", place.lit, place.number)
	elseif entry.complete then
		row.mark:Set("turnin", leading[id])
	else
		row.mark:Set("goal", leading[id], nil, ns.QuestKind(id))
	end
	row.mark:SetPicked(Holding() and kept.id == id)
	local level = entry.level or 0
	row.level:SetText(level > 0 and tostring(level) or "")
	local color = GetQuestDifficultyColor(level > 0 and level or L.Level())
	row.name:SetWidth(math.max(20, wide - LIST.mark - LIST.apart - row.level:GetStringWidth() - 8))
	row.name:SetTextColor(color.r, color.g, color.b)
	row.name:SetText(listFilter and ns.LightWords and (ns.LightWords(entry.title, listFilter, true)) or entry.title)
	local n = 0
	if entry.failed then
		n = 1
		ListLine(row, n, "Failed: abandon it and take it again", nil, C.bad)
	elseif entry.complete then
		n = 1
		ListLine(row, n, "Ready to hand in", nil, C.good)
	else
		local open = {}
		for _, goal in ipairs(L.Goals(id)) do
			if not goal.finished and goal.text and goal.text ~= "" then open[#open + 1] = goal end
		end
		for i, goal in ipairs(open) do
			n = n + 1
			if i > LIST.most then
				ListLine(row, n, ("and %d more"):format(#open - LIST.most))
				break
			end
			local words, count = Counted(goal.text)
			ListLine(row, n, words, count)
		end
	end
	for i = n + 1, #row.lines do
		row.lines[i]:Hide()
		row.counts[i]:Hide()
	end
	local tall = LIST.row + n * LIST.line
	row:SetHeight(tall)
	row:Show()
	return tall
end

local function ListHeading(parent, i)
	local h = listHeadings[i]
	if not h then
		h = CreateFrame("Frame", nil, parent)
		h:SetHeight(LIST.heading)
		h.text = UI.Text(h, "", LIST.caps, false, C.dim)
		h.text:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 5)
		h.count = UI.Text(h, "", LIST.caps, false, C.dim)
		h.count:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 5)
		h.rule = h:CreateTexture(nil, "ARTWORK")
		h.rule:SetHeight(1)
		h.rule:SetPoint("LEFT", h.text, "RIGHT", 6, 0)
		h.rule:SetPoint("RIGHT", h.count, "LEFT", -6, 0)
		UI.Paint(h.rule, C.border, 0.6)
		listHeadings[i] = h
	end
	return h
end

-- The groups the list shows: following a guide, the quests it uses (by the route's numbers), then those it has no
-- use for, faded; else by zone, the zone you are in first, in a zone by the route's numbers, then as the log has
-- them. Only what the filter asks for.
local function ListZones()
	local here = GetZoneText()
	local order, by = {}, {}
	local guided = ns.Following() and ns.Guide and ns.Guide.Uses
	for index, entry in ipairs(L.order) do
		local zone = entry.header or OTHER
		if guided then zone = ns.Guide.Uses(entry.id) and "Your guide" or "Not in your guide" end
		if listFilter and not Matches(entry, listFilter) then zone = nil end
		if zone then
			if not by[zone] then
				by[zone] = {}
				order[#order + 1] = zone
			end
			local place = PlaceOf(entry.id)
			by[zone][#by[zone] + 1] = { entry = entry, turn = place and place.number or (1000 + index) }
		end
	end
	-- (The zone you are in first, or your guide's quests; the rest as the log has them.)
	local first = guided and "Your guide" or here
	for i, zone in ipairs(order) do
		if zone == first and i > 1 then
			table.remove(order, i)
			table.insert(order, 1, zone)
			break
		end
	end
	for _, zone in ipairs(order) do
		table.sort(by[zone], function(a, b) return a.turn < b.turn end)
	end
	return order, by
end

function ListFill()
	if not (list and list:IsShown()) or listPage then return end
	local area = list.scroll
	local wide = math.max(60, area:GetWidth() - 14)
	area.content:SetWidth(wide)
	local leading = Leading()
	local order, by = ListZones()
	local y, r = 0, 0
	local guided = ns.Following()
	for i, zone in ipairs(order) do
		local h = ListHeading(area.content, i)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", area.content, "TOPLEFT", 0, -y)
		h:SetWidth(wide)
		h.text:SetText(zone:upper())
		h.count:SetText(tostring(#by[zone]))
		h:Show()
		y = y + LIST.heading
		for _, each in ipairs(by[zone]) do
			r = r + 1
			local row = listRows[r] or ListRow(area.content)
			listRows[r] = row
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", area.content, "TOPLEFT", 0, -y)
			y = y + ListPaint(row, each.entry, wide, leading, guided and zone == "Not in your guide") + LIST.gap
		end
	end
	for i = #order + 1, #listHeadings do listHeadings[i]:Hide() end
	for i = r + 1, #listRows do
		listRows[i]:Hide()
		listRows[i].id = nil
	end
	area.content:SetHeight(math.max(1, y))
	area:Update()
	list.count:SetText(("%d of %d"):format(L.held or #L.order, L.most or 25))
	list.none:SetShown(#order == 0)
	if list.mode then list.mode:Refresh() end
end

-- A quest's page ------------------------------------------------------------------------------------------------
-- The window turns from the list to one quest's page, Back at its top: its name and level, where it is and who takes it
-- back; what is left of it, each with its count (what is done ticked); what it asks in its own sentence; its own words;
-- what it gives (XP as you would be paid it now, money, the items, those to choose from, a spell), each item the
-- game's own tooltip under the mouse with what it is to you (Offer.lua's rows); and at its foot your route, tracking,
-- sharing with your group and abandoning. Its ground is lit and the map flies to it as it opens.

local PAGE = { title = 14, text = 11, caps = 10, row = 26, icon = 20, gap = 10, after = 4, foot = 22 }
local pageTexts, pageItems, pageRules = {}, {}, {}
local pageUsed = { texts = 0, items = 0, rules = 0 }

local function PageText(parent, size, color, wrap)
	pageUsed.texts = pageUsed.texts + 1
	local text = pageTexts[pageUsed.texts]
	if not text then
		text = UI.Text(parent, "", size)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		pageTexts[pageUsed.texts] = text
	end
	text:SetFontObject(UI.TextFont(size))
	text:SetWordWrap(wrap ~= false)
	text:SetSpacing(wrap ~= false and 2 or 0)
	UI.Ink(text, color or C.text)
	text:ClearAllPoints()
	text:Show()
	return text
end

-- A heading: dim capitals, a hairline running on to the right.
local function PageHeading(parent, y, wide, words)
	local text = PageText(parent, PAGE.caps, C.dim, false)
	text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
	text:SetText(words:upper())
	pageUsed.rules = pageUsed.rules + 1
	local rule = pageRules[pageUsed.rules]
	if not rule then
		rule = parent:CreateTexture(nil, "ARTWORK")
		rule:SetHeight(1)
		UI.Paint(rule, C.border, 0.6)
		pageRules[pageUsed.rules] = rule
	end
	rule:ClearAllPoints()
	rule:SetPoint("LEFT", text, "RIGHT", 6, 0)
	rule:SetPoint("RIGHT", parent, "TOPLEFT", wide, -(y + PAGE.caps / 2))
	rule:Show()
	return y + PAGE.caps + 8
end

-- Words that wrap, `wide` across at `x`. Returns the y under them.
local function PageWords(parent, y, x, wide, words, size, color)
	local text = PageText(parent, size or PAGE.text, color)
	text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	text:SetWidth(wide - x)
	text:SetText(words)
	return y + math.ceil(text:GetStringHeight())
end

-- An item (or a spell) it gives: Offer.lua's row, as a line of the page; the game's tooltip under the mouse.
local function PageItem(parent, y, wide, row)
	pageUsed.items = pageUsed.items + 1
	local item = pageItems[pageUsed.items]
	if not item then
		item = CreateFrame("Button", nil, parent)
		item:SetHeight(PAGE.row)
		item.icon = item:CreateTexture(nil, "ARTWORK")
		item.icon:SetSize(PAGE.icon, PAGE.icon)
		item.icon:SetPoint("LEFT", 0, 0)
		item.slot = Shy.Slot.New(item, { to = item.icon, icon = item.icon, hover = false })
		item.name = UI.Text(item, "", PAGE.text)
		item.name:SetPoint("LEFT", item.icon, "RIGHT", 8, 0)
		item.name:SetJustifyH("LEFT")
		item.name:SetWordWrap(false)
		item.right = UI.Text(item, "", PAGE.text, false, C.dim)
		item.right:SetPoint("RIGHT", item, "RIGHT", 0, 0)
		item.right:SetJustifyH("RIGHT")
		item.light = item:CreateTexture(nil, "BACKGROUND")
		item.light:SetAllPoints()
		UI.Paint(item.light, C.hot, 0.08)
		item.light:Hide()
		item:SetScript("OnEnter", function(self)
			self.light:Show()
			local tip = UI.GameTipAt(self, self.icon)
			if self.spell then tip:SetSpellByID(self.spell) elseif self.item then tip:SetItemByID(self.item) end
			GameTooltip:Show()
		end)
		item:SetScript("OnLeave", function(self)
			self.light:Hide()
			GameTooltip:Hide()
		end)
		item:SetScript("OnClick", function(self)
			local link = self.link or (self.item and select(2, C_Item.GetItemInfo(self.item)))
			if link and IsModifiedClick() then HandleModifiedItemClick(link) end
		end)
		pageItems[pageUsed.items] = item
	end
	item.item, item.spell, item.link = row.item, row.spell, row.link
	item.icon:SetTexture(row.icon)
	item.right:SetText(row.right or "")
	UI.Ink(item.right, row.rightColor or C.dim)
	item.name:SetText(row.text or "")
	local color = row.color or C.text
	item.name:SetTextColor(color[1], color[2], color[3])
	item:ClearAllPoints()
	item:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
	item:SetWidth(wide)
	item.name:SetWidth(math.max(20, wide - PAGE.icon - 8 - item.right:GetStringWidth() - 10))
	item:Show()
	return y + PAGE.row
end

local function PageFill()
	local id = listPage
	local entry = id and L.entries[id]
	if not (list and entry) then return end
	local area = list.pageScroll
	local body = area.content
	local wide = math.max(60, area:GetWidth() - 14)
	body:SetWidth(wide)
	pageUsed.texts, pageUsed.items, pageUsed.rules = 0, 0, 0
	local y = 2
	-- Its name in its difficulty's color, its level at the right.
	local level = entry.level or 0
	local color = GetQuestDifficultyColor(level > 0 and level or L.Level())
	local levelText = PageText(body, PAGE.text, C.dim, false)
	levelText:SetPoint("TOPRIGHT", body, "TOPLEFT", wide, -(y + 2))
	levelText:SetJustifyH("RIGHT")
	levelText:SetText(level > 0 and ("Level " .. level) or "")
	local title = PageText(body, PAGE.title, C.text)
	title:SetFontObject(UI.TitleFont and UI.TitleFont(PAGE.title) or UI.TextFont(PAGE.title))
	title:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	title:SetWidth(wide - levelText:GetStringWidth() - 10)
	title:SetText(entry.title)
	title:SetTextColor(color.r, color.g, color.b)
	y = y + math.ceil(title:GetStringHeight()) + 2
	-- Where, and who takes it back.
	local at = Ender(id)
	local where = entry.header or ""
	if at and at.who then where = (where ~= "" and (where .. "  \194\183  ") or "") .. "Hand in to " .. at.who end
	if where ~= "" then y = PageWords(body, y, 0, wide, where, PAGE.text, C.dim) end
	y = y + PAGE.gap
	-- What is left of it, each with its count; what is done ticked.
	y = PageHeading(body, y, wide, "Objectives")
	if entry.failed then
		y = PageWords(body, y, 0, wide, "Failed: abandon it and take it again", PAGE.text, C.bad) + PAGE.after
	elseif entry.complete then
		y = PageWords(body, y, 0, wide, "Ready to hand in", PAGE.text, C.good) + PAGE.after
	end
	for _, goal in ipairs(L.Goals(id)) do
		if goal.text and goal.text ~= "" then
			local words, count = Counted(goal.text)
			if count then
				local right = PageText(body, PAGE.text, goal.finished and C.good or C.text, false)
				right:SetPoint("TOPRIGHT", body, "TOPLEFT", wide, -y)
				right:SetJustifyH("RIGHT")
				right:SetText(count)
			end
			y = PageWords(body, y, 0, wide - 44, words, PAGE.text, goal.finished and C.dim or C.text) + PAGE.after
		end
	end
	-- What it asks, in its own sentence; then its own words.
	local text = L.Text(id) or {}
	if text.goal then y = PageWords(body, y + PAGE.after, 0, wide, text.goal, PAGE.text, C.text) end
	if text.story then
		y = PageHeading(body, y + PAGE.gap, wide, "Description")
		y = PageWords(body, y, 0, wide, text.story, PAGE.text, C.dim)
	end
	-- What it gives.
	local quest, offer = D.Quest(id), D.Offer(id) or {}
	local xp = GetQuestLogRewardXP(id)
	if not (xp and xp > 0) and quest then xp = L.Pays(quest) end
	local money = GetQuestLogRewardMoney(id) or 0
	if money <= 0 then money = offer.money or 0 end
	local items, choices = offer.items or {}, offer.choices or {}
	if (xp and xp > 0) or money > 0 or #items > 0 or #choices > 0 or offer.spell then
		y = PageHeading(body, y + PAGE.gap, wide, "Rewards")
		local pays = {}
		if xp and xp > 0 then pays[#pays + 1] = UI.Wrap(C.alert, ("+%s XP"):format(BreakUpLargeNumbers(xp))) end
		if money > 0 then pays[#pays + 1] = UI.Money(money, false, PAGE.text) end
		if #pays > 0 then y = PageWords(body, y, 0, wide, table.concat(pays, "  \194\183  "), PAGE.text) + PAGE.after end
		local itemRow = ns.Offer and ns.Offer.ItemRow
		if itemRow and #choices > 0 then
			if #choices > 1 then y = PageWords(body, y + PAGE.after, 0, wide, "Choose one:", PAGE.text, C.dim) + PAGE.after end
			for _, each in ipairs(choices) do y = PageItem(body, y, wide, itemRow(each)) end
		end
		if itemRow and #items > 0 then
			if #choices > 1 then y = PageWords(body, y + PAGE.after, 0, wide, "And you get:", PAGE.text, C.dim) + PAGE.after end
			for _, each in ipairs(items) do y = PageItem(body, y, wide, itemRow(each)) end
		end
		if offer.spell then
			y = PageItem(body, y, wide, { icon = C_Spell.GetSpellTexture(offer.spell), text = C_Spell.GetSpellName(offer.spell) or "A spell",
				spell = offer.spell, right = "You learn it", rightColor = C.dim })
		end
	end
	for i = pageUsed.texts + 1, #pageTexts do pageTexts[i]:Hide() end
	for i = pageUsed.items + 1, #pageItems do pageItems[i]:Hide() end
	for i = pageUsed.rules + 1, #pageRules do pageRules[i]:Hide() end
	body:SetHeight(math.max(1, y + PAGE.gap))
	area:Update()
	-- Its foot: your route first; then tracking, sharing and abandoning.
	local stop = RouteStop(id)
	list.go:SetLabel(stop and stop.chosen and "Remove from my route" or "Go here next")
	list.go:SetPrimary(not (stop and stop.chosen))
	list.go:SetTone(stop and stop.chosen and C.bad or nil)
	list.track:SetLabel(C_QuestLog.GetQuestWatchType(id) ~= nil and "Untrack" or "Track")
	local share = C_QuestLog.IsPushableQuest(id) and IsInGroup() and not InCombatLockdown()
	list.share:SetUsable(share, not IsInGroup() and "Only with a group" or InCombatLockdown() and "After the fight" or "This quest can't be shared")
end

-- The window as the list, or as one quest's page (`id`).
local function ListView(id)
	listPage = id
	local page = id ~= nil
	for _, part in ipairs({ list.mode, list.count, list.filter, list.scroll }) do part:SetShown(not page) end
	for _, part in ipairs({ list.back, list.pageScroll, list.go, list.track, list.share, list.abandon }) do part:SetShown(page) end
	list.none:SetShown(false)
	if page then
		list.pageScroll:SetVerticalScroll(0)
		PageFill()
	else
		ListFill()
	end
end

-- A quest's page, its ground lit and the map flown to it.
function ListOpen(id)
	if not (list and L.entries[id]) then return end
	Keep(id, nil, nil, true)
	Focus(id)
	ListView(id)
end

-- Docked, as tall as the map it stands beside.
local function ListMatch()
	if not list then return end
	local host = Shy.HUD.Find("shymaps.window")
	if host and Shy.HUD.Docked(list) and math.abs(list:GetHeight() - host:GetHeight()) > 0.5 then
		Shy.HUD.Resize(list, list:GetWidth(), host:GetHeight())
	end
end

local function ListMake()
	if list then return list end
	local top = UI.HEAD.window.line + UI.HEAD.window.lip + 6
	-- (Made as tall as the map it docks beside, so it opens matched; ListMatch keeps it so.)
	local host = Shy.HUD.Find("shymaps.window")
	-- (No name: Escape is the map's to close it with, which takes this down with it and keeps it on for next time. On
	-- the game's list of windows Escape closes, it would be shut as if by its own x.)
	list = UI.Window({
		id = "shyquest.quests",
		title = "Quests",
		width = LIST.wide, height = host and math.max(LIST.least[2], host:GetHeight()) or LIST.tall,
		point = { "CENTER", "CENTER", 360, 0 },
		-- (Shown while the map's window is and you keep it on: the HUD lays its windows out again now and then, and a
		-- window it is told is shut it shuts, as if by its x.)
		shown = function()
			local maps = Shy.addons.Maps
			return list ~= nil and list.made == true and T.db.mapQuests == true and maps ~= nil and maps.WindowShown ~= nil and maps:WindowShown() == true
		end,
		grip = { flow = true, min = LIST.least },
		strata = "HIGH",
		head = { size = "window", icon = T.mark, title = "Quests" },
		dock = { to = "shymaps.window", side = "RIGHT", label = "Beside the map" },
		-- Its x: docked beside the map, the map and the list close together (the list kept on for next time); standing
		-- free, the list alone, and the setting goes with it. Nothing else switches it off (T:QuestList): shut with the
		-- map or laid out again by the HUD, it is kept.
		close = function()
			local maps = Shy.addons.Maps
			if Shy.HUD.Docked(list) and maps and maps.CloseWindow then
				maps:CloseWindow()
			else
				T.db.mapQuests = false
			end
			ListHide()
		end,
	})
	local body = UI.Body(list)
	-- The card's own switch, Zone or Guide: the list groups as the card leads (and switching here switches the card).
	list.mode = UI.Segmented(body, { "Zone", "Guide" },
		function() return ns.Following() and 2 or 1 end,
		function(index)
			if index == 2 and ns.Run and ns.Run.Doing() then ns.Run.Stop(true) end
			T:SetQuestStyle(index == 2 and "guide" or "zone")
			ListFill()
		end,
		{ width = LIST.switch, height = LIST.control })
	list.mode:SetPoint("TOPLEFT", body, "TOPLEFT", LIST.pad, -top)
	-- How many quests you hold, level with it at the right.
	list.count = UI.Text(body, "", LIST.small, false, C.dim)
	list.count:SetPoint("RIGHT", body, "TOPRIGHT", -LIST.pad, -(top + LIST.control / 2))
	-- The filter: a quest's name, zone, what it asks for or its own text; the words lit where they stand.
	list.filter = UI.Input(body, nil, function() return listFilter or "" end, function(text)
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		listFilter = text ~= "" and text:lower() or nil
		ListFill()
	end, { width = LIST.wide - 2 * LIST.pad, live = true, placeholder = function() return "Filter quests" end })
	list.filter:SetPoint("TOPLEFT", body, "TOPLEFT", LIST.pad, -(top + LIST.control + LIST.between))
	list.filter:SetPoint("RIGHT", body, "RIGHT", -LIST.pad, 0)
	local below = top + 2 * LIST.control + 2 * LIST.between
	list.none = UI.Text(body, "No quest matches that.", LIST.small, false, C.dim)
	list.none:SetPoint("TOPLEFT", body, "TOPLEFT", LIST.pad, -(below + LIST.between))
	list.none:Hide()
	list.scroll = UI.ScrollArea(body, LIST.wide - 2 * LIST.pad, LIST.tall, { smooth = true })
	list.scroll:SetPoint("TOPLEFT", body, "TOPLEFT", LIST.pad, -below)
	-- A quest's page: Back where the switch stands; its words down a scroll of their own; its buttons at the foot.
	list.back = UI.Button(body, "Back", 72, Safe(function()
		if Holding() and kept.id == listPage then Keep(nil) end
		ListView(nil)
	end))
	list.back:SetHeight(LIST.control)
	list.back:SetPoint("TOPLEFT", body, "TOPLEFT", LIST.pad, -top)
	local footTall = 2 * PAGE.foot + LIST.between
	list.pageScroll = UI.ScrollArea(body, LIST.wide - 2 * LIST.pad, LIST.tall, { smooth = true })
	list.pageScroll:SetPoint("TOPLEFT", body, "TOPLEFT", LIST.pad, -(top + LIST.control + 2 * LIST.between))
	list.pageScroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -LIST.pad, LIST.pad + footTall + LIST.between)
	list.pageScroll:HookScript("OnSizeChanged", Safe(function() if listPage then PageFill() end end))
	list.pageTexts = pageTexts   -- (what the page says, for whoever reads the window)
	list.go = UI.Button(body, "Go here next", 100, Safe(function()
		if listPage then Head(listPage) end
	end))
	list.go:SetHeight(PAGE.foot)
	list.go:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", LIST.pad, LIST.pad + PAGE.foot + LIST.between)
	list.go:SetPoint("RIGHT", body, "RIGHT", -LIST.pad, 0)
	local function Third(label, click)
		local button = UI.Button(body, label, 80, Safe(click))
		button:SetHeight(PAGE.foot)
		return button
	end
	list.track = Third("Track", function()
		local id = listPage
		if not id then return end
		if C_QuestLog.GetQuestWatchType(id) ~= nil then C_QuestLog.RemoveQuestWatch(id) else C_QuestLog.AddQuestWatch(id) end
		PageFill()
	end)
	list.share = Third("Share", function()
		if listPage and not InCombatLockdown() then QuestUtil.ShareQuest(listPage) end
	end)
	list.abandon = Third("Abandon", function()
		if listPage then QuestMapQuestOptions_AbandonQuest(listPage) end
	end)
	list.abandon:SetTone(C.bad)
	-- (Three across the foot, each a third, the gaps between.)
	local function Lay()
		local each = (list:GetWidth() - 2 * LIST.pad - 2 * LIST.between) / 3
		for i, button in ipairs({ list.track, list.share, list.abandon }) do
			button:SetWidth(math.max(40, each))
			button:SetLabel(button.text:GetText())
			button:ClearAllPoints()
			button:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", LIST.pad + (i - 1) * (each + LIST.between), LIST.pad)
		end
	end
	list:HookScript("OnSizeChanged", Safe(Lay))
	Lay()
	for _, part in ipairs({ list.back, list.pageScroll, list.go, list.track, list.share, list.abandon }) do part:Hide() end
	list.scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -LIST.pad, LIST.pad)
	list.scroll:HookScript("OnSizeChanged", Safe(function() ListFill() end))
	list:HookScript("OnShow", Safe(function()
		ListMatch()
		-- (Docked by the HUD as it shows: matched again once it stands there, the frame after. Once an opening.)
		C_Timer.After(0, Safe(ListMatch))
		ListFill()
		Shy:Fire("SHY_QUEST_LIST", true)
	end))
	list:HookScript("OnHide", function() Shy:Fire("SHY_QUEST_LIST", false) end)
	Shy:On("SHY_HUD_RESIZED", function(box)
		if box == Shy.HUD.Find("shymaps.window") then ListMatch() end
	end)
	-- (Whole now: the HUD may show it, its rows filled as it opens.)
	list.made = true
	return list
end

-- ShyMaps' window is up (its map in a window of its own).
local function MapUp()
	local maps = Shy.addons.Maps
	return maps ~= nil and maps.WindowShown ~= nil and maps:WindowShown() == true
end

function ListHide()
	if list and list:IsShown() then list:Hide() end
end

function T:QuestList(on)
	if on == nil then on = not (list and list:IsShown()) end
	T.db.mapQuests = on and true or false
	if on and MapUp() then
		ListMake()
		list:Show()
		list:Raise()
	else
		ListHide()
	end
	return list ~= nil and list:IsShown()
end

-- A quest's page in the Quests window, the map opened as you use it (Shy.Maps.Open) and flown to it. False where
-- the map you use is the game's (its own log has the page there).
function T:QuestPage(id)
	if not L.entries[id] then return false end
	local maps = Shy.addons.Maps
	if not MapUp() and not (maps and maps.ShowMap and maps:ShowMap(nil) and MapUp()) then return false end
	T.db.mapQuests = true
	ListMake()
	list:Show()
	list:Raise()
	ListOpen(id)
	return true
end

-- The window, made or not (whoever reads it: the tests, a render).
function Rows.List() return list end

function T:QuestListShown()
	return list ~= nil and list:IsShown()
end

function T:QuestListFollow(open)
	if open and T.db.mapQuests then
		ListMake()
		list:Show()
	else
		ListHide()
	end
end

ns.OnRoute(Safe(function(rebuilt)
	if not rebuilt then return end
	-- (A quest whose page is up and has left the log: back to the list.)
	if listPage and not L.entries[listPage] and list then ListView(nil) end
	if listPage then PageFill() else ListFill() end
end))
