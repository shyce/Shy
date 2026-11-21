-- What you could farm: creatures out in the world, and the items you get from them or from nodes.
-- Not farms: townsfolk, guards, vendors, quest givers, your friends, anything only sold, and anyone
-- only in a dungeon. With ShyFarm on, a creature must be in its loot tables (it has something to loot).
--
--   Fa.Creature(npc)          whether you could farm a creature
--   Fa.Item(id)               where an item is best farmed: { kind = "n" | "o", id, name, chance } (the creature
--                             likeliest to drop it, else a node that holds it), or nil for one you can't farm
--   Fa.Search(text, kinds)    T:Farmable's answer (ShyQuest.lua has its fields)

local ADDON, ns = ...
local D = ns.Data

local Fa = {}
ns.Farmable = Fa

-- Most of each kind a search gives, most in all, letters before one; how many of a kind are weighed for your level
-- before the best are kept; levels over yours a creature may be and still be one you'd farm (ShyQuest's own rule).
local K = { each = 14, most = 40, least = 2, pool = 80, above = 3 }
local FACTION = { A = true, H = true }          -- one side's own: its guards and its towns' people

local creatures, asked = {}, 0   -- [npc] = true | false, once asked (no more than the data's creatures)
if Shy.Memory then
	Shy.Memory.Cache("quest: farmable creatures", function()
		wipe(creatures)
		asked = 0
	end, function() return asked end)
end

local function Outside(thing)
	for _, place in ipairs(thing.places or {}) do
		if not place.dungeon then return true end
	end
	return false
end

-- (ShyFarm's loot tables, when it is on: a creature they don't know has nothing to loot.)
local function Loots(npc)
	local farm = Shy.addons.Farm
	if not (farm and farm.Loots) then return true end
	return farm:Loots(npc)
end

function Fa.Creature(npc)
	local known = creatures[npc]
	if known ~= nil then return known end
	local thing = D.Npc(npc)
	local ok = thing ~= nil and not thing.title and not (thing.gives and #thing.gives > 0) and not (thing.takes and #thing.takes > 0)
		and not D.Internal(thing.name) and not FACTION[thing.side] and thing.maxLevel > 0 and Outside(thing) and Loots(npc)
	creatures[npc] = ok and true or false
	asked = asked + 1
	return ok and true or false
end

function Fa.Item(id)
	local item = D.Item(id)
	if not item then return nil end
	local best, node
	for _, source in ipairs(item.sources) do
		if source.kind == "n" and not D.Dropless(source.id, id) and Fa.Creature(source.id) then
			if not best or (source.chance or 0) > (best.chance or 0) then best = source end
		elseif source.kind == "o" and not node then
			local thing = D.Object(source.id)
			if thing and Outside(thing) then node = source end
		end
	end
	if not best then
		for _, npc in ipairs(item.more or {}) do
			if not D.Dropless(npc, id) and Fa.Creature(npc) then
				best = { kind = "n", id = npc }
				break
			end
		end
	end
	local from = best or node
	if not from then return nil end
	local thing = D.Thing(from.kind, from.id)
	return { kind = from.kind, id = from.id, name = thing and thing.name, chance = from.chance }
end

-- One kind's names holding `text`, prefix matches first, as many as `room` that pass `ok(id)`; a creature's IDs of
-- one name are one entry.
local function Matches(kind, text, room, ok)
	local starts, has, by = {}, {}, {}
	for _, entry in ipairs(D.Names(kind)) do
		local at = entry[2]:find(text, 1, true)
		if at then
			local same = by[entry[2]]
			if same and kind == "npcs" then
				same[#same + 1] = entry[1]
			elseif not same then
				local ids = { entry[1] }
				by[entry[2]] = ids
				local into = at == 1 and starts or has
				into[#into + 1] = ids
			end
		end
	end
	local out = {}
	for _, from in ipairs({ starts, has }) do
		for _, ids in ipairs(from) do
			if #out >= room then return out end
			local kept = {}
			for _, id in ipairs(ids) do
				if ok(id) then kept[#kept + 1] = id end
			end
			if #kept > 0 then out[#out + 1] = kept end
		end
	end
	return out
end

-- How well a creature suits you to farm, lower better: one at your level first, one below by how far below, one
-- more than K.above over you last. Nodes and creatures the data has no level for stand in the middle.
local function Fit(npc)
	local thing = npc and D.Npc(npc)
	if not (thing and thing.maxLevel > 0) then return 20 end
	local level = ns.Log.Level()
	if thing.minLevel > level + K.above then return 100 + thing.minLevel - level end
	return math.max(0, level - thing.maxLevel)
end

-- Best first: the one that suits your level, then a name that begins with what was typed, then by name.
local function Order(list, text)
	for _, each in ipairs(list) do
		each.fit = Fit(each.kind == "creature" and each.id or (not each.node and each.fromId) or nil)
		each.starts = each.name:lower():find(text, 1, true) == 1
	end
	table.sort(list, function(a, b)
		if a.fit ~= b.fit then return a.fit < b.fit end
		if a.starts ~= b.starts then return a.starts end
		return a.name < b.name
	end)
	for i = #list, K.each + 1, -1 do list[i] = nil end
	return list
end

function Fa.Search(text, kinds)
	local list = {}
	text = strtrim(text or ""):lower()
	if #text < K.least then return list end
	kinds = kinds or { creature = true, item = true }
	if kinds.creature then
		local found = {}
		for _, ids in ipairs(Matches("npcs", text, K.pool, Fa.Creature)) do
			local thing = D.Npc(ids[1])
			found[#found + 1] = { kind = "creature", id = ids[1], ids = ids, name = thing.name, level = D.LevelText(thing) }
		end
		for _, each in ipairs(Order(found, text)) do list[#list + 1] = each end
	end
	if kinds.item then
		local froms, found = {}, {}
		local function Farmed(id)
			froms[id] = Fa.Item(id)
			return froms[id] ~= nil
		end
		for _, ids in ipairs(Matches("items", text, K.pool, Farmed)) do
			local id, from = ids[1], froms[ids[1]]
			found[#found + 1] = { kind = "item", id = id, ids = ids, name = D.Name("items", id), from = from.name,
				fromId = from.id, chance = from.chance, node = from.kind == "o" }
		end
		for _, each in ipairs(Order(found, text)) do list[#list + 1] = each end
	end
	for i = #list, K.most + 1, -1 do list[i] = nil end
	return list
end
