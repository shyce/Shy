-- What a kill is worth: the coin a creature carries and everything it drops, each by how often (Data/Loot.lua), at
-- what you value each thing (Prices.lua). Your own corpses (T.db.seen) weigh in as you loot more of a creature.
--
--   K.Creature(id)     { coin, respawn, drops = { { item, chance, count } }, tables = { { table, chance, times } } } or nil
--   K.Table(id)        a shared table's drops, each given it is rolled once: { { item, chance, count } }
--   K.Item(id)         { sell, quality, bound } from the data, or nil
--   K.Worth(id)        copper a kill brings on average (coin, then loot at your prices), or nil for no creature we know
--   K.Best(id, n)      what brings most of it: { { item, per (how many a kill), copper (a kill's share) } }, best first

local ADDON, ns = ...
local T = ns.T

local K = {}
ns.Worth = K

local SCALE = 10000          -- the data's chances are in hundredths of a percent
local TRUST = 20             -- corpses of your own that weigh as much as the data's word
local loot = ns.loot or { creatures = {}, tables = {}, items = {} }
local creatures, tables, items = {}, {}, {}
local stamp = 0              -- K.Stale() moves it: every price is asked again
local tableWorth = {}        -- table -> { stamp, copper a roll }

-- A record's fields, "a^b^c": the first four.
local function Fields(text)
	return text:match("^([^^]*)%^?([^^]*)%^?([^^]*)%^?([^^]*)")
end

local function Drops(text, whole)
	local out = {}
	for id, chance, count in (text or ""):gmatch("(%d+):(%d+):?(%d*)") do
		local n = tonumber(count)
		out[#out + 1] = { item = tonumber(id), chance = tonumber(chance) / SCALE, count = n and (whole and n or n / 10) or 1 }
	end
	return out
end

function K.Creature(id)
	local kept = creatures[id]
	if kept == nil then
		local text = loot.creatures[id]
		if text then
			local coin, respawn, drops, rolls = Fields(text)
			kept = { coin = tonumber(coin) or 0, respawn = tonumber(respawn) or 300, drops = Drops(drops), tables = {} }
			for _, roll in ipairs(Drops(rolls, true)) do
				kept.tables[#kept.tables + 1] = { table = roll.item, chance = roll.chance, times = roll.count }
			end
		end
		creatures[id] = kept or false
	end
	return kept or nil
end

-- A shared table's drops, each given the table is rolled once: { { item, chance, count } }.
local function Table(id)
	local kept = tables[id]
	if not kept then
		kept = Drops(loot.tables[id])
		tables[id] = kept
	end
	return kept
end

K.Table = Table

function K.Item(id)
	local kept = items[id]
	if kept == nil then
		local text = loot.items[id]
		if text then
			local sell, quality, bound = Fields(text)
			kept = { sell = tonumber(sell) or 0, quality = tonumber(quality) or 1, bound = bound == "b" }
		end
		items[id] = kept or false
	end
	return kept or nil
end

-- Prices changed: every worth is reckoned again as it is next asked.
function K.Stale() stamp = stamp + 1 end

local function Value(item)
	return ns.Prices.Value(item) or 0
end

local function RollWorth(id)
	local kept = tableWorth[id]
	if kept and kept.stamp == stamp then return kept.copper end
	local copper = 0
	for _, drop in ipairs(Table(id)) do copper = copper + drop.chance * drop.count * Value(drop.item) end
	tableWorth[id] = { stamp = stamp, copper = copper }
	return copper
end

-- The data's word: copper of loot a kill brings (the coin apart).
local function Loot(c)
	local copper = 0
	for _, drop in ipairs(c.drops) do copper = copper + drop.chance * drop.count * Value(drop.item) end
	for _, roll in ipairs(c.tables) do copper = copper + roll.chance * roll.times * RollWorth(roll.table) end
	return copper
end

function K.Worth(id)
	local c = K.Creature(id)
	if not c then return nil end
	local copper = Loot(c)
	local seen = T.db.seen[id]
	if seen and seen.n and seen.n > 0 then
		local own = 0
		for item, count in pairs(seen.i or {}) do own = own + count * Value(item) end
		copper = (copper * TRUST + own) / (TRUST + seen.n)
	end
	return c.coin + copper
end

function K.Best(id, most)
	local c = K.Creature(id)
	if not c then return {} end
	local per = {}
	for _, drop in ipairs(c.drops) do per[drop.item] = (per[drop.item] or 0) + drop.chance * drop.count end
	for _, roll in ipairs(c.tables) do
		for _, drop in ipairs(Table(roll.table)) do
			per[drop.item] = (per[drop.item] or 0) + roll.chance * roll.times * drop.chance * drop.count
		end
	end
	local out = {}
	for item, n in pairs(per) do
		local copper = n * Value(item)
		if copper > 0 then out[#out + 1] = { item = item, per = n, copper = copper } end
	end
	table.sort(out, function(a, b)
		if a.copper ~= b.copper then return a.copper > b.copper end
		return a.item < b.item
	end)
	for i = #out, (most or 5) + 1, -1 do out[i] = nil end
	return out
end
