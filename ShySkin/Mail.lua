-- The mailbox: a window of our own in place of the game's (MailFrame). The game's window stays the panel the game
-- opens and closes (the mailbox you click, Escape, walking away), emptied and taking no mouse: every piece of it goes to
-- the attic (Shop.lua). Ours is a child of it, so it opens and closes with it. It flows: dragged by a corner or a side
-- it is laid again at that size, never scaled; wide enough, the list and the open letter stand side by side.
--
-- Under the header, a band: the page's picture, its title (Inbox, a letter's subject, a new letter), pills of what
-- waits (unread, gold, items, mail still on the server, your bags' room) and the switch between your inbox and a new
-- letter. The body stands on the window's own plain color:
--   the inbox: a row for each letter, who sent it and what about, what it holds (gold, items, cash on delivery) and
--   how long it stays (in red its last day); unread ones carry your color at their edge. A click opens it, Shift-click
--   takes what it holds.
--   a letter: its words on a page inked to read in every theme, or on its own stationery laid to cover the page; an
--   auction's account of the sale; what it holds as slots to click.
--   a new letter: to whom (your other characters a click away, from ShyBags), the subject, the words on a page, what you
--   attach and the gold you send or ask for.
-- The foot is a hover's foot: one filled button, the page's answer (Take all, Pay, Reply, Send) at its right end, the
-- others quiet words beside it, and what is under way at its left.
--
-- Taking all is ours (the game's own runs on a button that is in the attic), paced as the game paces it; it stops when
-- your bags are full and offers to make room. Cash on delivery and deleting what a letter holds ask twice.

local ADDON, ns = ...
local UI = Shy.UI

-- Money as the game writes it (thousands apart), its coins set level with the digits.
local function Coins(copper)
	return UI.MoneyFit(GetMoneyString(copper, true))
end
local Theme = Shy.Theme
local Slot = Shy.Slot
local C = UI.colors
local Shop = ns.Shop
local HEAD = UI.HEAD.window

local L = {
	w = 430, h = 560, least = { 340, 420 },
	split = 720, list = 340, gap = 10,    -- side by side from this width: the list's width, between the two
	pad = 12, band = 62, icon = 40, foot = 38, button = 12, between = 8, quiet = 10,
	pill = 18, pillGap = 6, segW = 112, segH = 22,
	row = 42, rowGap = 2, rowSlot = Slot.SIZES.compact, rowPin = 12,   -- (a row's pin: the quest's, on its picture's corner)
	inset = 14, feather = 22, text = 13, page = 120,   -- a page's inset, its feather, its words' size and least height
	field = 24, fieldGap = 8, chip = 20, chipRows = 2,
	slot = Slot.SIZES.medium, slotGap = 6, held = Slot.SIZES.bag, -- a slot you fill, one a letter holds
	coinLeft = 4, coinRight = 16, caret = 3, -- a coin box's insets (its coin sits in the right one) and room for the cursor
	pace = 0.15,                           -- between two takes (the game's own pace)
	late = 1, soon = 3,                    -- days: red under one, amber under three
	tip = 3,                               -- a row's tooltip only for one item
}
L.head0 = HEAD.line + UI.LINE
L.ICON = Shop.ICON

local WORDS = {
	title = "Mailbox", inbox = "Inbox", send = "Send", new = "New letter", reply = "Reply",
	unread = "%d unread", item = "%d item", items = "%d items", more = "%d more waiting", room = "Bags: %d free", full = "Bags full",
	cod = "C.O.D.", returned = "Returned", empty = "No mail", takeAll = "Take all", taking = "%d left to take",
	stop = "Stop", pay = "Pay %s", take = "Take", delete = "Delete", ret = "Return", back = "Back", makeRoom = "Make room",
	short = "You don't have that much gold", nothing = "Nothing to take", spam = "Report as spam",
	to = "To", subject = "Subject", words = "Write your letter", attach = "Drop items here, or right-click them in your bags.",
	gold = "Send gold", ask = "C.O.D.", postage = "Postage %s", needs = "Needs a name and a subject", sending = "Sending",
	sold = "Sold: %s", bought = "Bought: %s", by = "To %s", from = "From %s", price = "Sale price", deposit = "Deposit",
	cut = "Auction house cut", got = "You got", paid = "You paid", pending = "Gold on its way", attached = "Attached",
}
local TONE = { good = C.good, bad = C.bad, alert = C.alert, hot = C.hot }

local M              -- the module
local own = { rows = {}, pills = {}, slots = {}, sends = {}, chips = {} }
local page = "inbox" -- "inbox" or "send"
local letter         -- the open letter's index, or nil
local mail = {}      -- the inbox read: one record a letter
local sum = {}       -- what it holds in all
local draft = { to = "", subject = "", body = "", cod = false }
local taking         -- take all under way: { index, slot, failed, wait, count, done }
local stopped        -- why take all stopped short ("full")
local mouse          -- the game's window took the mouse before we emptied it
local plain          -- the game's own stationery (its file), so a letter on it reads on our page
local Refresh, Stale

local function Frame() return MailFrame end

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

local function Items(n)
	return (n == 1 and WORDS.item or WORDS.items):format(n)
end

local function Plain(value)
	if value == nil or issecretvalue(value) then return nil end
	return value
end

-- What a quest wants of an item (ShyQuest, where it is on): "now", "later" or "over", worn as the quest's pin on
-- what a letter holds and on the letter's own row, so the mailbox says which letters to take.
local PIN = { now = "quest", later = "ahead", over = "over" }
local function Stands(id)
	local quest = Shy.addons.Quest
	if not (id and quest and quest.ItemStanding) or issecretvalue(id) then return nil end
	return quest:ItemStanding(id)
end

-- The pin for a letter's row: something in it is needed now, else needed later, else none.
local function Holds(i)
	local quest = Shy.addons.Quest
	if not (quest and quest.ItemStanding) then return nil end
	local found
	for slot = 1, ATTACHMENTS_MAX_RECEIVE do
		local _, id = GetInboxItem(i, slot)
		local how = Stands(id)
		if how == "now" then return PIN.now end
		if how == "later" then found = PIN.later end
	end
	return found
end

-- Reading the inbox

local function Read()
	wipe(mail)
	sum = { unread = 0, money = 0, items = 0, more = 0, take = 0 }
	local shown, total = GetInboxNumItems()
	for i = 1, shown or 0 do
		local package, stationery, from, subj, money, cod, days, items, read, returned, made, reply, gm, firstCount =
			GetInboxHeaderInfo(i)
		local m = {
			index = i, package = package, stationery = stationery, from = Plain(from) or UNKNOWN, subj = Plain(subj) or "",
			money = money or 0, cod = cod or 0, days = days or 0, items = items or 0, read = read, returned = returned,
			made = made, reply = reply, gm = gm, first = firstCount,
		}
		m.pin = (m.items > 0) and Holds(i) or nil
		mail[i] = m
		if not read then sum.unread = sum.unread + 1 end
		sum.money = sum.money + m.money
		sum.items = sum.items + m.items
		if not gm and m.cod == 0 and (m.money > 0 or m.items > 0) then sum.take = sum.take + 1 end
	end
	sum.more = math.max(0, (total or 0) - (shown or 0))
end

local function Room()
	local bags = Shy.addons.Bags
	if bags and bags.Room then return (bags:Room()) end
	return C_Container.CalculateTotalNumberOfFreeBagSlots()
end

-- How long a letter stays, in the game's words, and how urgent.
local function Left(days)
	if days >= 1 then return DAYS_ABBR:format(math.floor(days)), days < L.soon and C.alert or C.dim end
	return SecondsToTime(math.floor(days * 86400)), C.bad
end

-- The game's stationery is our page; any other is the letter's own paper.
local function Paper(file)
	if not file or file == "" then return nil end
	own.probe:SetTexture(file)
	local id = own.probe:GetTextureFileID()
	if not plain then
		own.probe:SetTexture("Interface/Stationery/stationerytest1")
		plain = own.probe:GetTextureFileID() or false
	end
	if not id or id == plain then return nil end
	return id
end

-- Take all: as the game's Open All goes, a take at a time, never on a letter from a Game Master or one asking for gold.

local function Stop()
	if not taking then return end
	taking = nil
	C_Mail.SetOpeningAll(false)
	own.driver:SetScript("OnUpdate", nil)
	Stale()
end

local function Skip(i, slot)
	local m = mail[i]
	if not m or m.gm or m.cod > 0 then return true end
	if C_Mail.HasInboxMoney(i) then return false end
	local _, id, _, _, _, _, isCurrency = GetInboxItem(i, slot)
	if not isCurrency and id and taking.failed[id] then return true end
	return not HasInboxItem(i, slot)
end

-- The next take: { index, slot } or nil when none is left.
local function Next()
	while taking.index <= GetInboxNumItems() do
		local i = taking.index
		local m = mail[i]
		if m and not m.gm and m.cod == 0 then
			while taking.slot > 0 do
				if not Skip(i, taking.slot) then return true end
				taking.slot = taking.slot - 1
			end
		end
		taking.index = i + 1
		taking.slot = ATTACHMENTS_MAX_RECEIVE
	end
	return false
end

local function Step()
	if Room() == 0 then
		stopped = "full"
		return Stop()
	end
	if not Next() then return Stop() end
	local i = taking.index
	local _, _, _, _, money, _, _, items = GetInboxHeaderInfo(i)
	if (money or 0) > 0 then
		TakeInboxMoney(i)
	elseif (items or 0) > 0 then
		TakeInboxItem(i, taking.slot)
	else
		taking.index = i + 1
		return Step()
	end
	taking.done = taking.done + 1
	taking.wait = L.pace
end

local function Drive(_, elapsed)
	if not taking or not taking.wait then return end
	taking.wait = taking.wait - elapsed
	if taking.wait > 0 then return end
	if C_Mail.IsCommandPending() then
		taking.wait = L.pace
		return
	end
	taking.wait = nil
	Step()
end

local function TakeAll()
	if taking then return Stop() end
	stopped = nil
	letter = nil
	taking = { index = 1, slot = ATTACHMENTS_MAX_RECEIVE, failed = {}, count = sum.take, done = 0, shown = GetInboxNumItems() }
	C_Mail.SetOpeningAll(true)
	own.driver:SetScript("OnUpdate", Drive)
	Step()
	Stale()
end

-- A letter

-- Leaving a letter as the game leaves it: one whose words you took as an item and that holds nothing more is deleted.
local function Leave()
	local i = letter
	letter = nil
	if not i or i > GetInboxNumItems() then return end
	local m = mail[i]
	if not m or m.money > 0 or m.items > 0 or not m.made then return end
	local _, _, _, _, isInvoice = GetInboxText(i)
	if isInvoice and GetInboxInvoiceInfo(i) == "seller_temp_invoice" then return end
	DeleteInboxItem(i)
end

local function Open(i)
	letter = i
	page = "inbox"
	PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
	if own.letterArea then own.letterArea:SetVerticalScroll(0) end
	Refresh()
end

local function Back()
	Leave()
	PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
	Refresh()
end

local function Delete()
	local i = letter
	if not i then return end
	if InboxItemCanDelete(i) then DeleteInboxItem(i) else ReturnInboxItem(i) end
	letter = nil
	Refresh()
end

local function Reply()
	local m = letter and mail[letter]
	if not m then return end
	local prefix = MAIL_REPLY_PREFIX .. " "
	draft.to = m.from
	draft.subject = (m.subj:sub(1, #prefix) == prefix) and m.subj or (prefix .. m.subj)
	draft.body = ""
	draft.reply = letter
	page = "send"
	Refresh()
	own.bodyBox:SetFocus()
end

-- Takes what the open letter holds: everything, or paying first for one asking for gold.
local function Take()
	local m = letter and mail[letter]
	if not m then return end
	if m.cod > 0 then
		for slot = 1, ATTACHMENTS_MAX_RECEIVE do
			if HasInboxItem(letter, slot) then return TakeInboxItem(letter, slot) end
		end
		return
	end
	AutoLootMailItem(letter)
end

local function Report()
	if not letter then return end
	local info = ReportInfo:CreateMailReportInfo(Enum.ReportType.Mail, letter)
	if info then ReportFrame:InitiateReport(info, mail[letter] and mail[letter].from) end
end

-- Sending

local function Copper()
	local g = tonumber(own.coins[1]:GetText()) or 0
	local s = tonumber(own.coins[2]:GetText()) or 0
	local c = tonumber(own.coins[3]:GetText()) or 0
	return g * COPPER_PER_GOLD + s * COPPER_PER_SILVER + c
end

local function Attached()
	for i = 1, ATTACHMENTS_MAX_SEND do
		if HasSendMailItem(i) then return true end
	end
	return false
end

local function CanSend()
	return strtrim(draft.to) ~= "" and strtrim(draft.subject) ~= "" and not draft.busy
end

local function Fresh()
	draft.to, draft.subject, draft.body, draft.cod, draft.reply, draft.busy, draft.named = "", "", "", false, nil, nil, nil
	for _, box in ipairs(own.coins) do box:SetText("") end
	own.bodyBox:SetText("")
end

-- Who a letter goes to: the game wants a name and its surname, so one of yours written by name alone gets its surname;
-- anyone else as written.
local function Address(to)
	to = strtrim(to)
	local bags = Shy.addons.Bags
	for _, alt in ipairs((bags and bags.Alts) and bags:Alts() or {}) do
		if alt.full and alt.name:lower() == to:lower() then return alt.full end
	end
	return to
end

local function Send()
	if not CanSend() then return end
	local copper = Copper()
	SetSendMailCOD(0)
	SetSendMailMoney(0)
	if copper > 0 then
		if draft.cod and Attached() then
			SetSendMailCOD(copper)
		elseif SetSendMailMoney(copper) == false then
			own.status:SetText(WORDS.short)
			return
		end
	end
	draft.busy = true
	SendMail(Address(draft.to), draft.subject, draft.body, draft.reply)
	Stale()
end

-- Building

local function Groove(frame, top)
	local groove = frame:CreateTexture(nil, "BORDER")
	groove:SetColorTexture(0, 0, 0, 0.85)
	groove:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT")
	groove:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT")
	groove:SetHeight(1)
	local lip = frame:CreateTexture(nil, "BORDER")
	lip:SetColorTexture(1, 1, 1, 0.07)
	lip:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", 0, top and -1 or 1)
	lip:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", 0, top and -1 or 1)
	lip:SetHeight(1)
end

local function Pill(i)
	local pill = own.pills[i]
	if pill then return pill end
	pill = CreateFrame("Frame", nil, own.band)
	pill:SetHeight(L.pill)
	pill.fill = pill:CreateTexture(nil, "BACKGROUND")
	pill.fill:SetAllPoints()
	pill.edge = pill:CreateTexture(nil, "BORDER")
	pill.edge:SetPoint("TOPLEFT")
	pill.edge:SetPoint("BOTTOMLEFT")
	pill.edge:SetWidth(2)
	pill.text = Text(pill, UI.TextFont(11), C.text)
	pill.text:SetPoint("LEFT", 8, 0)
	own.pills[i] = pill
	return pill
end

-- A button of the foot: words alone while quiet, the one filled button the page's answer.
local function FootButton(word, onClick, twice)
	local b = UI.Button(own.foot, word, 96, onClick)
	if twice then UI.Twice(b, onClick) end
	b:SetFrameLevel(own.foot:GetFrameLevel() + 2)
	b:Hide()
	return b
end

-- A slot to click: an icon in the family's frame, a count, the game's tooltip.
local function SlotButton(parent, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(unpack(L.ICON))
	b.slot = Slot.New(b, { to = b.icon, icon = b.icon, size = size, hover = true })
	b.count = b:CreateFontString(nil, "OVERLAY")
	b.count:SetFontObject(NumberFontNormal)
	b.count:SetPoint("BOTTOMRIGHT", -1, 1)
	b.slot:Count(b.count)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function Row(i)
	local row = own.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, own.listArea.content)
	row:SetHeight(L.row)
	row:RegisterForClicks("LeftButtonUp")
	row.hot = row:CreateTexture(nil, "BACKGROUND")
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.row, 0.95)
	row.hot:Hide()
	row.on = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.on:SetAllPoints()
	row.rule = row:CreateTexture(nil, "BORDER")
	row.rule:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.rule:SetHeight(1)
	row.bar = row:CreateTexture(nil, "ARTWORK")
	row.bar:SetSize(2, L.row - 12)
	row.bar:SetPoint("LEFT", 0, 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(L.rowSlot, L.rowSlot)
	row.icon:SetPoint("LEFT", 8, 0)
	row.icon:SetTexCoord(unpack(L.ICON))
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, size = L.rowSlot, hover = false })
	row.pin = Slot.Pin(row, row.icon, nil, L.rowPin)
	row.count = row:CreateFontString(nil, "OVERLAY")
	row.count:SetFontObject(NumberFontNormal)
	row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 0)
	row.slot:Count(row.count)
	local left = 8 + L.rowSlot + 10
	row.left = left
	row.when = Text(row, UI.TextFont(10), C.dim)
	row.when:SetPoint("TOPRIGHT", -8, -7)
	row.when:SetJustifyH("RIGHT")
	row.what = Text(row, UI.NameFont(11), C.text)
	row.what:SetPoint("BOTTOMRIGHT", -8, 7)
	row.what:SetJustifyH("RIGHT")
	row.from = Text(row, UI.NameFont(12), C.head)
	row.from:SetPoint("TOPLEFT", left, -6)
	row.from:SetPoint("RIGHT", row.when, "LEFT", -8, 0)
	row.subj = Text(row, UI.TextFont(11), C.dim)
	row.subj:SetPoint("BOTTOMLEFT", left, 7)
	row.subj:SetPoint("RIGHT", row.what, "LEFT", -8, 0)
	row:SetScript("OnClick", function(self)
		local m = mail[self.index]
		if not m then return end
		if IsShiftKeyDown() then
			if m.cod == 0 and not m.gm then AutoLootMailItem(self.index) end
			return
		end
		if letter == self.index then Back() else Open(self.index) end
	end)
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		local m = mail[self.index]
		if m and m.items == 1 then
			UI.GameTipAt(self, self.icon)
			GameTooltip:SetInboxItem(self.index)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	own.rows[i] = row
	return row
end

local function Field(parent, key, hint, letters, onEnter)
	local f = UI.Input(parent, nil, function() return draft[key] end, function(text) draft[key] = text; Stale() end, {
		live = true, maxLetters = letters, placeholder = function() return hint end,
	})
	f:SetHeight(L.field)
	f.box:ClearAllPoints()
	f.box:SetAllPoints()
	f.box:SetFontObject(UI.TextFont(12))
	f.box:SetScript("OnTabPressed", onEnter)
	return f
end

local function BuildSend(box)
	local area = UI.ScrollArea(box, L.w, L.h, { smooth = true, shades = C.panel })
	area:SetFrameLevel(box:GetFrameLevel() + 3)
	own.sendArea = area
	local sheet = area.content

	own.to = Field(sheet, "to", WORDS.to, 77, function() own.subject.box:SetFocus() end)
	own.to:SetPoint("TOPLEFT", L.inset, -L.inset)
	own.to:SetPoint("RIGHT", sheet, "RIGHT", -L.inset, 0)
	own.subject = Field(sheet, "subject", WORDS.subject, 64, function() own.bodyBox:SetFocus() end)

	-- The words, on a page.
	local paper = UI.PaperPage(sheet, { feather = L.feather })
	paper:SetFrameLevel(sheet:GetFrameLevel() + 1)
	own.sendPage = paper
	local body = CreateFrame("EditBox", nil, paper)
	body:SetMultiLine(true)
	body:SetAutoFocus(false)
	body:SetMaxLetters(500)
	body:SetFontObject(UI.TextFont(L.text))
	body:SetPoint("TOPLEFT", L.inset, -L.inset)
	body:SetPoint("RIGHT", paper, "RIGHT", -L.inset, 0)
	body:SetHeight(L.page - 2 * L.inset)
	body.hint = Text(paper, UI.TextFont(L.text), C.dim)
	body.hint:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	body.hint:SetText(WORDS.words)
	body.measure = paper:CreateFontString(nil, "BACKGROUND")
	body.measure:SetFontObject(UI.TextFont(L.text))
	body.measure:SetWordWrap(true)
	body.measure:SetAlpha(0)
	body:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	body:SetScript("OnTabPressed", function() own.to.box:SetFocus() end)
	body:SetScript("OnTextChanged", function(self, typed)
		draft.body = self:GetText()
		self.hint:SetShown(draft.body == "")
		if typed then Stale() end
	end)
	body:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top = select(5, paper:GetPoint(1)) or 0
		own.sendArea:Reveal(-top - y + L.inset - 4, -top - y + h + L.inset + 4)
	end)
	paper:EnableMouse(true)
	paper:SetScript("OnMouseDown", function() body:SetFocus() end)
	own.bodyBox = body

	-- What you attach.
	own.attachHint = Text(sheet, UI.TextFont(11), C.dim)
	own.attachHint:SetText(WORDS.attach)
	own.attachHint:SetWordWrap(true)
	for i = 1, ATTACHMENTS_MAX_SEND do
		local b = SlotButton(sheet, L.slot)
		b.index = i
		b:SetScript("OnClick", function(self, button) ClickSendMailItemButton(self.index, button == "RightButton") end)
		b:SetScript("OnReceiveDrag", function(self) ClickSendMailItemButton(self.index) end)
		b:SetScript("OnEnter", function(self)
			if not HasSendMailItem(self.index) then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSendMailItem(self.index)
			GameTooltip:Show()
		end)
		own.sends[i] = b
	end

	-- The gold: sent with it, or asked for on delivery.
	own.mode = UI.Segmented(sheet, { WORDS.gold, WORDS.ask }, function() return draft.cod and 2 or 1 end, function(i)
		draft.cod = i == 2 and Attached()
		own.mode:Refresh()
		Stale()
	end, { width = 150, height = L.field - 2 })
	own.coins = {}
	for i, atlas in ipairs({ "coin-gold", "coin-silver", "coin-copper" }) do
		local c = CreateFrame("EditBox", nil, sheet)
		c.letters = i == 1 and 6 or 2
		c:SetHeight(L.field)
		c:SetAutoFocus(false)
		c:SetNumeric(true)
		c:SetMaxLetters(c.letters)
		c:SetFontObject(UI.TextFont(12))
		c:SetJustifyH("RIGHT")
		c:SetTextInsets(L.coinLeft, L.coinRight, 0, 0)
		UI.Skin(c, C.bg, C.border)
		c.coin = c:CreateTexture(nil, "OVERLAY")
		c.coin:SetAtlas(atlas)
		c.coin:SetSize(11, 11)
		c.coin:SetPoint("RIGHT", -4, 0)
		c:SetScript("OnTextChanged", function(_, typed) if typed then Stale() end end)
		c:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		c:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		c:SetScript("OnEditFocusGained", function(self) UI.SetBorder(self, C.hot) end)
		c:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
		own.coins[i] = c
	end
	-- Measures a box's widest amount in its own font, so every digit it takes shows.
	own.coinProbe = sheet:CreateFontString(nil, "ARTWORK")
	own.coinProbe:Hide()
end

local function BuildLetter(box)
	local area = UI.ScrollArea(box, L.w, L.h, { smooth = true, shades = C.panel })
	area:SetFrameLevel(box:GetFrameLevel() + 3)
	own.letterArea = area
	local sheet = area.content
	local paper = UI.PaperPage(sheet, { feather = L.feather })
	paper:SetFrameLevel(sheet:GetFrameLevel() + 1)
	paper:SetPoint("TOPLEFT", L.inset, -L.inset)
	own.paper = paper
	own.words = paper:CreateFontString(nil, "ARTWORK")
	own.words:SetFontObject(UI.TextFont(L.text))
	own.words:SetJustifyH("LEFT")
	own.words:SetJustifyV("TOP")
	own.words:SetWordWrap(true)
	own.words:SetSpacing(2)
	own.words:SetPoint("TOPLEFT", L.inset, -L.inset)
	-- An auction's account: label and amount a line.
	own.account = {}
	for i = 1, 5 do
		local line = {}
		line.label = Text(sheet, UI.TextFont(11), C.dim)
		line.value = Text(sheet, UI.NameFont(11), C.text)
		line.value:SetJustifyH("RIGHT")
		own.account[i] = line
	end
	own.attached = Text(sheet, UI.NameFont(11), C.dim)
	own.attached:SetText(WORDS.attached)
	-- What it holds: its gold, a copy of its words, its items.
	for i = 1, ATTACHMENTS_MAX_RECEIVE + 2 do
		local b = SlotButton(sheet, L.held)
		b:SetScript("OnClick", function(self)
			if not letter then return end
			local m = mail[letter]
			if self.kind == "money" then TakeInboxMoney(letter)
			elseif self.kind == "copy" then TakeInboxTextItem(letter)
			elseif m and m.cod == 0 then TakeInboxItem(letter, self.index) end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end)
		b:SetScript("OnEnter", function(self)
			if not letter then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.kind == "money" then
				GameTooltip:AddLine(ENCLOSED_MONEY, 1, 1, 1)
				GameTooltip_AddMoneyLine(GameTooltip, self.money)
			elseif self.kind == "copy" then
				GameTooltip:AddLine(MAIL_LETTER_TOOLTIP, 1, 1, 1, true)
			else
				GameTooltip:SetInboxItem(letter, self.index)
				local m = mail[letter]
				if m and m.cod > 0 then GameTooltip_AddMoneyLine(GameTooltip, m.cod, m.cod > GetMoney()) end
			end
			GameTooltip:Show()
		end)
		own.slots[i] = b
	end
	own.spam = CreateFrame("Button", nil, sheet)
	own.spam:SetHeight(16)
	own.spam.text = Text(own.spam, UI.TextFont(10), C.dim)
	own.spam.text:SetPoint("LEFT")
	own.spam.text:SetText(WORDS.spam)
	own.spam:SetWidth(math.ceil(own.spam.text:GetStringWidth()) + 2)
	own.spam:SetScript("OnClick", Report)
	own.spam:SetScript("OnEnter", function(self) UI.Ink(self.text, C.hot) end)
	own.spam:SetScript("OnLeave", function(self) UI.Ink(self.text, C.dim) end)
end

local function Build()
	local f = Frame()
	local box = UI.Window({
		id = "shyskin.mail", title = WORDS.title, width = L.w, height = L.h,
		point = { "TOPLEFT", "TOPLEFT", 16, -116 },
		shown = function() return M ~= nil and M.on == true end,
		head = { size = "window", title = WORDS.title },
		grip = { flow = function() if Stale then Stale() end end, min = { L.least[1], L.least[2] } },
		-- Closed by its ×: the mailbox closes, as the game's window closes it.
		onClose = function() CloseMail() end,
	})
	own.box = box
	box:SetParent(f)
	own.driver = CreateFrame("Frame", nil, box)
	own.probe = box:CreateTexture(nil, "BACKGROUND")
	own.probe:SetSize(1, 1)
	own.probe:SetAlpha(0)

	-- The band and the foot stand on the window's body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)

	-- The band: your color's wash from the left, a groove along its foot.
	local band = CreateFrame("Frame", nil, box)
	band:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -L.head0)
	band:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -L.head0)
	band:SetHeight(L.band)
	band:SetFrameLevel(box:GetFrameLevel() + 2)
	own.band = band
	local wash = band:CreateTexture(nil, "BACKGROUND")
	wash:SetAllPoints()
	wash:SetColorTexture(1, 1, 1, 1)
	function wash:Ink()
		local r, g, b = Theme.Accent()
		self:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.12), CreateColor(r, g, b, 0))
	end
	own.wash = wash
	Groove(band, false)
	own.icon = band:CreateTexture(nil, "ARTWORK")
	own.icon:SetSize(L.icon, L.icon)
	own.icon:SetPoint("LEFT", L.pad, 0)
	own.icon:SetTexCoord(unpack(L.ICON))
	own.iconSlot = Slot.New(band, { to = own.icon, icon = own.icon, size = L.icon, hover = false })
	own.left = L.pad + L.icon + 12
	own.switch = UI.Segmented(band, { WORDS.inbox, WORDS.send }, function() return page == "send" and 2 or 1 end, function(i)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		page = i == 2 and "send" or "inbox"
		if page == "send" then draft.reply = nil end
		Refresh()
	end, { width = L.segW, height = L.segH })
	own.switch:SetPoint("TOPRIGHT", band, "TOPRIGHT", -L.pad, -10)
	own.title = Text(band, UI.TitleFont(15), C.head)
	own.title:SetPoint("TOPLEFT", own.left, -12)
	own.title:SetPoint("RIGHT", own.switch, "LEFT", -10, 0)

	-- The foot: a hover's foot, its floor under a groove and a lip of light.
	local foot = CreateFrame("Frame", nil, box)
	foot:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 2, 2)
	foot:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
	foot:SetHeight(L.foot)
	foot:SetFrameLevel(box:GetFrameLevel() + 6)
	own.foot = foot
	local floor = foot:CreateTexture(nil, "BACKGROUND")
	floor:SetAllPoints()
	floor:SetColorTexture(0, 0, 0, 0.30)
	Groove(foot, true)
	own.status = Text(foot, UI.TextFont(11), C.dim)
	own.status:SetPoint("LEFT", L.button, 0)
	own.b = {
		take = FootButton(WORDS.takeAll, TakeAll),
		room = FootButton(WORDS.makeRoom, function()
			local bags = Shy.addons.Bags
			if bags and bags.MakeRoom then bags:MakeRoom({ need = 1, why = WORDS.title }) end
		end),
		pay = FootButton(WORDS.pay, Take, true),
		takeOne = FootButton(WORDS.take, Take),
		reply = FootButton(WORDS.reply, Reply),
		delete = FootButton(WORDS.delete, Delete),
		deleteSure = FootButton(WORDS.delete, Delete, true),
		back = FootButton(WORDS.back, Back),
		send = FootButton(WORDS.send, Send),
	}

	-- The reading ground: the look keeps the frame, the band and the foot; the rest stands on the window's plain color.
	local ground = CreateFrame("Frame", nil, box)
	ground:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
	ground:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
	ground:SetFrameLevel(box:GetFrameLevel() + 1)
	ground.fill = ground:CreateTexture(nil, "BACKGROUND")
	ground.fill:SetAllPoints()
	UI.Paint(ground.fill, C.panel, 1)
	own.ground = ground

	-- The inbox.
	local list = UI.ScrollArea(box, L.list, L.h, { smooth = true, shades = C.panel })
	list:SetFrameLevel(box:GetFrameLevel() + 3)
	own.listArea = list
	own.none = Text(list.content, UI.TextFont(12), C.dim)
	own.none:SetPoint("TOP", 0, -30)
	own.none:SetText(WORDS.empty)
	own.divide = box:CreateTexture(nil, "ARTWORK")
	own.divide:SetWidth(1)
	UI.Paint(own.divide, C.border, 0.9)

	BuildLetter(box)
	BuildSend(box)
