-- A quest you could take, as a page on the world map: what it asks for and what it gives, so the trip
-- to its giver can be weighed before it is made. A click on a pin that has quests to pick up (the "!" of
-- a giver, a place of the route, a step of the guide) keeps its ground lit, as it always did, and opens
-- this page beside it; a click on such a pin on the minimap opens the map there. The pin's hover names
-- the quests; the page says the rest:
--   the head     who gives them, where, how far; then how many quests, their XP together (and how much of
--                your level that is) and whether anything in them is an upgrade
--   each quest   its name in the color of its difficulty and its level; what it asks for, in its own
--                sentence (Data/Offers.lua, the server's word), else each thing the data has it ask for;
--                what it pays: XP as you would be paid it now, money, what it costs; the items it gives and
--                the ones to choose from, each with what it is and what ShyGear makes of it for you; a spell
--                it teaches; who takes it back where that isn't its giver; the quest it leads to; and, in
--                gold, why the route leaves it or what your guide does with it
--   the foot     the pin's right click as a button: head there first
-- It stands over the map's window (Shy.Maps.Over), at the canvas's top right, and is as tall as what it
-- says up to the map's height; past that it scrolls.
--
--   ns.Offer.Quests(stop) -> { { id, action, who } }   the quests picked up at a stop, in its order (who: their
--                                                 giver, on a pin of several); empty for none
--   ns.Offer.Content(stop) -> content or nil      what the page says (the tests read it)
--   ns.Offer.Follow(stop)                         the stop the map keeps lit (Pins.lua, at every laying of the
--                                                 map): its page shows, is filled again when what it says has
--                                                 changed, and goes when the stop has no quest to take or is nil
--   ns.Offer.Shown() -> stop or nil

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide
local UI = Shy.UI
local C = UI.colors

local Offer = {}
ns.Offer = Offer

local P = {
	wide = 372, pad = 14,          -- the page, and its content's inset
	head = 64, foot = 44,          -- the head (name, where, the tally) and the foot (the button)
	top = 40, edge = 12,           -- from the map's top and its right edge
	least = 120,                   -- the body is never shorter than this, however little room the map has
	row = 40, icon = 28, gap = 2,  -- an item's row
	mark = 18,                     -- a quest's mark before its name
	-- Its words' sizes. The page stands over the map at Shy.Maps.OVER of its size, as everything there does:
	-- these are a notch over the family's usual, so they read as the usual on the screen.
	title = 15, small = 12, name = 14, body = 13, quiet = 11, caps = 10, item = 13, what = 11,
	between = 12,                  -- from one quest to the rule before the next
	late = 0.15,                   -- seconds from an item coming in to the page being filled again
	most = 8,                      -- quests on one page; the rest are counted
}
local VERDICT = { later = "Later", same = "About the same", worse = "Worse than yours", cant = "Can't use" }
local DOT = "  \194\183  "

local page                   -- the frame, made when first asked for
local showing                -- the stop its page is up for
local said                   -- what the page was last filled from (Sig)
local asked = {}             -- items the page waits to hear of
local waiting = false

local function Gear()
	local gear = Shy.addons.Gear
	return gear and gear.Judge and gear or nil
end

-- What the page says ----------------------------------------------------------------------------------

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

-- What the route or the guide makes of a quest, where that is worth saying: in gold on the page.
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
--             more (quests past P.most), xp (all of them together), go (the foot's words) }
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
	-- The foot's button is the pin's right click (Pins.lua): the arrow for a step of the guide, the route
	-- for a quest's stop.
	if stop.kind == "guide" then
		content.go = "Point the way"
	else
		content.go = stop.chosen and "Let the route choose" or "Head here first"
	end
	return content
end

-- What a page is filled from, as one text: filled again only when this changes.
local function Sig(stop, quests)
	local out = { stop.key or "", stop.chosen and "c" or "", L.version or "", L.Level(), R.offGuide and "g" or "" }
	for _, one in ipairs(quests) do out[#out + 1] = one.id end
	return table.concat(out, ":")
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

-- The page ----------------------------------------------------------------------------------------------

-- What an item is, in a line: where it is worn and its kind ("Chest  ·  Mail"), or its kind alone.
local function What(kind, subKind, where)
	local slot = where and where ~= "" and _G[where] or nil
	if slot == "" then slot = nil end
	local what = subKind and subKind ~= "" and subKind ~= OTHER and subKind or nil
	if slot and what and what ~= slot then return slot .. DOT .. what end
	return slot or what or kind or ""
end

local function PaintRow(row)
	local data = row.data
	row.verdict:SetText("")
	row.arrow:Hide()
	row:SetAlpha(1)
	row.icon:SetDesaturated(false)
	if data.spell then
		local name = C_Spell.GetSpellName(data.spell)
		row.icon:SetTexture(C_Spell.GetSpellTexture(data.spell))
		row.name:SetText(name or "A spell")
		UI.Ink(row.name, C.head)
		row.slot:Quality(nil)
		row.sub:SetText("You learn it")
		row.link = nil
		return
	end
	local item = data.item
	local name, link, quality, _, _, kind, subKind, _, where, icon = C_Item.GetItemInfo(item)
	row.link = link
	local times = data.count > 1 and UI.Wrap(C.dim, "  x" .. data.count) or ""
	if not name then
		-- (Not told of yet: asked for, and painted again as the answer comes.)
		asked[item] = true
		C_Item.RequestLoadItemDataByID(item)
		row.icon:SetTexture(C_Item.GetItemIconByID(item))
		row.name:SetText((D.Item(item) or {}).name or "")
		UI.Ink(row.name, C.head)
		row.slot:Quality(nil)
		row.sub:SetText("")
		return
	end
	row.icon:SetTexture(icon)
	row.name:SetText(name .. times)
	local color = ITEM_QUALITY_COLORS[quality or 1]
	row.name:SetTextColor(color.r, color.g, color.b)
	row.slot:Quality(quality)
	-- What it is to you: an arrow and what you gain for an upgrade, a quiet word for the rest.
	local v = Verdict(item)
	local words, ink, arrow = "", C.dim, false
	if v then
		if v.kind == "upgrade" then
			local gear = Gear()
			words, ink, arrow = gear.Words and gear:Words(v) or "", C.good, true
			if words == "" then words = "Upgrade" end
		else
			words = VERDICT[v.kind] or ""
			if v.kind == "later" then ink = C.alert end
		end
	end
	local cant = v and v.kind == "cant"
	row.verdict:SetText(words)
	UI.Ink(row.verdict, ink)
	row.arrow:SetShown(arrow)
	row.icon:SetDesaturated(cant and true or false)
	row:SetAlpha(cant and 0.5 or 1)
	-- The verdict is said whole; what the item is has what is left of the line.
	local room = row.room
	local mark = arrow and 15 or 0
	local wide = words ~= "" and math.min(row.verdict:GetUnboundedStringWidth() + 2, room - mark - 60) or 0
	row.verdict:SetWidth(math.max(1, wide))
	row.sub:SetWidth(math.max(48, room - wide - mark - (wide > 0 and 10 or 0)))
	row.sub:SetText(What(kind, subKind, where))
end

local function MakeRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(P.row)
	UI.Skin(row, C.row, C.rowEdge)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(P.icon, P.icon)
	row.icon:SetPoint("LEFT", 6, 0)
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, hover = false })
	row.name = UI.Text(row, "", P.item, false, C.head)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, 0)
	row.name:SetWordWrap(false)
	row.sub = UI.Text(row, "", P.what, false, C.dim)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 9, 0)
	row.sub:SetWordWrap(false)
	row.verdict = UI.Text(row, "", P.what, false, C.dim)
	row.verdict:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, (P.row - P.icon) / 2)
	row.verdict:SetJustifyH("RIGHT")
	row.verdict:SetWordWrap(false)
	row.arrow = row:CreateTexture(nil, "ARTWORK")
	row.arrow:SetSize(10, 10)
	row.arrow:SetPoint("RIGHT", row.verdict, "LEFT", -5, 0)
	Shy.Hover.Glyph(row.arrow, "up", 10)
	UI.Tint(row.arrow, C.good)
	-- The game's own tooltip of the item or the spell, where every window's rows have it.
	row:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		local tip = UI.GameTipAt(self, self.icon)
		if self.data.spell then tip:SetSpellByID(self.data.spell) else tip:SetItemByID(self.data.item) end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.rowEdge)
		GameTooltip:Hide()
	end)
	-- A held key links it in chat or tries it on, as the game's own item buttons do.
	row:SetScript("OnClick", function(self)
		if self.link and IsModifiedClick() then HandleModifiedItemClick(self.link) end
	end)
	return row
