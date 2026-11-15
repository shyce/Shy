-- Search syntax, compiled once into a test over Index.lua entries (no server queries, no tooltip scans).
--   linen cloth        every word must be in the name
--   q:rare  q:3        quality by name prefix or number
--   t:armor  t:chest   item type, subtype or equip slot
--   lvl:30  lvl:>30  lvl:<30  lvl:30-40     required level
--   @lil               owner
--   boe, bound, quest, junk, bags, bank, mail, auction, keys, and registered keywords
--   -word              negation
--   Search.Compile(text)     returns test(item), or nil for an empty search
--   Search.Run(text)         { { item, id, name, quality, total, places = { { guid, char, source, count, at, exp } } } }
--   Search.Register({ word, help, test })

local ADDON, ns = ...
local Store = ns.Store

local Search = {}
ns.Search = Search

local keywords, order = {}, {}

function Search.Register(def)
	local word = def.word:lower()
	if not keywords[word] then order[#order + 1] = word end
	keywords[word] = def
end

-- Cached on the entry; callers reset item.known per search.
local function Facts(item)
	if item.known then return end
	item.known = true
	local quality, level, bind, plain = Store.Fact(item.id or 0)
	item.quality, item.level, item.bind = quality, level, bind
	item.title = (item.name or plain or ""):lower()
end

local function Kind(item)
	if item.kind then return item.kind end
	local _, kind, sub, slot = C_Item.GetItemInfoInstant(item.id or 0)
	item.kind = ((kind or "") .. "\n" .. (sub or "") .. "\n" .. ((slot and slot ~= "" and _G[slot]) or "")):lower()
	return item.kind
end

local function Owner(item)
	if not item.owner then
		local c = Store.Char(item.guid)
		item.owner = c and Store.Name(c):lower() or ""
	end
	return item.owner
end

for _, source in ipairs({ "bags", "bank", "mail", "auction", "keys" }) do
	Search.Register({ word = source, help = "items in that place", test = function(item) return item.source == source end })
end
Search.Register({ word = "bound", help = "soulbound", test = function(item) return item.bound end })
Search.Register({ word = "boe", help = "binds on equip, not bound yet", test = function(item)
	Facts(item)
	return item.bind == Enum.ItemBind.OnEquip and not item.bound
end })
Search.Register({ word = "quest", help = "quest items and quest starters", test = function(item) return item.quest end })
Search.Register({ word = "junk", help = "grey items and leftovers from finished quests", test = function(item)
	Facts(item)
	return item.quality == Enum.ItemQuality.Poor or ns.Marks.Over(item)
end })

-- "rare", "unc" or "3" to a quality number.
local function Quality(text)
	local n = tonumber(text)
	if n then return n end
	for quality = 0, 7 do
		local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
		if name and name:lower():sub(1, #text) == text then return quality end
	end
end

-- One word as a test; nil if it adds no constraint.
local function Term(word)
	local prefix, rest = word:match("^(%a+):(.+)$")
	if prefix == "q" then
		local quality = Quality(rest)
		if not quality then return function() return false end end
		return function(item)
			Facts(item)
			return item.quality == quality
		end
	elseif prefix == "t" then
		return function(item) return Kind(item):find(rest, 1, true) ~= nil end
	elseif prefix == "lvl" then
		local low, high = rest:match("^(%d+)%-(%d+)$")
		local sign, number = rest:match("^([<>]?)(%d+)$")
		low, high, number = tonumber(low), tonumber(high), tonumber(number)
		if not (low or number) then return function() return false end end
		return function(item)
			Facts(item)
			local level = item.level or 0
			if low then return level >= low and level <= high end
			if sign == ">" then return level > number end
			if sign == "<" then return level < number end
			return level == number
		end
	end
	if word:sub(1, 1) == "@" then
		local who = word:sub(2)
		if who == "" then return nil end
		return function(item) return Owner(item):find(who, 1, true) ~= nil end
	end
	if keywords[word] then return keywords[word].test end
	return function(item)
		Facts(item)
		return item.title:find(word, 1, true) ~= nil
	end
end

function Search.Compile(text)
	local tests = {}
	for raw in (text or ""):lower():gmatch("%S+") do
		local negate = raw:sub(1, 1) == "-" and #raw > 1
		local test = Term(negate and raw:sub(2) or raw)
		if test then
			if negate then
				local inner = test
				test = function(item) return not inner(item) end
			end
			tests[#tests + 1] = test
		end
	end
	if #tests == 0 then return nil end
	return function(item)
		for _, test in ipairs(tests) do
			if not test(item) then return false end
		end
		return true
	end
end

-- One row per distinct item across every character, sorted by name.
function Search.Run(text)
	local test = Search.Compile(text)
	if not test then return {} end
	local rows, byItem = {}, {}
	for _, item in ipairs(ns.Index.All()) do
		item.known, item.kind, item.owner = nil, nil, nil
		if test(item) then
			Facts(item)
			local row = byItem[item.item]
			if not row then
				local _, _, _, plain = Store.Fact(item.id or 0)
				row = { item = item.item, id = item.id, name = item.name or plain or ("item " .. tostring(item.id)),
					quality = item.quality, total = 0, places = {} }
				byItem[item.item] = row
				rows[#rows + 1] = row
			end
			row.total = row.total + item.count
			row.places[#row.places + 1] = { guid = item.guid, char = Store.Char(item.guid), source = item.source,
				count = item.count, at = item.at, exp = item.exp }
		end
	end
	table.sort(rows, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		return a.item < b.item
	end)
	return rows
end

-- For other addons.
function ns.T:RegisterKeyword(def)
	Search.Register(def)
end

function Search.Help()
	local lines = {
		"linen cloth - every word must be in the name",
		"q:rare - quality, by name or number",
		"t:armor - item type, subtype or equip slot",
		"lvl:30, lvl:>30, lvl:30-40 - required level",
		"@name - owner",
		"-word - exclude",
	}
	for _, word in ipairs(order) do lines[#lines + 1] = word .. " - " .. keywords[word].help end
	return lines
end

local PLACE = { bags = "bags", keys = "key ring", bank = "bank", mail = "mailbox", auction = "auction house" }
ns.Command("find", "search every character: /shybags find linen", function(text)
	if strtrim(text) == "" then
		ns.T:Print("search terms for /shybags find:")
		for _, line in ipairs(Search.Help()) do print("  " .. line) end
		return
	end
	local lines = {}
	for _, row in ipairs(Search.Run(text)) do
		local places = {}
		for _, place in ipairs(row.places) do
			local who = place.char and Store.Name(place.char) or "?"
			local age = ""
			if place.guid ~= Store.Guid() and place.at then age = ", seen " .. ns.Ago(place.at) end
			places[#places + 1] = who .. ": " .. place.count .. " in the " .. PLACE[place.source] .. age
		end
		lines[#lines + 1] = row.name .. " x" .. row.total .. "\n    " .. table.concat(places, "\n    ")
	end
	if #lines == 0 then lines[1] = "No matches." end
	Shy.UI.ShowCopyBox("ShyBags: " .. text, table.concat(lines, "\n"))
end)