end

-- Drawing

local function Pills(list)
	local x, y = own.left, -36
	local room = UI.BodySize(own.box) - 4 - L.pad
	local shown = 0
	for _, fact in ipairs(list) do
		local pill = Pill(shown + 1)
		pill.text:SetText(fact.text)
		local wide = math.ceil(pill.text:GetStringWidth() + 16)
		if x + wide > room then break end
		shown = shown + 1
		local tone = TONE[fact.tone]
		UI.Paint(pill.fill, tone or C.text, tone and 0.16 or 0.07)
		UI.Paint(pill.edge, tone or C.dim, 0.9)
		UI.Ink(pill.text, tone or C.text)
		pill:SetWidth(wide)
		pill:ClearAllPoints()
		pill:SetPoint("TOPLEFT", own.band, "TOPLEFT", x, y)
		pill:Show()
		x = x + wide + L.pillGap
	end
	for i = shown + 1, #own.pills do own.pills[i]:Hide() end
end

local function DrawBand()
	own.wash:Ink()
	own.switch:Refresh()
	local m = letter and mail[letter]
	local facts = {}
	if page == "send" then
		own.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
		own.title:SetText(draft.reply and WORDS.reply or WORDS.new)
		local to = Address(draft.to)
		if to ~= "" then facts[#facts + 1] = { text = WORDS.by:format(to) } end
		facts[#facts + 1] = { text = WORDS.room:format(Room()) }
	elseif m and own.split ~= true then
		own.icon:SetTexture(m.package or m.stationery)
		own.title:SetText(m.subj ~= "" and m.subj or m.from)
		facts[#facts + 1] = { text = WORDS.from:format(m.from) }
		local when, tone = Left(m.days)
		facts[#facts + 1] = { text = when, tone = tone == C.bad and "bad" or (tone == C.alert and "alert" or nil) }
		if m.cod > 0 then facts[#facts + 1] = { text = WORDS.cod .. " " .. Coins(m.cod), tone = "bad" } end
		if m.returned then facts[#facts + 1] = { text = WORDS.returned } end
	else
		own.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
		own.title:SetText(WORDS.inbox)
		if sum.unread > 0 then facts[#facts + 1] = { text = WORDS.unread:format(sum.unread), tone = "hot" } end
		if sum.money > 0 then facts[#facts + 1] = { text = Coins(sum.money), tone = "alert" } end
		if sum.items > 0 then facts[#facts + 1] = { text = Items(sum.items) } end
		local free = Room()
		facts[#facts + 1] = free == 0 and { text = WORDS.full, tone = "bad" } or { text = WORDS.room:format(free), tone = free < sum.items and "alert" or nil }
		if sum.more > 0 then facts[#facts + 1] = { text = WORDS.more:format(sum.more) } end
	end
	Pills(facts)
end

local function DrawList(width)
	local list = own.listArea
	list.content:SetWidth(width)
	local y = 4
	for i, m in ipairs(mail) do
		local row = Row(i)
		row.index = i
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -y)
		row:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
		row.icon:SetTexture(m.package or m.stationery)
		row.icon:SetDesaturated(m.read and true or false)
		row.count:SetText((m.first and m.first > 1) and m.first or "")
		row.pin:Set(m.pin)
		row.from:SetText(m.from)
		row.subj:SetText(m.subj)
		UI.Ink(row.from, m.read and C.text or C.head)
		local when, tone = Left(m.days)
		row.when:SetText(when)
		UI.Ink(row.when, tone)
		if m.cod > 0 then
			row.what:SetText(WORDS.cod .. " " .. Coins(m.cod))
			UI.Ink(row.what, C.bad)
		elseif m.money > 0 then
			row.what:SetText(Coins(m.money))
			UI.Ink(row.what, C.text)
		elseif m.items > 0 then
			row.what:SetText(Items(m.items))
			UI.Ink(row.what, C.text)
		else
			row.what:SetText(m.returned and WORDS.returned or "")
			UI.Ink(row.what, C.dim)
		end
		row.bar:SetShown(not m.read)
		UI.Paint(row.bar, Theme.Accent)
		UI.Paint(row.rule, C.rowEdge, 0.7)
		UI.Paint(row.on, Theme.Accent, 0.12)
		row.on:SetShown(letter == i)
		row:Show()
		y = y + L.row + L.rowGap
	end
	for i = #mail + 1, #own.rows do own.rows[i]:Hide() end
	own.none:SetShown(#mail == 0)
	list.content:SetHeight(math.max(y, 60))
	list:Update()
end

-- The open letter: its words on its page, an auction's account, what it holds.
local function DrawLetter(width)
	local area = own.letterArea
	local sheet = area.content
	sheet:SetWidth(width)
	local m = letter and mail[letter]
	if not m then return end
	local column = width - 2 * L.inset
	local body, s1, s2, _, isInvoice = GetInboxText(letter)
	body = Plain(body) or ""
	-- A letter without words gets no page: what it holds moves up.
	local said = body:find("%S") ~= nil
	own.paper:SetShown(said)
	local y = L.inset
	if said then
		own.words:SetWidth(column - 2 * L.inset)
		own.words:SetText(body)
		local tall = math.max(L.page, math.ceil(own.words:GetStringHeight()) + 2 * L.inset)
		own.paper:SetSize(column, tall)
		local a, b = Paper(Plain(s1)), Plain(s2)
		local paper = a and { files = { { s1, 0, 0, 252, 256 }, { b, 252, 0, 64, 256 } }, spread = { 316, 256 }, material = "Parchment" } or nil
		local face, ink = own.paper:Lay(paper)
		UI.FaceInk(own.words, own.paper, face, ink)
		y = y + tall + 12
	end

	-- An auction's account.
	local lines = {}
	if isInvoice then
		local kind, item, player, bid, buyout, deposit, cut, _, _, _, count = GetInboxInvoiceInfo(letter)
		item = Plain(item) or ""
		if count and count > 1 then item = AUCTION_MAIL_ITEM_STACK:format(item, count) end
		player = Plain(player)
		if kind == "buyer" then
			lines = { { WORDS.bought:format(item) }, player and { WORDS.from:format(player) } or nil, { WORDS.paid, bid } }
		elseif kind == "seller" then
			lines = { { WORDS.sold:format(item) }, { WORDS.price, bid }, { WORDS.deposit, deposit }, { WORDS.cut, -(cut or 0) }, { WORDS.got, (bid or 0) + (deposit or 0) - (cut or 0) } }
		elseif kind == "seller_temp_invoice" then
			lines = { { WORDS.sold:format(item) }, { WORDS.pending, (bid or 0) + (deposit or 0) - (cut or 0) } }
		end
	end
	for i, line in ipairs(own.account) do
		local said = lines[i]
		line.label:SetShown(said ~= nil)
		line.value:SetShown(said ~= nil)
		if said then
			line.label:ClearAllPoints()
			line.label:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
			line.value:ClearAllPoints()
			line.value:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -L.inset, -y)
			line.label:SetText(said[1])
			local copper = said[2]
			line.value:SetText(copper and ((copper < 0 and "-" or "") .. Coins(math.abs(copper))) or "")
			UI.Ink(line.value, (copper and copper < 0) and C.bad or C.text)
			y = y + 18
		end
	end
	if #lines > 0 then y = y + 8 end

	-- What it holds.
	local _, _, _, isTakeable = GetInboxText(letter)
	local held = {}
	if m.money > 0 then held[#held + 1] = { kind = "money", icon = C_CurrencyInfo.GetCoinIcon(m.money), money = m.money } end
	if isTakeable and not m.made then held[#held + 1] = { kind = "copy", icon = m.stationery } end
	for slot = 1, ATTACHMENTS_MAX_RECEIVE do
		if HasInboxItem(letter, slot) then
			local _, id, texture, count, quality, canUse = GetInboxItem(letter, slot)
			held[#held + 1] = { kind = "item", index = slot, icon = texture or "Interface\\Icons\\INV_Misc_QuestionMark", count = count, quality = quality, canUse = canUse,
				pin = PIN[Stands(id)] }
		end
	end
	own.attached:SetShown(#held > 0)
	if #held > 0 then
		own.attached:ClearAllPoints()
		own.attached:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
		y = y + 18
	end
	local per = math.max(1, math.floor((column + L.slotGap) / (L.held + L.slotGap)))
	for i, b in ipairs(own.slots) do
		local h = held[i]
		b:SetShown(h ~= nil)
		if h and h.pin and not b.pin then b.pin = Slot.Pin(b, b.icon) end
		if b.pin then b.pin:Set(h and h.pin or nil) end
		if h then
			b.kind, b.index, b.money = h.kind, h.index, h.money
			b.icon:SetTexture(h.icon)
			b.icon:SetVertexColor(1, h.canUse == false and 0.1 or 1, h.canUse == false and 0.1 or 1)
			b.count:SetText((h.count and h.count > 1) and h.count or "")
			b.slot:Quality(h.quality)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset + ((i - 1) % per) * (L.held + L.slotGap), -(y + math.floor((i - 1) / per) * (L.held + L.slotGap)))
		end
	end
	if #held > 0 then y = y + math.ceil(#held / per) * (L.held + L.slotGap) + 6 end
	own.spam:SetShown(CanComplainInboxItem(letter) and true or false)
	own.spam:ClearAllPoints()
	own.spam:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -(y + 4))
	if own.spam:IsShown() then y = y + 24 end
	sheet:SetHeight(y + L.inset)
	area:Update()
end

-- The new letter, laid down the sheet at its width: the words' page fills what the window has to spare.
local function DrawSend(width, height)
	local area = own.sendArea
	local sheet = area.content
	sheet:SetWidth(width)
	local column = width - 2 * L.inset
	own.to:Refresh()
	own.subject:Refresh()
	if own.bodyBox:GetText() ~= draft.body then own.bodyBox:SetText(draft.body) end
	own.bodyBox.hint:SetShown(draft.body == "")
	local y = L.inset + L.field + 6

	-- Your other characters, a click away.
	local bags = Shy.addons.Bags
	local alts = (bags and bags.Alts) and bags:Alts() or {}
	-- Each by name and surname (the letter goes to the name), wrapping onto a second row.
	local x, shown, line = L.inset, 0, 0
	for _, alt in ipairs(alts) do
		local chip = own.chips[shown + 1]
		if not chip then
			chip = Shop.Chip(sheet, "", function(self)
				draft.to = self.full
				own.to:Refresh()
				own.subject.box:SetFocus()
				Stale()
			end)
			own.chips[shown + 1] = chip
		end
		chip:Say(alt.full or alt.name)
		if x > L.inset and x + chip:GetWidth() > width - L.inset then
			if line + 1 >= L.chipRows then break end
			line, x = line + 1, L.inset
		end
		shown = shown + 1
		chip.full = alt.full or alt.name
		local color = alt.class and RAID_CLASS_COLORS[alt.class]
		UI.Ink(chip.text, color and { color.r, color.g, color.b, 1 } or C.text)
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", sheet, "TOPLEFT", x, -(y + line * (L.chip + 4)))
		chip:Show()
		x = x + chip:GetWidth() + 4
	end
	for i = shown + 1, #own.chips do own.chips[i]:Hide() end
	if shown > 0 then y = y + (line + 1) * (L.chip + 4) end
	y = y + 4
	own.subject:ClearAllPoints()
	own.subject:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
	own.subject:SetPoint("RIGHT", sheet, "RIGHT", -L.inset, 0)
	y = y + L.field + L.fieldGap

	-- The attachments and the gold under the page, measured first so the page takes the rest.
	local per = math.max(1, math.floor((column + L.slotGap) / (L.slot + L.slotGap)))
	local rows = math.ceil(ATTACHMENTS_MAX_SEND / per)
	own.attachHint:SetWidth(column)
	local below = L.fieldGap + rows * (L.slot + L.slotGap) + math.ceil(own.attachHint:GetStringHeight()) + 8 + L.field + L.inset
	own.bodyBox.measure:SetWidth(column - 2 * L.inset)
	own.bodyBox.measure:SetText(draft.body ~= "" and draft.body or " ")
	local words = math.ceil(own.bodyBox.measure:GetStringHeight()) + 2 * L.inset + 16
	local tall = math.max(L.page, words, height - y - below)
	own.sendPage:ClearAllPoints()
	own.sendPage:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
	own.sendPage:SetSize(column, tall)
	own.bodyBox:SetHeight(tall - 2 * L.inset)
	local face, ink = own.sendPage:Lay(nil)
	UI.FaceInk(own.bodyBox.hint, own.sendPage, face, C.dim)
	UI.FaceInk(own.bodyBox, own.sendPage, face, ink)
	y = y + tall + L.fieldGap

	for i, b in ipairs(own.sends) do
		local name, _, texture, count, quality = GetSendMailItem(i)
		local has = HasSendMailItem(i)
		b.icon:SetTexture(has and (texture or "Interface\\Icons\\INV_Misc_QuestionMark") or nil)
		b.slot:Empty(not has)
		b.count:SetText((has and count and count > 1) and count or "")
		b.slot:Quality(has and quality or nil)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset + ((i - 1) % per) * (L.slot + L.slotGap), -(y + math.floor((i - 1) / per) * (L.slot + L.slotGap)))
		-- A subject from the first item, as the game gives one.
		if has and name and i == 1 and (draft.subject == "" or draft.subject == draft.named) then
			draft.subject = (count and count > 1) and (name .. " (" .. count .. ")") or name
			draft.named = draft.subject
			own.subject:Refresh()
		end
	end
	y = y + rows * (L.slot + L.slotGap)
	own.attachHint:ClearAllPoints()
	own.attachHint:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
	y = y + math.ceil(own.attachHint:GetStringHeight()) + 8

	-- The gold: asking for it on delivery only with something attached.
	if draft.cod and not Attached() then draft.cod = false end
	own.mode:Refresh()
	own.mode:SetAlpha(Attached() and 1 or 0.5)
	own.mode:ClearAllPoints()
	own.mode:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -(y + 1))
	for _, c in ipairs(own.coins) do
		own.coinProbe:SetFontObject(c:GetFontObject())
		own.coinProbe:SetText(("0"):rep(c.letters))
		c:SetWidth(math.ceil(own.coinProbe:GetUnboundedStringWidth()) + L.coinLeft + L.coinRight + L.caret)
	end
	own.coins[3]:ClearAllPoints()
	own.coins[3]:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -L.inset, -y)
	own.coins[2]:ClearAllPoints()
	own.coins[2]:SetPoint("RIGHT", own.coins[3], "LEFT", -4, 0)
	own.coins[1]:ClearAllPoints()
	own.coins[1]:SetPoint("RIGHT", own.coins[2], "LEFT", -4, 0)
	y = y + L.field + L.inset
	sheet:SetHeight(y)
	area:Update()
end

-- The foot: the page's answer filled at the right end, the rest quiet words, what is under way at the left.
local function DrawFoot()
	for _, b in pairs(own.b) do b:Hide() end
	local B = own.b
	local list = {}   -- right to left: the answer first
	local status = ""
	local m = letter and mail[letter]
	if page == "send" then
		list[1] = B.send
		B.send:SetUsable(CanSend(), WORDS.needs)
		B.send:SetLabel(draft.busy and WORDS.sending or WORDS.send)
		local price = GetSendMailPrice()
		status = WORDS.postage:format(Coins(price))
		if price > GetMoney() then status = UI.Wrap(C.bad, status) end
	elseif m then
		local holds = m.money > 0 or m.items > 0
		if m.cod > 0 then
			list[1] = B.pay
			B.pay.text:SetText(UI.MoneyFit(WORDS.pay:format(Coins(m.cod)), B.pay.text))
			B.pay:SetUsable(m.cod <= GetMoney(), WORDS.short)
		elseif holds then
			list[1] = B.takeOne
			B.takeOne:SetLabel(WORDS.takeAll)
		end
		local mine = m.from == UnitName("player")
		if m.reply and not mine then list[#list + 1] = B.reply end
		local del = holds and B.deleteSure or B.delete
		del.text:SetText(InboxItemCanDelete(letter) and WORDS.delete or WORDS.ret)
		list[#list + 1] = del
		if not own.split then list[#list + 1] = B.back end
	end
	if page ~= "send" and (not m or own.split) then
		-- The inbox's answer: take all; while it runs, stop; bags full, make room.
		local b = B.take
		if taking then
			b:SetLabel(WORDS.stop)
			b:SetUsable(true)
			status = WORDS.taking:format(math.max(sum.take, 1))
		elseif stopped == "full" and Room() == 0 and Shy.addons.Bags and Shy.addons.Bags.MakeRoom then
			b = B.room
			status = UI.Wrap(C.bad, WORDS.full)
		else
			b:SetLabel(WORDS.takeAll)
			b:SetUsable(sum.take > 0, WORDS.nothing)
		end
		if m then table.insert(list, 2, b) else table.insert(list, 1, b) end
	end
	own.status:SetText(status)

	-- Laid from the right: the first filled, the rest quiet; short of room each takes its words' width.
	local gap = L.between
	local room = UI.BodySize(own.box) - 4 - 2 * L.button - (status ~= "" and (own.status:GetUnboundedStringWidth() + 12) or 0)
	local need = 0
	for i, b in ipairs(list) do
		local quiet = i > 1
		b:SetPrimary(not quiet)
		b:SetBare(quiet)
		local wide = math.ceil(b.text:GetUnboundedStringWidth())
		b.full = quiet and (wide + 2 * L.quiet) or math.max(96, wide + 34)
		b.least = quiet and b.full or (wide + 22)
		need = need + b.full + (i > 1 and gap or 0)
	end
	local least = need > room
	local right = -L.button
	for _, b in ipairs(list) do
		b:SetWidth(least and b.least or b.full)
		b.text:SetWidth(b:GetWidth() - 8)
		b:ClearAllPoints()
		b:SetPoint("RIGHT", own.foot, "RIGHT", right, 0)
		b:Show()
		right = right - b:GetWidth() - gap
	end
	own.status:SetPoint("RIGHT", own.foot, "RIGHT", right, 0)
end

-- The body: the list, the letter or the new letter, side by side where the window is wide enough.
local function Draw()
	Read()
	if letter and not mail[letter] then letter = nil end
	local box = own.box
	local wide, tall = UI.BodySize(box)   -- (what it holds stands on its body: UI.Body)
	if issecretvalue(wide) or not wide or wide <= 0 then wide = L.w end
	if issecretvalue(tall) or not tall or tall <= 0 then tall = L.h end
	own.split = page == "inbox" and wide >= L.split
	local bodyH = tall - L.head0 - L.band - L.foot - 4
	local send = page == "send"
	local showList = not send and (own.split or not letter)
	local showLetter = not send and letter ~= nil
	own.listArea:SetShown(showList)
	own.letterArea:SetShown(showLetter)
	own.sendArea:SetShown(send)
	own.divide:SetShown(own.split and showLetter)

	local listW = own.split and L.list or (wide - 4)
	own.listArea:ClearAllPoints()
	own.listArea:SetPoint("TOPLEFT", own.band, "BOTTOMLEFT", 0, -2)
	own.listArea:SetPoint("BOTTOM", own.foot, "TOP", 0, 2)
	own.listArea:SetWidth(listW - 4)
	own.letterArea:ClearAllPoints()
	if own.split then
		own.letterArea:SetPoint("TOPLEFT", own.listArea, "TOPRIGHT", L.gap, 0)
		own.divide:ClearAllPoints()
		own.divide:SetPoint("TOP", own.band, "BOTTOM", 0, 0)
		own.divide:SetPoint("BOTTOM", own.foot, "TOP", 0, 0)
		own.divide:SetPoint("LEFT", own.listArea, "RIGHT", L.gap / 2, 0)
	else
		own.letterArea:SetPoint("TOPLEFT", own.band, "BOTTOMLEFT", 0, -2)
	end
	own.letterArea:SetPoint("BOTTOMRIGHT", own.foot, "TOPRIGHT", -4, 2)
	own.sendArea:ClearAllPoints()
	own.sendArea:SetPoint("TOPLEFT", own.band, "BOTTOMLEFT", 0, -2)
	own.sendArea:SetPoint("BOTTOMRIGHT", own.foot, "TOPRIGHT", -4, 2)

	-- The game's send page is up while ours is: an item right-clicked in your bags is attached.
	SetSendMailShowing(send)
	DrawBand()
	if showList then DrawList(listW - 18) end
	if showLetter then
		local letterW = own.split and (wide - 4 - listW - L.gap - 4) or (wide - 8)
		DrawLetter(letterW - 14)
	end
	if send then DrawSend(wide - 8 - 14, bodyH) end
	DrawFoot()
end

Refresh = function()
	local f = Frame()
	if not (M and M.on and own.box and f and f:IsShown()) then return end
	Shop.Try(M, Draw)
end

Stale = Shop.Later(function() Refresh() end)

-- The game's window, emptied: every piece of it in the attic, its art hidden, no mouse.
local function Empty(kit)
	local f = Frame()
	local attic = Shop.AtticOf(f)
	local kids = {}
	for _, kid in ipairs({ f:GetChildren() }) do
		if kid ~= own.box and kid ~= attic and not kid:IsForbidden() then kids[#kids + 1] = kid end
	end
	Shop.PutAway(f, unpack(kids))
	for _, region in ipairs({ f:GetRegions() }) do kit:Hide(region) end
	if mouse == nil then mouse = { f:IsMouseEnabled(), f:IsMouseWheelEnabled() } end
	f:EnableMouse(false)
	f:EnableMouseWheel(false)
end

-- The module

local EVENTS = { "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_SUCCESS", "CLOSE_INBOX_ITEM",
	"MAIL_CLOSED", "MAIL_OPEN_ALL_CANCELED", "BAG_UPDATE_DELAYED", "PLAYER_MONEY" }

local function Hook()
	local f = Frame()
	f:HookScript("OnShow", function()
		if not M.on then return end
		page, letter, stopped = "inbox", nil, nil
		if own.box then Shy.HUD.Update(own.box) end
		Refresh()
	end)
	f:HookScript("OnHide", function()
		Stop()
		Leave()
		if own.bodyBox then own.bodyBox:ClearFocus() end
	end)
	-- The game puts the focus in its own (hidden) name box after a letter goes: ours keeps it.
	hooksecurefunc("SendMailFrame_Reset", function()
		if not M.on then return end
		SendMailNameEditBox:ClearFocus()
	end)
	-- The game's tabs say whether its send page is up (an item right-clicked in your bags is attached): ours does.
	hooksecurefunc("MailFrameTab_OnClick", function()
		if M.on and Frame():IsShown() then SetSendMailShowing(page == "send") end
	end)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function(_, event, arg)
		if not M.on then return end
		if event == "MAIL_INBOX_UPDATE" then
			-- Letters went: take all starts over from the top, as the game's does.
			if taking and taking.shown ~= GetInboxNumItems() then
				taking.index, taking.slot, taking.shown = 1, ATTACHMENTS_MAX_RECEIVE, GetInboxNumItems()
			end
		elseif event == "MAIL_FAILED" then
			if taking and arg then taking.failed[arg] = true end
			draft.busy = nil
		elseif event == "MAIL_OPEN_ALL_CANCELED" then
			Stop()
		elseif event == "MAIL_SEND_SUCCESS" then
			local replied = draft.reply ~= nil
			Fresh()
			if replied then page = "inbox" end
			PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
		elseif event == "MAIL_SUCCESS" then
			draft.busy = nil
		elseif event == "CLOSE_INBOX_ITEM" then
			if arg == letter then letter = nil end
		elseif event == "MAIL_CLOSED" then
			Stop()
		end
		if Frame():IsShown() then Stale() end
	end)
end

local function Paint(m, kit)
	Shop.Try(m, function()
		if not own.box then Build() end
		Shy.HUD.Update(own.box)
		Empty(kit)
		Refresh()
	end)
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	Stop()
	letter = nil
	local f = Frame()
	SetSendMailShowing(f:IsShown() and SendMailFrame:IsShown())
	Shop.BringBack(f)
	if mouse ~= nil then
		f:EnableMouse(mouse[1])
		f:EnableMouseWheel(mouse[2])
	end
	if own.box then Shy.HUD.Update(own.box) end
end

M = ns.Module({
	id = "mail",
	title = "Mailbox",
	desc = "Replaces the mailbox with a window of your own you can size: your letters at a glance, take all, and sending to your other characters.",
	Ready = function() return MailFrame ~= nil and Shop ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,   -- exposed for inspection
})
