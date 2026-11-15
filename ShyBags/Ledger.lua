-- Gold received by mail and from the AH, per character.
--   character.ledger = { "when;kind;gold;what;count;deposit;cut;who", ... }   oldest first, newest 500
--   character.totals = { sale, mail, deposit, cut, sales }                    all time
--   character.days   = { ["YYYYMMDD"] = { sale, mail } }                      last 31 days
-- kind is sale, mail, refund (outbid) or transfer (own character); only sale and mail count as gold made.

local ADDON, ns = ...

local Ledger = {}
ns.Ledger = Ledger

local KEEP, DAYS = 500, 31
local MADE = { sale = true, mail = true }

local function Day(when)
	return date("%Y%m%d", when)
end

local function Trim(c)
	local oldest = Day(ns.Now() - DAYS * 86400)
	for key in pairs(c.days) do
		if key < oldest then c.days[key] = nil end
	end
end

function Ledger.Book(c, kind, gold, what, count, deposit, cut, who)
	local now = ns.Now()
	c.ledger = c.ledger or {}
	c.totals = c.totals or { sale = 0, mail = 0, deposit = 0, cut = 0, sales = 0 }
	c.days = c.days or {}
	-- Only names can contain the separator.
	local line = table.concat({ now, kind, gold, (tostring(what or ""):gsub(";", ",")), count or 1, deposit or 0, cut or 0,
		(tostring(who or ""):gsub(";", ",")) }, ";")
	table.insert(c.ledger, line)
	while #c.ledger > KEEP do table.remove(c.ledger, 1) end
	if MADE[kind] then
		c.totals[kind] = (c.totals[kind] or 0) + gold
		local day = c.days[Day(now)] or { sale = 0, mail = 0 }
		c.days[Day(now)] = day
		day[kind] = day[kind] + gold
		Trim(c)
	end
	if kind == "sale" then
		c.totals.sales = c.totals.sales + 1
		c.totals.deposit = c.totals.deposit + (deposit or 0)
		c.totals.cut = c.totals.cut + (cut or 0)
	end
	Shy:Fire("SHY_BAGS_SCANNED", ns.Store.Guid(), "ledger")
end

-- Gold from sales and from mail over the last `days` (nil: all time).
function Ledger.Made(c, days)
	if not c.totals then return 0, 0 end
	if not days then return c.totals.sale or 0, c.totals.mail or 0 end
	local sale, mail = 0, 0
	local oldest = Day(ns.Now() - (days - 1) * 86400)
	for key, day in pairs(c.days or {}) do
		if key >= oldest then
			sale, mail = sale + day.sale, mail + day.mail
		end
	end
	return sale, mail
end

function Ledger.Recent(c, n)
	local out = {}
	local list = c.ledger or {}
	for i = #list, math.max(1, #list - (n or KEEP) + 1), -1 do
		local when, kind, gold, what, count, deposit, cut, who = list[i]:match("^(%d+);(%a+);(%-?%d+);([^;]*);(%d+);(%d+);(%d+);(.*)$")
		if when then
			out[#out + 1] = { when = tonumber(when), kind = kind, gold = tonumber(gold), what = what, count = tonumber(count),
				deposit = tonumber(deposit), cut = tonumber(cut), who = who }
		end
	end
	return out
end

-- Gold in the mailbox, and gold from sold auctions not yet paid.
function Ledger.Waiting(c)
	local mail, auctions = 0, 0
	for _, row in ipairs(c.mail and c.mail.rows or {}) do mail = mail + (row.money or 0) end
	for _, auction in ipairs(c.auctions or {}) do
		if auction.sold then auctions = auctions + (auction.buyout or auction.bid or 0) end
	end
	return mail, auctions
end

function Ledger.Init()
	for _, entry in ipairs(ns.Store.List()) do
		if entry.char.days then Trim(entry.char) end
	end
end
