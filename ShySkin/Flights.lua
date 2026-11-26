-- The flight master: where to fly. A window of our own in place of the game's (TaxiFrame, the flight master's map),
-- built for the one choice a flight master asks of you: the flight your guide wants, or somewhere else. It is a desk
-- (Shop.Desk): the game's window stays the panel the game opens and closes, emptied and taking no mouse; ours is its
-- child, in the make of the quest giver's window, so the talk that opens the map turns into it where it stands; it
-- flows to any size.
--
-- The band: the flight master's face with a wing at its corner, who they are, and pills: where your guide (or your
-- route) flies you, and how many flights there are from here.
-- Left, the choice. Your guide's flight under its own name, a taller row, picked as the window opens; under it every
-- other flight, the quickest first, each with its zone, its cost and its time in the air (dim and "~" while it is an
-- estimate: never flown). With no flight asked for, the list alone.
-- Right, the game's flight map in a frame of the theme's look (a housing of its own: the look's border, and what it
-- lays round a content it holds, a well or rivets, L.frame wide), the whole of it as the game draws it, its points as the
-- family's marks: where you are in the color for yes, the rest in steel; the one picked lit, the way it flies drawn
-- hop by hop (the way of the one under the mouse while it is there) with the points it passes. A mark's hover names
-- it with its time, cost and stops.
-- The foot: your gold, and Fly to the one picked. A click on a flight or its mark picks it; a second click takes it.
-- Nothing is ever taken for you: your guide's flight is one press of Fly away as the window opens.
-- Your guide's flight wears a color of its own (GUIDE, the gold of what a quest asks for) wherever it is the one
-- shown: its row's wash and wing, its mark, its way, and Fly itself. Pick another and all of those are the plain
-- ones again (your color in the list and on Fly, the travel color on the map), your guide's mark steel like the rest.
-- While on, the module claims "flights" (ns.Claim) so ShyQuest leaves the flight to it.
--
-- The game makes its map's buttons as the map opens, on the window itself: they are put away at each opening.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local Maps = Shy.Maps
local C = UI.colors
local Shop = ns.Shop
local Talk = Shy.Talk
local WIN = Talk and Talk.WIN