end

-- Pools of what a page is laid from: taken in order from the first at each filling (Begin), the rest put
-- away after it (Done).
local function Pool(make)
	local pool = { used = 0 }
	function pool:Next()
		self.used = self.used + 1
		local one = self[self.used]
		if not one then
			one = make()
			self[self.used] = one
		end
		one:ClearAllPoints()
		one:Show()
		return one
	end
	function pool:Begin()
		self.used = 0
	end
	function pool:Done()
		for i = self.used + 1, #self do self[i]:Hide() end
	end
	return pool
end

local function Build()
	local container = Shy.Maps.Canvas():GetCanvasContainer()
	page = CreateFrame("Frame", nil, container)
	page:SetFrameStrata("HIGH")
	page:SetWidth(P.wide)
	Shy.Maps.Over(page, "TOPRIGHT", -P.edge, -P.top)
	UI.Panel(page, { brackets = false })
	-- (Its own ground under the mouse: a click meant for the page never falls through to the map.)
	page:EnableMouse(true)
	page:Hide()

	-- The head: the stop's mark and name, where it is and how far, and the tally.
	page.mark = ns.CreateMark(page, 26)
	page.mark:SetPoint("TOPLEFT", P.pad, -P.pad + 1)
	page.close = UI.Close(page, 18, nil, function() Offer.Close() end)
	page.close:SetPoint("TOPRIGHT", -7, -7)
	page.title = UI.Text(page, "", P.title, true, C.head)
	page.title:SetPoint("TOPLEFT", page.mark, "TOPRIGHT", 8, 1)
	page.title:SetPoint("RIGHT", page.close, "LEFT", -6, 0)
	page.title:SetWordWrap(false)
	page.where = UI.Text(page, "", P.small, false, C.dim)
	page.where:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -2)
	page.where:SetPoint("RIGHT", page, "RIGHT", -P.pad, 0)
	page.where:SetWordWrap(false)
	page.tally = UI.Text(page, "", P.small, false, C.text)
	page.tally:SetPoint("TOPLEFT", page, "TOPLEFT", P.pad, -(P.head - 17))
	page.tally:SetPoint("RIGHT", page, "RIGHT", -P.pad, 0)
	page.tally:SetWordWrap(false)
	page.rule = page:CreateTexture(nil, "ARTWORK")
	page.rule:SetHeight(1)
	page.rule:SetPoint("TOPLEFT", P.pad, -P.head - 3)
	page.rule:SetPoint("TOPRIGHT", -P.pad, -P.head - 3)
	UI.Paint(page.rule, C.border, 0.7)

	-- The body: every quest, down a scrolling column.
	page.scroll = UI.ScrollArea(page, P.wide - P.pad * 2 + 8, P.least, { smooth = true })
	page.scroll:SetPoint("TOPLEFT", P.pad, -P.head - 10)
	local body = page.scroll.content
	page.body = body
	page.wide = P.wide - P.pad * 2 - 6     -- what a line of the body has
	body:SetWidth(page.wide)

	page.texts = Pool(function()
		local text = UI.Text(body, "", P.body, false, C.text)
		text:SetJustifyV("TOP")
		return text
	end)
	page.marks = Pool(function() return ns.CreateMark(body, P.mark) end)
	page.rows = Pool(function() return MakeRow(body) end)
	page.rules = Pool(function()
		local rule = body:CreateTexture(nil, "ARTWORK")
		rule:SetHeight(1)
		UI.Paint(rule, C.border, 0.5)
		return rule
	end)

	page.pools = { page.texts, page.marks, page.rows, page.rules }

	-- The foot: the pin's right click, as a button.
	page.go = UI.Button(page, "", P.wide - P.pad * 2, function()
		local stop = showing
		if not stop then return end
		if stop.kind == "guide" then ns.PointTheWay(stop) else R.Go(stop) end
	end)
	page.go:SetPoint("BOTTOM", 0, P.pad - 2)
	page.go:SetPrimary(true)
