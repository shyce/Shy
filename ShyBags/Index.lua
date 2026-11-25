-- Every item by character and place: built lazily from the store, in memory only.
--   entry = { guid, source, item, id, count, name, bound, quest, starter, at, exp }
--   source is "bags", "keys", "bank", "mail" or "auction"; exp is the earliest expiry (mail, auctions)

local ADDON, ns = ...
local Store = ns.Store

local Index = {}
ns.Index = Index

local KEYS = Enum.BagIndex.Keyring
local byChar = {}   -- guid -> entries; nil means rebuild

local function Add(entries, found, guid, source, slot, at, exp)
	local item, count, flags, name = Store.Unpack(slot)
	if not item then return end
	local key = source .. "\n" .. item
	local entry = found[key]
	if not entry then
		entry = { guid = guid, source = source, item = item, id = Store.ItemID(item), count = 0, name = name, at = at,
			bound = flags:find("b", 1, true) ~= nil, quest = flags:find("[qs]") ~= nil, starter = flags:find("s", 1, true) ~= nil }
		found[key] = entry
		entries[#entries + 1] = entry
	end
	entry.count = entry.count + count
	if exp and (not entry.exp or exp < entry.exp) then entry.exp = exp end
end

local function Build(guid, c)
	local entries, found = {}, {}
	for bag, list in pairs(c.bags or {}) do
		if type(list) == "table" then
			local source = bag == KEYS and "keys" or "bags"
			for _, slot in ipairs(list) do Add(entries, found, guid, source, slot, c.bags.at) end
		end
	end
	for _, list in pairs(c.bank or {}) do
		if type(list) == "table" then
			for _, slot in ipairs(list) do Add(entries, found, guid, "bank", slot, c.bank.at) end
		end
	end
	for _, row in ipairs(c.mail and c.mail.rows or {}) do
		for _, slot in ipairs(row.items) do Add(entries, found, guid, "mail", slot, c.mail.at, row.exp) end
	end
	for _, auction in ipairs(c.auctions or {}) do
		if not auction.sold then
			Add(entries, found, guid, "auction", Store.Pack(auction.item, auction.n), c.auctions.at, auction.exp)
		end
	end
	return entries
end

function Index.Of(guid)
	local entries = byChar[guid]
	if not entries then
		local c = Store.Char(guid)
		entries = c and Build(guid, c) or {}
		byChar[guid] = entries
	end
	return entries
end

function Index.All()
	local all = {}
	for _, entry in ipairs(Store.List()) do
		for _, e in ipairs(Index.Of(entry.guid)) do all[#all + 1] = e end
	end
	return all
end

-- A character's entries by item: made once a list (a character's list is made anew when what it holds changes),
-- so counting one item is a look in each character's, not a walk through all they hold.
local idsOf = setmetatable({}, { __mode = "k" })   -- entries -> item id -> its entries
local NONE = {}
local function ById(entries)
	local by = idsOf[entries]
	if not by then
		by = {}
		for _, e in ipairs(entries) do
			if e.id then
				local list = by[e.id]
				if not list then
					list = {}
					by[e.id] = list
				end
				list[#list + 1] = e
			end
		end
		idsOf[entries] = by
	end
	return by
end

-- Returns the total and { guid, char, bags, keys, bank, mail, auction, at } per character.
function Index.Count(id)
	local total, places = 0, {}
	for _, entry in ipairs(Store.List()) do
		local place
		for _, e in ipairs(ById(Index.Of(entry.guid))[id] or NONE) do
			place = place or { guid = entry.guid, char = entry.char, bags = 0, keys = 0, bank = 0, mail = 0, auction = 0 }
			place[e.source] = place[e.source] + e.count
			if e.at and (not place.at or e.at < place.at) then place.at = e.at end
			total = total + e.count
		end
		if place then places[#places + 1] = place end
	end
	return total, places
end

-- For other addons.
function ns.T:Count(id)
	return Index.Count(id)
end

-- For other addons: what this character's mailbox held when it was last read, item -> how many (letters one of
-- your other characters sent, not yet seen arriving, among them); and the same of its bank. One table each,
-- written again when the place is read: not to keep or change.
local held = {}
local function Held(source)
	local counts = held[source]
	if not counts then
		counts = {}
		for _, e in ipairs(Index.Of(Store.Guid())) do
			if e.source == source and e.id then counts[e.id] = (counts[e.id] or 0) + e.count end
		end
		held[source] = counts
	end
	return counts
end

function ns.T:Mailed()
	return Held("mail")
end

function ns.T:Banked()
	return Held("bank")
end

-- For other addons: totals over your characters on this realm, each kept until ShyBags reads something again.
--   :Gold()          { hand, mail, sold, chars }: copper carried, waiting in mailboxes, and from auctions sold
--   :Currency(id)    how many of a currency they hold
--   :Total(ids)      how many of these items they hold, everywhere ShyBags reads (ids: a set, { [itemID] = true })
local stamp = 0
local gold, goldAt
local currencies, currenciesAt = {}, nil
local totals = setmetatable({}, { __mode = "k" })   -- ids -> { at = stamp, n }

function ns.T:Gold()
	if goldAt ~= stamp then
		gold = gold or {}
		gold.hand, gold.mail, gold.sold, gold.chars = 0, 0, 0, 0
		for _, entry in ipairs(Store.List()) do
			local c = entry.char
			if not c.skip then
				local mail, sold = ns.Ledger.Waiting(c)
				gold.hand, gold.mail, gold.sold = gold.hand + (c.money or 0), gold.mail + mail, gold.sold + sold
				gold.chars = gold.chars + 1
			end
		end
		goldAt = stamp
	end
	return gold
end

function ns.T:Currency(id)
	if currenciesAt ~= stamp then
		wipe(currencies)
		for _, entry in ipairs(Store.List()) do
			if not entry.char.skip then
				for each, n in pairs(entry.char.currencies or NONE) do currencies[each] = (currencies[each] or 0) + n end
			end
		end
		currenciesAt = stamp
	end
	return currencies[id] or 0
end

function ns.T:Total(ids)
	local kept = totals[ids]
	if kept and kept.at == stamp then return kept.n end
	local n = 0
	for _, entry in ipairs(Store.List()) do
		local by = ById(Index.Of(entry.guid))
		for id in pairs(ids) do
			for _, e in ipairs(by[id] or NONE) do n = n + e.count end
		end
	end
	totals[ids] = { at = stamp, n = n }
	return n
end

Shy:On("SHY_BAGS_SCANNED", function(guid)
	byChar[guid] = nil
	stamp = stamp + 1
	if guid == Store.Guid() then wipe(held) end
end)