local L = {
	w = 760, h = 560, least = { 600, 440 },
	top = 8,                               -- from the band to the list and the map
	list = 280,                            -- the list's width
	gap = 18,                              -- between the list and the map
	right = 14,                            -- the map's right margin
	kick = 24,                             -- a section's name over its hairline, and the room under it
	row = 30, rowGap = 2,                  -- a flight's row
	lead = 46, sign = 22,                  -- your guide's row, and the wing in it
	between = 10,                          -- from your guide's row to the others' name
	clock = 42,                            -- a row's time, right-aligned in this much
	key = 22,                              -- a button's height
	pills = -44,                           -- the band's second line, under who the flight master is
	mark = 18, picked = 24, hovered = 22, stop = 12,   -- the map's marks: a flight, the one picked, under the mouse, passed on the way
	apart = 18 / 580,                      -- marks nearer than this share of the map shown stand apart (as the game's map has them)
	frame = 7,                             -- the map's frame: this much of its housing shows round it, inside the look's border
	route = 3,                             -- the way's width, in pixels
	again = 0.5,                           -- seconds within which a second click on the one picked takes it
}
local STEEL = { 0.74, 0.74, 0.78 }
local TRAVEL = Theme.TRAVEL.flight
local GUIDE = C.alert                      -- your guide's flight, wherever it is the one shown
local NONE = {}

local WORDS = {
	title = "Flight Master", guide = "Your guide", route = "Your route", rest = "Somewhere else",
	flights = "%d flights", one = "1 flight", none = "No flights from here",
	fly = "Fly to %s", pick = "Pick a flight", noGold = "Not enough gold",
	air = "%s in the air", about = "About %s in the air", stops = "Stops at %s", here = "You are here",
}

local M              -- the module
local desk           -- our window (Shop.Desk)
local own = { rows = {}, marks = {} }   -- our frames, made once
local visit = {}     -- this visit: role, want (the slot your guide asks for), whose ("guide" or "route")
local spots = {}     -- slot -> { slot, kind, full, name, zone, x, y, cost, seconds, timed }: the map's points as last read
local order = {}     -- ... in the map's order
local flights = {}   -- ... the ones you can fly to but your guide's, the quickest first
local picked         -- the slot picked
local hovered        -- the slot under the mouse (its row or its mark)
local clicked        -- the last click on the one picked: { slot, at }
local Refresh, Stale, Draw, DrawMap, DrawFoot

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

local function Wide(text)
	local wide = text:GetUnboundedStringWidth()
	return (issecretvalue(wide) or not wide) and 0 or math.ceil(wide)
end

-- Reading the map

-- Marks nearer each other than L.apart move apart, the later from the earlier, as the game's own map places them.
local function Apart()
	local near = L.apart
	local placed = {}
	for _, f in ipairs(order) do
		if f.kind ~= "DISTANT" then
			for _, other in ipairs(placed) do
				local dx, dy = f.x - other.x, f.y - other.y
				local d2 = dx * dx + dy * dy
				if d2 < near * near then
					if d2 <= 0 then dx, dy, d2 = near, 0, near * near end
					local scale = near / math.sqrt(d2)
					f.x, f.y = other.x + dx * scale, other.y + dy * scale
				end
			end
			placed[#placed + 1] = f
		end
	end
end

local function Sooner(a, b)
	local at, bt = a.seconds or math.huge, b.seconds or math.huge
	if at ~= bt then return at < bt end
	return a.name < b.name
end

local function Read()
	wipe(spots)
	wipe(order)
	wipe(flights)
	local Offer = Shy.Way.Flight.Offer
	for slot = 1, NumTaxiNodes() do
		local kind = TaxiNodeGetType(slot)
		if kind == "CURRENT" or kind == "REACHABLE" or kind == "DISTANT" then
			local x, y = TaxiNodePosition(slot)
			local full = TaxiNodeName(slot) or ""
			local name, zone = full:match("^(.-),%s*(.+)$")
			local f = { slot = slot, kind = kind, full = full, name = name or full, zone = zone or "", x = x or 0, y = y or 0 }
			spots[slot] = f
			order[#order + 1] = f
			if kind == "REACHABLE" then
				f.cost = TaxiNodeCost(slot) or 0
				if Offer then f.seconds, f.timed = Offer(slot) end
				if slot ~= visit.want then flights[#flights + 1] = f end
			end
		end
	end
	table.sort(flights, Sooner)
	Apart()
end

-- A flight you can take: the point at a slot, where it is one.
local function Flight(slot)
	local f = slot and spots[slot]
	if f and f.kind == "REACHABLE" then return f end
end

-- The hops of the flight to a slot: { from slot, to slot } each.
local function Hops(slot)
	local hops = {}
	for hop = 1, GetNumRoutes(slot) do
		hops[#hops + 1] = { TaxiGetNodeSlot(slot, hop, true), TaxiGetNodeSlot(slot, hop, false) }
	end
	return hops
end

-- Flying

local function Fly()
	local f = Flight(picked)
	if not f or f.cost > GetMoney() then return Refresh() end
	TakeTaxiNode(f.slot)
end

local function Pick(f)
	if f.kind ~= "REACHABLE" then return end
	local now = GetTime()
	if clicked and clicked.slot == f.slot and picked == f.slot and now - clicked.at <= L.again then
		clicked = nil
		return Fly()
	end
	clicked = { slot = f.slot, at = now }
	if picked ~= f.slot then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
	picked = f.slot
	Refresh()
end

local function Hover(slot)
	if hovered == slot then return end
	hovered = slot
	if own.side then Shop.Try(M, DrawMap) end
end

-- Building

-- A flight's row: its name and zone, its cost, its time in the air at the right. Your guide's (lead) is taller: the
-- wing lit in your color, its zone under its name, its cost under its time.
local function MakeRow(lead)
	local row = CreateFrame("Button", nil, own.stock)
	row:SetHeight(lead and L.lead or L.row)
	row:RegisterForClicks("LeftButtonUp")
	-- Picked: your color washed in from the left with a fine line of it at the edge. Under the mouse: a glow.
	row.lit = row:CreateTexture(nil, "BACKGROUND")
	row.lit:SetAllPoints()
	row.lit:SetColorTexture(1, 1, 1, 1)
	row.lit:Hide()
	row.edge = row:CreateTexture(nil, "BACKGROUND", nil, 2)
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(2)
	UI.Paint(row.edge, lead and GUIDE or Theme.Accent)
	row.edge:Hide()
	row.hot = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.hot, 0.09)
	row.hot:Hide()
	row.name = Text(row, UI.NameFont(lead and 15 or 12), lead and C.head or C.text)
	row.zone = Text(row, UI.TextFont(11), C.dim)
	row.time = Text(row, UI.NameFont(lead and 15 or 12), C.head)
	row.time:SetJustifyH("RIGHT")
	row.cost = Text(row, UI.NameFont(10), C.dim)
	row.cost:SetJustifyH("RIGHT")
	if lead then
		row.mark = Maps.Mark(row, L.sign)
		row.mark:SetPoint("LEFT", 8, 0)
		row.inset = 8 + L.sign + 8
		row.name:SetPoint("TOPLEFT", row.inset, -7)
		row.zone:SetPoint("TOPLEFT", row.inset, -27)
		row.time:SetPoint("TOPRIGHT", -8, -7)
		row.cost:SetPoint("TOPRIGHT", -8, -28)
	else
		row.inset = 8
		row.name:SetPoint("LEFT", row.inset, 0)
		row.zone:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
		row.time:SetPoint("RIGHT", -8, 0)
		row.time:SetWidth(L.clock)
		row.cost:SetPoint("RIGHT", -(14 + L.clock), 0)
	end
	row.lead = lead
	row:SetScript("OnClick", function(self)
		if self.flight then Pick(self.flight) end
	end)
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if self.flight then Hover(self.flight.slot) end
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		Hover(nil)
	end)
	return row
end

local function Row(i)
	local row = own.rows[i]
	if not row then
		row = MakeRow(false)
		own.rows[i] = row
	end
	return row
end

-- What a mark's hover says: where you are, or a flight's time, its cost and where it stops on the way.
local function Say(f)
	if f.kind == "CURRENT" then return WORDS.here end
	local lines = {}
	if f.seconds then lines[#lines + 1] = (f.timed and WORDS.air or WORDS.about):format(Clock(f.seconds)) end
	if f.cost > 0 then lines[#lines + 1] = UI.Money(f.cost, nil, 11) end
	local stops = {}
	local hops = Hops(f.slot)
	for i = 1, #hops - 1 do
		local stop = spots[hops[i][2]]
		if stop then stops[#stops + 1] = stop.name end
	end
	if #stops > 0 then lines[#lines + 1] = WORDS.stops:format(table.concat(stops, ", ")) end
	return table.concat(lines, "\n")
end

-- A point on the map: the family's mark, the flight's wing in it.
local function Mark(i)
	local mark = own.marks[i]
	if mark then return mark end
	mark = Maps.Mark(own.pins, L.mark)
	mark:SetScript("OnEnter", function(self)
		local f = self.flight
		if not f then return end
		Hover(f.slot)
		UI.Tip(self, f.full, Say(f))
	end)
	mark:SetScript("OnLeave", function(self)
		UI.TipHide(self)
		Hover(nil)
	end)
	mark:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.flight then Pick(self.flight) end
	end)
	own.marks[i] = mark
	return mark
end

local function Build()
	desk = Shop.Desk({
		id = "shyskin.flights", title = WORDS.title, glyph = "fly",
		width = L.w, height = L.h, least = L.least,
		frame = function() return TaxiFrame end,
		on = function() return M ~= nil and M.on == true end,
		try = function(fn) Shop.Try(M, fn) end,
		flow = function() if Stale then Stale() end end,
		close = function() CloseTaxiMap() end,
	})
	local box, shell = desk.box, desk.shell
	own.box, own.shell, own.driver = box, shell, desk.driver
	local left = WIN.pad - 2

	-- The choice: your guide's flight under its name, the others under theirs, scrolling.
	local list = UI.ScrollArea(box, L.list, L.h, { smooth = true, shades = C.panel })
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", shell.band, "BOTTOMLEFT", left, -L.top)
	list:SetPoint("BOTTOMLEFT", shell.foot, "TOPLEFT", left, 2)
	list:SetWidth(L.list)
	list:SetFrameLevel(box:GetFrameLevel() + 3)
	own.list = list
	own.stock = CreateFrame("Frame", nil, list.content)
	own.stock:SetPoint("TOPLEFT")
	own.stock:SetSize(L.list, 1)
	own.kickLead = Shop.Kicker(own.stock)
	own.kickRest = Shop.Kicker(own.stock)
	own.lead = MakeRow(true)
	own.none = Text(own.stock, UI.TextFont(13), C.dim)
	own.none:SetPoint("TOPLEFT", 8, -6)
	own.none:SetText(WORDS.none)
	own.divide = box:CreateTexture(nil, "ARTWORK")
	own.divide:SetWidth(1)
	own.divide:SetPoint("TOP", shell.band, "BOTTOM", 0, 0)
	own.divide:SetPoint("BOTTOM", shell.foot, "TOP", 0, 0)
	own.divide:SetPoint("LEFT", UI.Body(box), "LEFT", 2 + left + L.list + L.gap / 2, 0)
	UI.Paint(own.divide, C.border, 0.9)

	-- The map. Its frame is a housing of its own in the theme's look, kept in it as the theme changes; the map is a
	-- sheet set in it (Frame, at each draw), a frame over the housing so nothing of a look lies on the map: the game's
	-- own art inside a hairline, the way drawn over it (cut at the sheet's edge), the marks over that.
	local stage = CreateFrame("Frame", nil, box)
	stage:SetFrameLevel(box:GetFrameLevel() + 3)
	own.stage = stage
	own.stageX = left + L.list + L.gap
	local map = CreateFrame("Frame", nil, stage)
	map:SetPoint("TOP")
	UI.Panel(map, { looks = true, brackets = false, line = false })
	own.map = map
	local sheet = CreateFrame("Frame", nil, map)
	sheet:SetFrameLevel(map:GetFrameLevel() + 1)
	UI.Skin(sheet, C.bg, C.border)
	own.sheet = sheet
	own.art = sheet:CreateTexture(nil, "ARTWORK")
	own.art:SetPoint("TOPLEFT", 1, -1)
	own.art:SetPoint("BOTTOMRIGHT", -1, 1)
	own.lines = CreateFrame("Frame", nil, sheet)
	own.lines:SetAllPoints(own.art)
	own.lines:SetFrameLevel(sheet:GetFrameLevel() + 1)
	own.lines:SetClipsChildren(true)
	own.pen = Maps.Pen(own.lines, "TOPLEFT", own.lines, true)
	own.pins = CreateFrame("Frame", nil, sheet)
	own.pins:SetAllPoints(own.art)
	own.pins:SetFrameLevel(sheet:GetFrameLevel() + 2)

	-- The foot: your gold at its left end, Fly at its right.
	own.gold = Text(shell.foot, UI.NameFont(12), C.head)
	own.gold:SetPoint("LEFT", WIN.button, 0)
	own.fly = UI.Button(shell.foot, "", 96, Fly)
	own.fly:SetHeight(L.key)
	own.fly:SetFrameLevel(shell.foot:GetFrameLevel() + 2)
	own.fly.dims = true
	own.fly:Hide()

	-- The opening: the list a line after a line, rising; the map with it; the band's and the foot's with the first.
	desk.risers = { { own.stock, list.content }, { stage, shell.band, own.stageX, -(WIN.band + L.top) } }
	desk.Pieces = function()
		local pieces = { stage }
		for _, piece in ipairs({ own.kickLead, own.lead, own.kickRest }) do
			if piece:IsShown() then pieces[#pieces + 1] = piece end
		end
		for _, row in ipairs(own.rows) do
			if row:IsShown() then pieces[#pieces + 1] = row end
		end
		return pieces
	end
	desk.Firsts = function()
		local firsts = { own.gold, own.fly }
		for _, pill in ipairs(shell.pills) do firsts[#firsts + 1] = pill end
		return firsts
	end
	desk.Draw = function() Draw() end
	stage.line = 2
end

-- Drawing

-- The band: who the flight master is, and pills: where your guide flies you, and how many flights there are; with
-- nothing to say, where you are.
local function DrawBand(wide)
	local shell = own.shell
	local role, place = desk:Meet("npc", visit)
	local words = math.max(80, wide - shell.left - WIN.pad - 4)
	shell.role:SetWidth(words)
	local facts = {}
	local want = Flight(visit.want)
	if want then facts[#facts + 1] = { text = (visit.whose == "route" and WORDS.route or WORDS.guide) .. ": " .. want.name, tone = "alert" } end
	local all = #flights + (want and 1 or 0)
	if all > 0 then facts[#facts + 1] = { text = all == 1 and WORDS.one or WORDS.flights:format(all) } end
	local shown = shell:Pills(facts, L.pills)
	shell.sub:SetShown(shown == 0)
	shell.sub:SetText(role ~= "" and place or "")
	shell.sub:SetWidth(words)
end

local function DrawRow(row, f)
	row.flight = f
	row.name:SetText(f.name)
	row.zone:SetText(f.zone)
	-- (A time never flown is an estimate: quiet, and said so.)
	row.time:SetText(f.seconds and ((f.timed and "" or "~") .. Clock(f.seconds)) or "")
	UI.Ink(row.time, f.timed and C.head or C.dim)
	row.cost:SetText(f.cost > 0 and UI.Money(f.cost, nil, 10, row.cost) or "")
	UI.Ink(row.cost, f.cost > GetMoney() and C.bad or C.dim)
	local wide = row:GetWidth()
	local on = picked == f.slot
	if row.lead then
		local words = math.max(40, wide - row.inset - math.max(Wide(row.time), Wide(row.cost)) - 18)
		row.name:SetWidth(words)
		row.zone:SetWidth(words)
		-- Its wing: lit in the guide's color while it is the one picked, steel like any other once it isn't.
		row.mark.color, row.mark.lit = on and GUIDE or STEEL, on
		row.mark:Set("flight", row.mark.color, on)
	else
		-- Its name whole where there is room, its zone after it in what is left.
		local room = wide - row.inset - 14 - L.clock - Wide(row.cost) - 10
		local name = math.max(40, math.min(Wide(row.name), room))
		row.name:SetWidth(name)
		local rest = room - name - 6
		row.zone:SetShown(rest >= 30 and f.zone ~= "")
		row.zone:SetWidth(math.max(1, rest))
	end
	if on then
		local r, g, b = GUIDE[1], GUIDE[2], GUIDE[3]
		if not row.lead then r, g, b = Theme.Accent() end
		row.lit:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.22), CreateColor(r, g, b, 0.02))
	end
	row.lit:SetShown(on)
	row.edge:SetShown(on)
end

-- The choice: your guide's flight under its own name, then the others under theirs; with none asked for, the list alone.
local function DrawList()
	local stock = own.stock
	local y, line = 0, 0
	local width = L.list - 8
	local function Place(piece, tall)
		piece:ClearAllPoints()
		piece:SetPoint("TOPLEFT", stock, "TOPLEFT", 0, -y)
		piece:SetWidth(width)
		piece.line = line
		line = line + 1
		piece:Show()
		y = y + tall
	end
	local want = Flight(visit.want)
	own.kickLead:SetShown(want ~= nil)
	own.lead:SetShown(want ~= nil)
	own.kickRest:SetShown(want ~= nil and #flights > 0)
	if want then
		Place(own.kickLead, L.kick)
		own.kickLead:Say(visit.whose == "route" and WORDS.route or WORDS.guide)
		UI.Ink(own.kickLead.text, GUIDE)
		Place(own.lead, L.lead + L.between)
		DrawRow(own.lead, want)
		if #flights > 0 then
			Place(own.kickRest, L.kick)
			own.kickRest:Say(WORDS.rest, tostring(#flights))
		end
	end
	for i, f in ipairs(flights) do
		local row = Row(i)
		Place(row, L.row + L.rowGap)
		DrawRow(row, f)
	end
	for i = #flights + 1, #own.rows do own.rows[i]:Hide() end
	local none = not want and #flights == 0
	own.none:SetShown(none)
	if none then y = 30 end
	own.list.content:SetSize(L.list, math.max(1, y))
	stock:SetSize(L.list, math.max(1, y))
	own.list:Update()
end

-- The map's frame: the sheet set into its housing past the look's border (its widest side: the map stays square) and
-- L.frame of the housing, which is told where its content stands (a look with a well sinks it there, one with rivets
-- runs them round it). Looked at at each draw: a look's border may change with the theme or an option of the look's.
local function Frame()
	local h = own.map.shyLook
	local rim = math.max(UI.LookBorder(h)) + L.frame
	if rim == own.rim then return end
	own.rim = rim
	own.sheet:ClearAllPoints()
	own.sheet:SetPoint("TOPLEFT", rim, -rim)
	own.sheet:SetPoint("BOTTOMRIGHT", -rim, rim)
	UI.LookContent(h, { rim, rim, rim, rim })
end

-- The color a flight wears while it is the one shown (picked, or under the mouse): the guide's own for your guide's
-- flight, the travel color for any other.
local function Wears(f)
	return f.slot == visit.want and GUIDE or TRAVEL
end

-- The map: the whole of it; every point as a mark; the way of the one under the mouse (else the one
-- picked) drawn hop by hop, the points it passes marked small.
DrawMap = function()
	local side = own.side - 2 * own.rim - 2   -- (the art: inside the frame, and the sheet's hairline)
	local shown = Flight(hovered) or Flight(picked)
	local hops = shown and Hops(shown.slot) or NONE
	own.way = shown and Wears(shown) or nil
	local passed = {}
	for _, hop in ipairs(hops) do passed[hop[1]], passed[hop[2]] = true, true end

	local lift = own.pins:GetFrameLevel()
	local i = 0
	for _, f in ipairs(order) do
		local x, y = f.x, f.y
		local stop = f.kind == "DISTANT"
		if (not stop or passed[f.slot]) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			i = i + 1
			local mark = Mark(i)
			mark.flight = f
			local on = f.slot == picked
			local over = f.slot == hovered and f.kind == "REACHABLE"
			local size = stop and L.stop or on and L.picked or over and L.hovered or L.mark
			-- (At rest every flight is steel, your guide's too: its color is for while it is the one shown.)
			local color = stop and STEEL or f.kind == "CURRENT" and C.good or (on or over) and Wears(f) or STEEL
			mark.color, mark.lit = color, on or over
			mark:EnableMouse(not stop)
			mark:SetSize(size, size)
			mark:ClearAllPoints()
			mark:SetPoint("CENTER", own.pins, "TOPLEFT", x * side, -y * side)
			mark:SetFrameLevel(lift + (on and 3 or over and 2 or 1))
			mark:Set("flight", color, on or over)
			mark:Show()
		end
	end
	for j = i + 1, #own.marks do
		own.marks[j]:Hide()
		own.marks[j].flight = nil
	end

	local pen = own.pen
	Maps.Begin(pen, 1)
	for _, hop in ipairs(hops) do
		local a, b = spots[hop[1]], spots[hop[2]]
		if a and b then
			Maps.Segment(pen, a.x * side, a.y * side, b.x * side, b.y * side,
				L.route, 1, own.way, nil, Maps.JOURNEY)
		end
	end
	Maps.Finish(pen)
end

-- The foot: your gold, and Fly to the one picked: in the guide's color while that is your guide's flight, the plain
-- answer for any other.
DrawFoot = function()
	local gold = own.gold
	gold:SetText(UI.Money(GetMoney(), nil, 12, gold))
	local f = Flight(picked)
	local fly = own.fly
	fly:SetTone(f and f.slot == visit.want and GUIDE or nil)
	if f then
		fly.text:SetText(WORDS.fly:format(f.name))
		fly:SetUsable(f.cost <= GetMoney(), WORDS.noGold)
	else
		fly.text:SetText(WORDS.pick)
		fly:SetUsable(false)
	end
	own.shell:Answers({ fly }, Wide(gold) + 16)
end

Draw = function()
	local f = TaxiFrame
	Read()
	if not Flight(picked) then picked = nil end
	if hovered and not spots[hovered] then hovered = nil end

	local box = own.box
	local wide, tall = UI.BodySize(box)   -- (what it holds stands on its body: UI.Body)
	if issecretvalue(wide) or not wide or wide <= 0 then wide = L.w end
	if issecretvalue(tall) or not tall or tall <= 0 then tall = L.h end
	-- The game's own window, empty under ours, is as wide (up to the width ours is made at): what the game opens
	-- beside it stands clear of ours.
	Shop.Size(f, math.min(wide, L.w), f:GetHeight())

	DrawBand(wide)
	DrawList()
	local width = math.floor(wide - 4 - own.stageX - L.right)
	local room = tall - (UI.HEAD.window.line + UI.LINE) - WIN.band - WIN.foot - 6 - 2 * L.top
	own.stage:SetSize(math.max(60, width), math.max(60, room))
	own.side = math.floor(math.max(60, math.min(width, room)))
	own.map:SetSize(own.side, own.side)
	Frame()
	DrawMap()
	DrawFoot()
	desk:Motion()
end

Refresh = function()
	if not (M and M.on and own.box) then return end
	if TaxiFrame:IsShown() then Shop.Try(M, Draw) end
end

Stale = Shop.Later(function() Refresh() end)

-- The game's own buttons for the map's points: made on its window as the map opens, so put away then.
local function Away()
	local attic = Shop.AtticOf(TaxiFrame)
	for _, kid in ipairs({ TaxiFrame:GetChildren() }) do
		if kid ~= own.box and kid ~= attic and not kid:IsForbidden() then Shop.PutAway(TaxiFrame, kid) end
	end
end

-- A visit begins: the game's map art, what your guide asks for (picked as it opens, never taken for you), and the
-- opening.
local function Begin()
	wipe(visit)
	picked, hovered, clicked = nil, nil, nil
	Away()
	own.art:SetTexCoord(0, 1, 0, 1)
	SetTaxiMap(own.art)
	local quest = Shy.addons.Quest
	if quest and quest.Flight then
		local slot, whose = quest:Flight()
		visit.want, visit.whose, picked = slot, whose, slot
	end
	own.list:SetVerticalScroll(0)
	desk:Begin("npc")
	Refresh()
	-- (Again next frame: the times in the air are read from the map as it opens.)
	Stale()
end

local function EndVisit()
	wipe(visit)
	picked, hovered, clicked = nil, nil, nil
	if desk and desk.motion then desk:Rest() end
end

-- The module

local EVENTS = { "TAXIMAP_CLOSED", "TAXI_NODE_STATUS_CHANGED", "PLAYER_MONEY" }

local function Hook()
	TaxiFrame:HookScript("OnShow", function()
		if not (M.on and desk) then return end
		Shy.HUD.Update(own.box)
		Shop.Try(M, Begin)
	end)
	TaxiFrame:HookScript("OnHide", EndVisit)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function(_, event)
		if event == "TAXIMAP_CLOSED" then
			EndVisit()
		elseif M.on and TaxiFrame:IsShown() then
			Stale()
		end
	end)
end

local function Paint(m, kit)
	Shop.Try(m, function()
		if not desk then Build() end
		Shy.HUD.Update(own.box)
		Shop.Empty(kit, TaxiFrame, own.box)
		ns.Claim("flights", true)
		Refresh()
	end)
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	if desk then desk:Rest() end
	Shop.Refill(TaxiFrame)
	Shop.Unsize(TaxiFrame)
	ns.Claim("flights", false)
	if own.box then Shy.HUD.Update(own.box) end
end

M = ns.Module({
	id = "flights",
	title = "Flight master",
	desc = "The flight map becomes a window you can resize, with each flight's time, cost and route.",
	group = "rebuilt",
	words = "taxi flight path",
	Ready = function() return TaxiFrame ~= nil and Shop ~= nil and WIN ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,   -- exposed for inspection
})