end

-- A line of words down the body at y: sized, inked and wrapped to the body's width. Returns the y under it.
local function Line(y, words, size, color, x, wide, brand)
	local text = page.texts:Next()
	if brand then Shy.Theme.Face(text, size) else text:SetFont((GameFontHighlight:GetFont()), size, "") end
	UI.Ink(text, color or C.text)
	text:SetWordWrap(true)
	text:SetJustifyH("LEFT")
	text:SetWidth(wide or (page.wide - (x or 0)))
	text:SetText(words)
	text:SetPoint("TOPLEFT", page.body, "TOPLEFT", x or 0, -y)
	return y + math.ceil(text:GetStringHeight()), text
end

local function Heading(y, words)
	return (Line(y + 9, words, P.caps, C.dim)) + 5
end

local function Rows(y, list, spell)
	for _, each in ipairs(list) do
		local row = page.rows:Next()
		row.data = spell and { spell = each } or each
		row:SetPoint("TOPLEFT", page.body, "TOPLEFT", 0, -y)
		row:SetWidth(page.wide)
		row.room = page.wide - 6 - P.icon - 9 - 8
		row.name:SetWidth(row.room)
		PaintRow(row)
		y = y + P.row + P.gap
	end
	return y
end

-- Where a stop is and how far, for the line under its name.
local function Place(where, far)
	if where and far and far ~= "" then return where .. DOT .. UI.Wrap(C.hot, far) end
	return where or far or ""
