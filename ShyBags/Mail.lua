-- The mailbox: what is in it, when it expires, and the gold taken from it.
--   character.mail = { at = time, more = mail not yet shown by the server,
--       rows = { { from, subj, money, cod, exp, ret, sys, items = { slots }, inv, sent } } }
--   ret: returned; sys: cannot be replied to; sent: added when mailed from another of your characters
--   inv: "kind;item;other player;bid;buyout;deposit;cut;count"
-- Inbox rows have no identity and shift as mail is removed, so readings are matched by sender, subject and expiry.
-- Taking gold only marks the row; the next reading books it once the gold is gone. Returned mail is never booked.

local ADDON, ns = ...
local T = ns.T
local Store = ns.Store

local Mail = {}
ns.Mail = Mail

local SOON = 3 * 86400          -- warn at login about mail expiring within this
local SENT_FOR = 30 * 86400     -- lifetime of mail between characters
local NEAR = 90                 -- seconds two readings of one mail's expiry may differ

local open = false
local queued = false
local last                                         -- rows of the last reading
local taking = setmetatable({}, { __mode = "k" })  -- row -> its gold was requested
local sending                                      -- { to, subj, money, items }

local function Plain(value)
	if value == nil or issecretvalue(value) then return "" end
	return value
end

-- Turns a format string ("Outbid on %s") into a match pattern.
local function AsPattern(text)
	return "^" .. text:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0"):gsub("%%%%s", ".+") .. "$"
end
local OUTBID = AsPattern(AUCTION_OUTBID_MAIL_SUBJECT)

