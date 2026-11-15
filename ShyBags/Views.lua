-- The side panels of the window (gold, search results, mail, auctions, make room): their data and their rows.
--   Views.Gold()            { hand, mail, sold, today, week, ever, rows = { { guid, char, hand, mail, sold, note } } }
--   Views.Results(text)     { { item, id, name, quality, total, places = n, chips = { { who, class, text, soon } } } }
--   Views.Left(when)        "2 days left", and whether that is soon

local ADDON, ns = ...
local Store = ns.Store

local Views = {}
ns.Views = Views

local SOON = 3 * 86400

local function Count(n, one)
	return n .. " " .. one .. (n == 1 and "" or "s")
end

function Views.Left(when)
	local left = when - ns.Now()
	if left <= 0 then return "gone", true end
	if left < 3600 then return "under an hour left", true end
	if left < 86400 then return Count(math.floor(left / 3600), "hour") .. " left", true end
	return Count(math.floor(left / 86400), "day") .. " left", left < SOON
end

function Views.Gold()
	local me = Store.Me()
	local realm = me and me.realm
	local out = { hand = 0, mail = 0, sold = 0, today = 0, week = 0, ever = 0, rows = {} }
	for _, entry in ipairs(Store.List()) do
		local c = entry.char
		if c.realm == realm and not c.skip then
			local mail, sold = ns.Ledger.Waiting(c)
			local row = { guid = entry.guid, char = c, hand = c.money or 0, mail = mail, sold = sold }
			if not c.mail and not c.auctions then
				row.note = "mailbox and auctions not scanned yet"
			elseif not c.mail then
				row.note = "mailbox not scanned yet"
			end
			out.rows[#out.rows + 1] = row
			out.hand, out.mail, out.sold = out.hand + row.hand, out.mail + mail, out.sold + sold
			out.today = out.today + (ns.Ledger.Made(c, 1))
			out.week = out.week + (ns.Ledger.Made(c, 7))
			out.ever = out.ever + (ns.Ledger.Made(c))
		end
	end
	return out
end

local WHERE = { bags = "bags", keys = "keys", bank = "bank", mail = "mail", auction = "auction" }

local function Chip(place)
	local c = place.char
	local chip = { who = c and Store.Name(c) or "?", class = c and c.class, guid = place.guid, source = place.source }
	local text = WHERE[place.source] .. " " .. place.count
	if (place.source == "mail" or place.source == "auction") and place.exp then
		local left, soon = Views.Left(place.exp)
		text, chip.soon = text .. " \194\183 " .. left, soon
	elseif place.at and not (place.guid == Store.Guid() and (place.source == "bags" or place.source == "keys")) then
		text = text .. " \194\183 " .. ns.Ago(place.at)
	end
	chip.text = text
	return chip
end

function Views.Results(text)
	local rows = ns.Search.Run(text)
	for _, row in ipairs(rows) do
		row.chips = {}
		for index, place in ipairs(row.places) do row.chips[index] = Chip(place) end
		row.summary = row.total .. " in " .. Count(#row.places, "place")
	end
	return rows
end

-- Wings: each a list panel beside the bags, built and shown by Window.lua.
--   wing.Build(parent)
--   wing.Show(c, guid, isMe, rows) returns width, title, detail, right

local UI = Shy.UI
local C = UI.colors
local WIDTH = 256

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

-- Player names need a font family covering every alphabet.
local function Name(parent, size)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(UI.NameFont(size or 12))
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end
local STEP = 42   -- one row of slots with its gap; must match the window's grid

Views.Wings = {}
Views.query = ""   -- the search text, set by Window.lua
Views.test = nil

local function Rounded(parent, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(Shy.FONT_ROUNDED, size, "")
	UI.Ink(fs, color or C.text)
	return fs
end

local function ClassColor(fs, class)
	local color = class and C_ClassColor.GetClassColor(class)
	if color then fs:SetTextColor(color.r, color.g, color.b) else UI.Ink(fs, C.text) end
end

local function QualityColor(fs, quality)
	local color = quality and ColorManager.GetColorDataForItemQuality(quality)
	if color then fs:SetTextColor(color.r, color.g, color.b) else UI.Ink(fs, C.text) end
end

local function Icon(id)
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(id or 0)
	return icon
end

-- A small item icon with its count.
local function Pic(parent)
	local pic = parent:CreateTexture(nil, "ARTWORK")
	pic:SetSize(17, 17)
	pic.count = Rounded(parent, 9)
	pic.count:SetFont(Shy.FONT_ROUNDED, 9, "OUTLINE")
	pic.count:SetPoint("BOTTOMRIGHT", pic, "BOTTOMRIGHT", 2, -2)
	function pic:Set(id, count)
		self:SetTexture(Icon(id))
		self:SetShown(id ~= nil)
		self.count:SetText((count and count > 1) and count or "")
		self.count:SetShown(id ~= nil)
	end
	return pic
end

-- A panel with a list and an empty-state line.
local function Shell(parent, rowHeight, make, fill)
	local plate = CreateFrame("Frame", nil, parent)
	plate:SetAllPoints(parent)
	UI.Skin(plate, C.bg, C.border)
	plate:Hide()
	plate.none = UI.Text(plate, "", 11, false, C.dim)
	plate.none:SetPoint("TOPLEFT", 10, -8)
	plate.none:SetWidth(WIDTH - 20)
	plate.none:SetWordWrap(true)
	plate.list = ns.Rows.New(plate, rowHeight, make, fill)
	plate.list:SetPoint("TOPLEFT", 6, -3)
	plate.list:SetPoint("RIGHT", plate, "RIGHT", -3, 0)
	plate.rowHeight = rowHeight
	-- none: the empty-state text; head: height reserved above the list.
	function plate:List(things, none, rows, head)
		self.none:SetText(#things == 0 and none or "")
		self.list:SetShownRows(math.max(1, math.floor((rows * STEP - 5 - 6 - (head or 0)) / self.rowHeight)))
		self.list:SetThings(things)
	end
	return plate
end

local function Parted(row)
	local line = row:CreateTexture(nil, "BACKGROUND")
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	UI.Paint(line, C.border, 0.65)
end

local function Seen(source)
	return (source and source.at) and ("seen " .. ns.Ago(source.at)) or ""
end

-- True when a search is active and none of the slots match it.
local function Misses(slots, guid, source)
	local test = Views.test
	if not test then return false end
	for _, slot in ipairs(slots) do
		local item = ns.Marks.Remembered(slot, guid, source)
		if item and test(item) then return false end
	end
	return true
end

-- Mail
do
	local wing, plate, owner = {}, nil, nil
	Views.Wings.mail = wing

	local function Make(row)
		Parted(row)
		row.left = Rounded(row, 10.5, C.dim)
		row.left:SetPoint("TOPRIGHT", 0, -5)
		row.from = Name(row, 12)
		row.from:SetPoint("TOPLEFT", 0, -4)
		row.from:SetPoint("TOPRIGHT", row.left, "TOPLEFT", -6, 1)
		row.subject = UI.Text(row, "", 10.5, false, C.dim)
		row.subject:SetPoint("BOTTOMLEFT", 0, 6)
		row.subject:SetWidth(120)
		row.subject:SetWordWrap(false)
		row.gold = Rounded(row, 10.5)
		row.gold:SetPoint("BOTTOMRIGHT", 0, 6)
		row.pics = {}
		for i = 1, 4 do
			row.pics[i] = Pic(row)
			row.pics[i]:SetPoint("BOTTOMRIGHT", row.gold, "BOTTOMLEFT", -4 - (i - 1) * 20, -3)
			-- (The quest's mark on what a letter holds, as on a slot: Marks.lua's word for it.)
			row.pics[i].pin = Shy.Slot.Pin(row, row.pics[i], "TOPRIGHT", 10)
		end
	end

	-- What a letter holds, as { item, count, mark } each: what a quest needs first (now, then later), so it is
	-- among the few pictures a row has room for.
	local RANK = { quest = 1, needed = 1, starter = 1, ahead = 2 }
	local function Held(mail)
		local out = {}
		for i, slot in ipairs(mail.items) do
			local item, count = ns.Store.Unpack(slot)
			local known = ns.Marks.Remembered(slot, owner.guid, "mail")
			local hit = known and ns.Marks.For(known).tr
			out[i] = { id = item and ns.Store.ItemID(item), count = count, mark = hit and hit.id or nil, at = i }
		end
		table.sort(out, function(a, b)
			local ra, rb = RANK[a.mark] or 3, RANK[b.mark] or 3
			if ra ~= rb then return ra < rb end
			return a.at < b.at
		end)
		return out
	end

	local function Fill(row, mail)
		row.from:SetText(mail.from ~= "" and mail.from or "The game")
		if mail.sent then ClassColor(row.from, ns.Store.Me() and ns.Store.Me().class) else UI.Ink(row.from, C.text) end
		if mail.sent then
			row.left:SetText("sent by you, not seen arriving yet")
			UI.Ink(row.left, C.dim)
		else
			local left, soon = Views.Left(mail.exp)
			row.left:SetText(left)
			UI.Ink(row.left, soon and C.alert or C.dim)
		end
		row.subject:SetText(mail.subj)
		row.gold:SetText(mail.money > 0 and Coins(mail.money) or "")
		local held = Held(mail)
		for i, pic in ipairs(row.pics) do
			local one = held[i]
			pic:Set(one and one.id, one and one.count)
			pic.pin:Set(one and one.id and Shy.Slot.PINS[one.mark] and one.mark or nil)
		end
		row:SetAlpha(Misses(mail.items, owner.guid, "mail") and 0.3 or 1)
	end

	function wing.Build(parent)
		plate = Shell(parent, 41, Make, Fill)
		wing.frame = plate
	end

	function wing.Show(c, guid, _, rows)
		owner = { char = c, guid = guid }
		local list = c.mail and c.mail.rows or {}
		local none = c.mail and "The mailbox was empty."
			or ("Mailbox not scanned yet. Open a mailbox on " .. ns.Store.Name(c) .. " once.")
		plate:List(list, none, rows)
		return WIDTH, "Mail", Count(#list, "letter"), Seen(c.mail)
	end
end

-- Auctions
do
	local wing, plate, owner = {}, nil, nil
	Views.Wings.auctions = wing

	local function Make(row)
		row.pic = Pic(row)
		row.pic:SetPoint("LEFT", 0, 0)
		row.state = Rounded(row, 10.5, C.dim)
		row.state:SetPoint("RIGHT", 0, 0)
		row.name = UI.Text(row, "", 12, true)
		row.name:SetPoint("LEFT", row.pic, "RIGHT", 6, 0)
		row.name:SetPoint("RIGHT", row.state, "LEFT", -6, 0)
		row.name:SetWordWrap(false)
	end

	local function Fill(row, auction)
		local id = ns.Store.ItemID(auction.item)
		local quality, _, _, name = ns.Store.Fact(id or 0)
		row.pic:Set(id, auction.n)
		row.name:SetText(name or ("item " .. tostring(id)))
		QualityColor(row.name, quality)
		local price = auction.buyout or auction.bid or 0
		local gone = not auction.sold and auction.exp ~= nil and auction.exp <= ns.Now()
		if auction.sold then
			row.state:SetText("sold, " .. Coins(price) .. " on its way")
			UI.Ink(row.state, C.alert)
		elseif gone then
			row.state:SetText("expired, in the mailbox")
			UI.Ink(row.state, C.dim)
		else
			row.state:SetText(Coins(price) .. (auction.exp and ("  " .. Views.Left(auction.exp)) or ""))
			UI.Ink(row.state, C.text)
		end
		local miss = Misses({ ns.Store.Pack(auction.item, auction.n) }, owner.guid, "auction")
		row:SetAlpha(miss and 0.3 or (gone and 0.55 or 1))
	end

	function wing.Build(parent)
		plate = Shell(parent, 22, Make, Fill)
		wing.frame = plate
	end

	function wing.Show(c, guid, _, rows)
		owner = { char = c, guid = guid }
		local list, up, sold = {}, 0, 0
		for _, auction in ipairs(c.auctions or {}) do
			list[#list + 1] = auction
			if auction.sold then sold = sold + 1 else up = up + 1 end
		end
		local none = c.auctions and "No auctions."
			or ("Auctions not scanned yet. Visit an auctioneer on " .. ns.Store.Name(c) .. " once.")
		plate:List(list, none, rows)
		local detail = up .. " up" .. (sold > 0 and (", " .. Shy.Theme.Wrap(C.alert, sold .. " sold")) or "")
		return WIDTH, "Auctions", detail, Seen(c.auctions)
	end
end

-- Gold
do
	local wing, plate = {}, nil
	Views.Wings.gold = wing

	local GOLD = 360                       -- the wing's width
	local HAND, SOLD, MAIL = 86, 80, 70    -- column widths, from the right
	local HEAD, FOOT = 40, 24              -- height above the rows (total, headings) and below (AH income)

	local function Column(parent, size, color, right, width)
		local fs = Rounded(parent, size, color)
		fs:SetPoint("RIGHT", parent, "RIGHT", -right, 0)
		fs:SetWidth(width)
		fs:SetJustifyH("RIGHT")
		fs:SetWordWrap(false)
		return fs
	end

	local function Make(row)
		row:EnableMouse(true)
		row.fill = row:CreateTexture(nil, "BACKGROUND")
		row.fill:SetAllPoints()
		UI.Paint(row.fill, C.row)
		row.fill:Hide()
		row.hand = Column(row, 10.5, C.text, 2, HAND)
		row.sold = Column(row, 10.5, C.alert, 2 + HAND, SOLD)
		row.mail = Column(row, 10.5, C.alert, 2 + HAND + SOLD, MAIL)
		row.note = Column(row, 10, C.dim, 2 + HAND, SOLD + MAIL)
		row.name = Name(row, 12)
		row.name:SetPoint("LEFT", 2, 0)
		row.name:SetPoint("RIGHT", row.mail, "LEFT", -6, 0)
		row:SetScript("OnEnter", function(self)
			self.fill:Show()
			if not self.guid then return end
			local c = Store.Char(self.guid)
			UI.Tip(self, c and Store.Name(c) or "A character", self.unseen
				and "Mail and auctions show after this character opens a mailbox and visits an auctioneer." or nil,
				{ side = "RIGHT", hints = { { "left", "Show bags" } } })
		end)
		row:SetScript("OnLeave", function(self)
			self.fill:Hide()
			UI.TipHide(self)
		end)
		row:SetScript("OnMouseUp", function(self)
			if self.guid then ns.Window.Look(self.guid) end
		end)
	end

	local function Fill(row, entry)
		local c = entry.char
		row.guid, row.unseen = entry.guid, entry.note ~= nil
		row.name:SetText(ns.Store.Name(c))
		ClassColor(row.name, c.class)
		row.hand:SetText(Coins(entry.hand))
		row.mail:SetText(entry.mail > 0 and Coins(entry.mail) or "")
		row.sold:SetText(entry.sold > 0 and Coins(entry.sold) or "")
		row.note:SetText((entry.note and entry.mail + entry.sold == 0) and "not scanned yet" or "")
	end

	local function Line(parent, point, y)
		local rule = parent:CreateTexture(nil, "ARTWORK")
		rule:SetPoint(point .. "LEFT", 6, y)
		rule:SetPoint(point .. "RIGHT", -6, y)
		rule:SetHeight(1)
		UI.Paint(rule, C.border, 0.65)
	end

	function wing.Build(parent)
		plate = Shell(parent, 16, Make, Fill)
		wing.frame = plate
		plate.none:SetWidth(GOLD - 20)
		plate.list:ClearAllPoints()
		plate.list:SetPoint("TOPLEFT", 6, -HEAD)
		plate.list:SetPoint("RIGHT", plate, "RIGHT", -3, 0)

		plate.realm = Rounded(plate, 9, C.dim)
		plate.realm:SetPoint("TOPLEFT", 8, -8)
		plate.realm:SetText("ON THIS REALM")
		plate.total = Rounded(plate, 12)
		plate.total:SetPoint("LEFT", plate.realm, "RIGHT", 8, 0)
		plate.waiting = Rounded(plate, 10.5, C.alert)
		plate.waiting:SetPoint("TOPRIGHT", -8, -7)
		Line(plate, "TOP", -22)

		-- Insets match the list's: 6 left, 9 right (scroll thumb included).
		local heads = CreateFrame("Frame", nil, plate)
		heads:SetPoint("TOPLEFT", 6, -25)
		heads:SetPoint("TOPRIGHT", -9, -25)
		heads:SetHeight(12)
		Column(heads, 8.5, C.dim, 2, HAND):SetText("IN HAND")
		Column(heads, 8.5, C.dim, 2 + HAND, SOLD):SetText("SOLD, UNPAID")
		Column(heads, 8.5, C.dim, 2 + HAND + SOLD, MAIL):SetText("IN MAIL")

		Line(plate, "BOTTOM", 20)
		plate.sums = Rounded(plate, 10)
		plate.sums:SetPoint("BOTTOMLEFT", 8, 6)
	end

	function wing.Show(_, _, _, rows)
		local gold = Views.Gold()
		local waiting = gold.mail + gold.sold
		plate.total:SetText(Coins(gold.hand))
		plate.waiting:SetText(waiting > 0 and ("+ " .. Coins(waiting) .. " waiting") or "")
		local dim = function(text) return Shy.Theme.Wrap(C.dim, text) end
		plate.sums:SetText(dim("AUCTIONS MADE   today ") .. Coins(gold.today) .. dim("    7 days ") .. Coins(gold.week) .. dim("    all time ") .. Coins(gold.ever))
		plate:List(gold.rows, "No characters on this realm yet.", rows, HEAD + FOOT - 3)
		return GOLD, "Gold", Count(#gold.rows, "character"), ""
	end
end

-- Search results: a row per item, then a line per place it is in
do
	local wing, plate = {}, nil
	Views.Wings.results = wing

	local function Make(row)
		row.pic = Pic(row)
		row.pic:SetPoint("LEFT", 0, 0)
		row.right = Rounded(row, 10.5, C.dim)
		row.right:SetPoint("RIGHT", 0, 0)
		row.name = UI.Text(row, "", 12, true)
		row.name:SetPoint("LEFT", 23, 0)
		row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
		row.name:SetWordWrap(false)
		row.who = Name(row, 11)
		row.who:SetPoint("LEFT", 23, 0)
		row.where = Rounded(row, 10.5, C.dim)
		row.where:SetPoint("LEFT", row.who, "RIGHT", 5, 0)
	end

	local function Fill(row, line)
		local head = line.chip == nil
		row.pic:Set(head and line.id or nil)
		row.name:SetShown(head)
		row.right:SetShown(head)
		row.who:SetShown(not head)
		row.where:SetShown(not head)
		if head then
			row.name:SetText(line.name)
			QualityColor(row.name, line.quality)
			row.right:SetText(line.summary)
		else
			row.who:SetText(line.chip.who)
			ClassColor(row.who, line.chip.class)
			row.where:SetText(line.chip.text)
			UI.Ink(row.where, line.chip.soon and C.alert or C.dim)
		end
	end

	function wing.Build(parent)
		plate = Shell(parent, 18, Make, Fill)
		wing.frame = plate
	end

	function wing.Show(_, _, _, rows)
		local found = Views.Results(Views.query)
		local lines = {}
		for _, row in ipairs(found) do
			lines[#lines + 1] = row
			for _, chip in ipairs(row.chips) do lines[#lines + 1] = { chip = chip } end
		end
		plate:List(lines, Views.query == "" and "Type to search every character." or "No matches.", rows)
		return WIDTH, "Results", Count(#found, "item"), ""
	end
end

-- Make room: what Room.lua says can go, cheapest first
do
	local wing, plate = {}, nil
	Views.Wings.room = wing
	local HEAD = 36   -- height above the rows: two lines and a rule

	local function Make(row)
		row:EnableMouse(true)
		row.fill = row:CreateTexture(nil, "BACKGROUND")
		row.fill:SetAllPoints()
		UI.Paint(row.fill, C.row)
		row.fill:Hide()
		row.lead = row:CreateTexture(nil, "ARTWORK")
		row.lead:SetPoint("TOPLEFT", 0, -2)
		row.lead:SetPoint("BOTTOMLEFT", 0, 2)
		row.lead:SetWidth(2)
		UI.Paint(row.lead, C.alert)
		row.pic = Pic(row)
		row.pic:SetPoint("LEFT", 6, 0)
		row.worth = Rounded(row, 10.5)
		row.worth:SetPoint("RIGHT", -2, 0)
		row.name = UI.Text(row, "", 12, true)
		row.name:SetPoint("LEFT", row.pic, "RIGHT", 6, 0)
		row.name:SetPoint("RIGHT", row.worth, "LEFT", -6, 0)
		row.name:SetWordWrap(false)
		row:SetScript("OnEnter", function(self)
			self.fill:Show()
			local entry = self.entry
			if not entry then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetBagItem(entry.bag, entry.slot)
			GameTooltip:Show()
			if ns.Window.Point then ns.Window.Point(entry.bag, entry.slot) end
		end)
		row:SetScript("OnLeave", function(self)
			self.fill:Hide()
			GameTooltip:Hide()
			if ns.Window.Point then ns.Window.Point(nil) end
		end)
	end

	local function Fill(row, entry)
		row.entry = entry
		row.pic:Set(entry.id, entry.count)
		row.name:SetText(entry.name or ("item " .. tostring(entry.id)))
		QualityColor(row.name, entry.quality)
		row.worth:SetText(ns.Room.Coins(entry.value))
		row.lead:SetShown(entry.lead == true)
		row:SetAlpha(entry.lit and 1 or 0.45)
	end

	-- What Drop takes: the cheapest lit item of those that have to go for the room asked, else the cheapest lit one.
	local function Next()
		local things = ns.Room.Told()
		for _, entry in ipairs(things) do
			if entry.lead then return entry end
		end
		for _, entry in ipairs(things) do
			if entry.lit then return entry end
		end
	end

	-- One press drops it: picked out of its slot (still the item listed) and destroyed. Nothing to drag to the world.
	local function Drop()
		local entry = Next()
		if not entry or C_Container.GetContainerItemID(entry.bag, entry.slot) ~= entry.id then return end
		ClearCursor()
		C_Container.PickupContainerItem(entry.bag, entry.slot)
		local kind, id = GetCursorInfo()
		if kind == "item" and id == entry.id then DeleteCursorItem() else ClearCursor() end
	end

	local DROP = { w = 50, h = 20 }   -- the Drop key in the head

	function wing.Build(parent)
		plate = Shell(parent, 20, Make, Fill)
		wing.frame = plate
		plate.none:ClearAllPoints()
		plate.none:SetPoint("TOPLEFT", 10, -(HEAD + 4))
		plate.list:ClearAllPoints()
		plate.list:SetPoint("TOPLEFT", 6, -HEAD)
		plate.list:SetPoint("RIGHT", plate, "RIGHT", -3, 0)
		plate.drop = UI.Button(plate, "Drop", DROP.w, Drop)
		plate.drop:SetHeight(DROP.h)
		plate.drop:SetPoint("TOPRIGHT", -6, -(HEAD - DROP.h) / 2 + 1)
		-- Which item it takes, lit in the bags and named, while the mouse is on it.
		plate.drop:HookScript("OnEnter", function(self)
			local entry = Next()
			if not entry then return end
			if ns.Window.Point then ns.Window.Point(entry.bag, entry.slot) end
			UI.Tip(self, "Drop", ("Destroys %s."):format(entry.name or "it"), { side = "TOP" })
		end)
		plate.drop:HookScript("OnLeave", function(self)
			if ns.Window.Point then ns.Window.Point(nil) end
			UI.TipHide(self)
		end)
		-- One line each, never wrapped: another addon's reason is cut at the wing's edge.
		plate.why = UI.Text(plate, "", 12, true, C.alert)
		plate.why:SetPoint("TOPLEFT", 8, -6)
		plate.why:SetWidth(WIDTH - 16 - DROP.w - 6)
		plate.why:SetJustifyH("LEFT")
		plate.why:SetWordWrap(false)
		plate.how = Rounded(plate, 10.5, C.dim)
		plate.how:SetPoint("TOPLEFT", 8, -20)
		plate.how:SetWidth(WIDTH - 16 - DROP.w - 6)
		plate.how:SetJustifyH("LEFT")
		plate.how:SetWordWrap(false)
		local rule = plate:CreateTexture(nil, "ARTWORK")
		rule:SetPoint("TOPLEFT", 6, -(HEAD - 3))
		rule:SetPoint("TOPRIGHT", -6, -(HEAD - 3))
		rule:SetHeight(1)
		UI.Paint(rule, C.border, 0.65)
	end

	function wing.Show(_, _, _, rows)
		local room = ns.Room
		if not room then
			plate:List({}, "", rows, HEAD)
			return WIDTH, "Make room", "", ""
		end
		local things, why, how, pressing, lit = room.Told()
		plate.why:SetText(why)
		plate.how:SetText(how)
		UI.Ink(plate.how, pressing and C.alert or C.dim)
		plate:List(things, "Nothing is safe to drop: it's all quest items, soulbound, in use or worth more than a vendor pays.", rows, HEAD)
		plate.drop:SetUsable(lit > 0, "Nothing is safe to drop.")
		local detail = #things == 0 and "" or (lit .. " of " .. #things .. " lit")
		return WIDTH, "Make room", detail, ""
	end
end