end

local function Fill(content)
	local body = page.body
	for _, pool in ipairs(page.pools) do pool:Begin() end
	wipe(asked)

	page.mark:Set(content.kind, true, nil, content.tone)
	page.title:SetText(content.title)
	page.where:SetText(Place(content.where, content.far))
	page.tally:SetText(Offer.Tally(content))
	page.go:SetLabel(content.go)

	local y = 2
	for index, quest in ipairs(content.quests) do
		if index > 1 then
			local rule = page.rules:Next()
			rule:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + P.between / 2))
			rule:SetWidth(page.wide)
			y = y + P.between + 1
		end
		-- Its mark and name, its level at the line's end.
		local mark = page.marks:Next()
		mark:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
		mark:Set("pickup")
		local level = quest.level > 0 and ("Level " .. quest.level) or ""
		local _, right = Line(y + 2, level, P.quiet, C.dim, page.wide - 64, 64)
		right:SetJustifyH("RIGHT")
		y = Line(y, quest.name, P.name, quest.color, P.mark + 6, page.wide - P.mark - 6 - 68, true)
		y = math.max(y, 0) + 2
		if quest.giver then y = Line(y, quest.giver, P.quiet, C.dim, P.mark + 6) + 2 end
		if quest.tags then y = Line(y, quest.tags, P.quiet, C.dim, P.mark + 6) + 2 end
		if quest.from then y = Line(y, quest.from, P.small, C.alert) + 2 end
		-- What it asks for.
		y = y + 3
		if quest.says then
			y = Line(y, quest.says, P.body, C.text)
		else
			for _, words in ipairs(quest.asks or {}) do y = Line(y, words, P.body, C.text) + 1 end
		end
		-- What it pays, on one line: the XP, the money. Under it, quiet, how much of its XP that is.
		local pays = {}
		if quest.xp then pays[#pays + 1] = UI.Wrap(C.alert, ("+%s XP"):format(BreakUpLargeNumbers(quest.xp))) end
		if quest.money then pays[#pays + 1] = UI.Money(quest.money, false, P.body) end
		if #pays > 0 then
			y = Line(y + 7, table.concat(pays, DOT), P.body, C.text)
			if quest.share and quest.xp then y = Line(y + 1, ("%d%% of its XP at your level"):format(quest.share), P.quiet, C.dim) end
		end
		if quest.cost then y = Line(y + 4, "Costs " .. UI.Money(quest.cost, false, P.body), P.body, C.alert) end
		if #quest.choices > 0 then y = Rows(Heading(y, #quest.choices > 1 and "CHOOSE ONE" or "YOU GET"), quest.choices) end
		if #quest.items > 0 then y = Rows(Heading(y, #quest.choices > 1 and "AND YOU GET" or "YOU GET"), quest.items) end
		if quest.spell then y = Rows(Heading(y, "TEACHES"), { quest.spell }, true) end
		-- Where it goes from here.
		local onward = {}
		if quest.back then
			onward[#onward + 1] = "Hand in to " .. UI.Wrap(C.text, quest.back) .. (quest.zone and (", " .. quest.zone) or "")
		end
		if quest.opens then onward[#onward + 1] = "Leads to " .. UI.Wrap(C.text, quest.opens) end
		for i, words in ipairs(onward) do y = Line(y + (i == 1 and 8 or 2), words, P.small, C.dim) end
		if quest.note then y = Line(y + 8, quest.note, P.small, C.alert) end
	end
	if content.more > 0 then
		y = Line(y + P.between, ("and %d more quest%s here"):format(content.more, content.more == 1 and "" or "s"), P.small, C.dim)
	end
	y = y + 4
	for _, pool in ipairs(page.pools) do pool:Done() end

	-- As tall as what it says, up to the room the map leaves under it.
	local container = page:GetParent()
	local room = (container:GetHeight() or 0) / Shy.Maps.OVER - P.top - P.edge - P.head - 10 - P.foot
	local tall = math.max(math.min(y, math.max(room, P.least)), 1)
	body:SetHeight(y)
	page.scroll:SetHeight(tall)
	page:SetHeight(P.head + 10 + tall + P.foot)
	page.scroll:Update()
end

-- The game told of an item the page was waiting for: filled again, once a moment.
local function Late()
	if waiting then return end
	waiting = true
	C_Timer.After(P.late, function()
		waiting = false
		if showing and page and page:IsShown() then
			local content = Offer.Content(showing)
			if content then Fill(content) end
		end
	end)
end

function Offer.Shown()
	return page and page:IsShown() and showing or nil
end

-- The page's x: the pin is let go of, on both maps (Pins.lua), and the page goes with it.
function Offer.Close()
	if ns.LetGo then ns.LetGo() else Offer.Follow(nil) end
end

function Offer.Follow(stop)
	local quests = stop and Offer.Quests(stop)
	if not quests or #quests == 0 then
		showing, said = nil, nil
		if page then page:Hide() end
		return
	end
	-- (Asked at every laying of the map and every pin the mouse crosses: the same page is left as it is,
	-- but for how far it is.)
	local sig = Sig(stop, quests)
	if showing and sig == said and page and page:IsShown() then
		showing = stop
		page.where:SetText(Place(Where(stop), stop.yards and W.Far(stop) or nil))
		return
	end
	local content = Offer.Content(stop)
	if not content then return end
	if not page then Build() end
	if sig ~= said then page.scroll:SetVerticalScroll(0) end
	showing, said = stop, sig
	Fill(content)
	page:Show()
end

Shy:On("SHY_LOGIN", function()
	local events = CreateFrame("Frame")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:SetScript("OnEvent", function(_, _, item)
		if item and asked[item] then Late() end
	end)
	-- ShyGear's verdicts may have changed (gear put on, a build picked): the rows and the tally say them.
	Shy:On("SHY_GEAR", function()
		if Offer.Shown() then Late() end
	end)
end)