local function Items(index, count)
	local items = {}
	if not count or count == 0 then return items end
	for slot = 1, ATTACHMENTS_MAX_RECEIVE do
		local name, id, _, stack, quality = GetInboxItem(index, slot)
		if id then
			local link = GetInboxItemLink(index, slot)
			local item = link and Store.ItemString(link) or tostring(id)
			local plain = Store.Note(id, quality, name)
			items[#items + 1] = Store.Pack(item, stack, "", (plain and name and name ~= plain) and name or nil)
		end
	end
	return items
end

local function Read()
	local shown, total = GetInboxNumItems()
	local now = ns.Now()
	local rows = {}
	for index = 1, shown do
		local _, _, sender, subject, money, cod, daysLeft, itemCount, _, wasReturned, _, canReply = GetInboxHeaderInfo(index)
		local row = {
			from = Plain(sender), subj = Plain(subject), money = money or 0,
			cod = (cod and cod > 0) and cod or nil,
			exp = math.floor(now + (daysLeft or 0) * 86400),
			ret = wasReturned and true or nil,
			sys = (not canReply) and true or nil,
			items = Items(index, itemCount),
		}
		local kind, item, player, bid, buyout, deposit, cut, _, _, _, count = GetInboxInvoiceInfo(index)
		if kind then
			row.inv = table.concat({ kind, (Plain(item):gsub(";", ",")), (Plain(player):gsub(";", ",")), bid or 0, buyout or 0,
				deposit or 0, cut or 0, count or 1 }, ";")
		end
		rows[index] = row
	end
	return rows, math.max(0, (total or shown) - shown)
end

-- Maps each previous row to its current row (nil if gone).
local function Match(before, now)
	local used, map = {}, {}
	for _, old in ipairs(before) do
		for index, row in ipairs(now) do
			if not used[index] and row.from == old.from and row.subj == old.subj and math.abs(row.exp - old.exp) <= NEAR then
				used[index] = true
				map[old] = row
				break
			end
		end
	end
	return map
end

local function Invoice(row)
	if not row.inv then return nil end
	local kind, item, player, bid, buyout, deposit, cut, count = row.inv:match("^([^;]*);([^;]*);([^;]*);(%d+);(%d+);(%d+);(%d+);(%d+)$")
	if not kind then return nil end
	return { kind = kind, item = item, player = player, bid = tonumber(bid), buyout = tonumber(buyout),
		deposit = tonumber(deposit), cut = tonumber(cut), count = tonumber(count) }
end
Mail.Invoice = Invoice

-- Another of your characters, by mail recipient name.
local function Mine(name)
	name = name:lower():gsub("%-.*$", "")
	if name == "" then return nil end
	for _, entry in ipairs(Store.List()) do
		local c = entry.char
		if entry.guid ~= Store.Guid() and (Store.Name(c):lower() == name or c.name:lower() == name) then return c end
	end
end

-- Your other characters you can mail (this realm and side), for other addons: { name, full, class, level } each, by
-- name. name: what a letter is addressed to; full: as the character is called, with a surname where it has one.
function T:Alts()
	local me = Store.Me()
	local out = {}
	for _, entry in ipairs(Store.List()) do
		local c = entry.char
		if entry.guid ~= Store.Guid() and c.name and (not me or (c.realm == me.realm and c.faction == me.faction)) then
			out[#out + 1] = { name = c.name, full = Store.Name(c), class = c.class, level = c.level }
		end
	end
	return out
end

local function Book(c, row)
	local Ledger = ns.Ledger   -- loads after this file
	local inv = Invoice(row)
	if inv and inv.kind == "seller" then
		Ledger.Book(c, "sale", row.money, inv.item, inv.count, inv.deposit, inv.cut, inv.player)
	elseif row.sys and row.subj:match(OUTBID) then
		Ledger.Book(c, "refund", row.money, row.subj)
	elseif Mine(row.from) then
		Ledger.Book(c, "transfer", row.money, row.subj, 1, 0, 0, row.from)
	else
		Ledger.Book(c, "mail", row.money, row.subj, 1, 0, 0, row.from)
	end
end

local function Snapshot()
	queued = false
	local c = Store.Me()
	if not c or not (open or MailFrame:IsShown()) then return end
	local rows, more = Read()
	if last then
		local map = Match(last, rows)
		for _, old in ipairs(last) do
			local row = map[old]
			if row then row.exp = old.exp end   -- keep the first expiry read
			if taking[old] and old.money > 0 then
				if not row or row.money == 0 then
					Book(c, old)
				else
					taking[row] = true   -- requested, not yet taken
				end
			end
		end
	end
	for _, row in ipairs(rows) do
		local inv = Invoice(row)
		if inv and inv.kind == "seller" and ns.Auctions and ns.Auctions.Paid then ns.Auctions.Paid(c, inv.item, inv.bid) end
	end
	last = rows
	c.mail = { rows = rows, more = more }
	Store.Touch("mail")
end

local function Queue()
	if queued then return end
	queued = true
	C_Timer.After(0, Snapshot)
end

local function Mark(index)
	local row = last and last[index]
	if row and row.money > 0 and not row.ret then taking[row] = true end
end

local function Unmark(index)
	local row = last and last[index]
	if row then taking[row] = nil end
end

-- Reads the send window as SendMail is called.
local function Sending(recipient, subject)
	local items = {}
	for slot = 1, ATTACHMENTS_MAX_SEND do
		local name, id, _, stack, quality = GetSendMailItem(slot)
		if id then
			Store.Note(id, quality, name)
			items[#items + 1] = Store.Pack(tostring(id), stack)
		end
	end
	local cod = GetSendMailCOD()
	sending = { to = Plain(recipient), subj = Plain(subject), money = GetSendMailMoney() or 0,
		cod = (cod and cod > 0) and cod or nil, items = items }
	ns.Check.Say("C13", (#items > 0 or sending.money > 0) and true or nil,
		#items .. " items and " .. sending.money .. " copper read as a mail was sent")
end

local function Sent()
	local s = sending
	sending = nil
	local me = Store.Me()
	local c = s and me and Mine(s.to)
	if not c or (#s.items == 0 and s.money == 0) then return end
	c.mail = c.mail or { rows = {}, more = 0 }
	table.insert(c.mail.rows, { from = Store.Name(me), subj = s.subj, money = s.money, cod = s.cod,
		exp = ns.Now() + SENT_FOR, items = s.items, sent = true })
	Shy:Fire("SHY_BAGS_SCANNED", Store.Guid(), "sent")
end

-- Drops expired mail and warns once about mail expiring soon.
local function Tidy()
	local now = ns.Now()
	local soon = {}
	for _, entry in ipairs(Store.List()) do
		local c = entry.char
		if c.mail then
			local kept, urgent = {}, false
			for _, row in ipairs(c.mail.rows) do
				if row.exp > now then
					kept[#kept + 1] = row
					if row.exp - now < SOON and (row.money > 0 or #row.items > 0) then urgent = true end
				end
			end
			c.mail.rows = kept
			if urgent then soon[#soon + 1] = Store.Name(c) end
		end
	end
	if #soon > 0 then
		T:Print("mail with items or gold expires soon: " .. table.concat(soon, ", ") .. ".")
	end
end

function Mail.Init()
	hooksecurefunc("TakeInboxMoney", Mark)
	hooksecurefunc("AutoLootMailItem", Mark)
	hooksecurefunc("ReturnInboxItem", Unmark)
	hooksecurefunc("SendMail", Sending)

	local events = CreateFrame("Frame")
	events:RegisterEvent("MAIL_SHOW")
	events:RegisterEvent("MAIL_CLOSED")
	events:RegisterEvent("MAIL_INBOX_UPDATE")
	events:RegisterEvent("MAIL_SEND_SUCCESS")
	events:RegisterEvent("MAIL_FAILED")
	events:SetScript("OnEvent", function(_, event)
		if event == "MAIL_SHOW" then
			open, last = true, nil
		elseif event == "MAIL_CLOSED" then
			open, last = false, nil
		elseif event == "MAIL_INBOX_UPDATE" then
			Queue()
		elseif event == "MAIL_SEND_SUCCESS" then
			ns.Guard(Sent)
		else
			sending = nil
		end
	end)
	ns.Guard(Tidy)
end
