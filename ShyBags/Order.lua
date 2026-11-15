-- Order: how your own bags are shown. Display only: nothing in the bags moves.
--   T.db.order    "bags" (as they are), "type" (by kind of item, then name), "worth" (by vendor price) or
--                 "age" (by when each item arrived)
--   T.db.backward by type: from the last slot back, the empty slots leading (otherwise from the first slot)
--   T.db.costly   by price: most expensive first (otherwise cheapest first)
--   T.db.oldest   by age: oldest first (otherwise newest first)
-- By type is the order a bag is read in, what to keep first and what can go last, so where one ends and
-- the other begins is plain: the hearthstone, what you wear, what you use up, what your class runs on
-- (ammunition, poisons, reagents), the rest, what your quests need (needed now, then needed later, each in
-- the order its quests come), and then what can go: quest items no quest needs any more, and junk. Within
-- each by kind, then name, the bigger stack of the same item first. How a thing stands with your quests is
-- what its mark shows (Marks.Stands).
-- Stacks without a price follow the priced ones; empty slots come last, except by type backward, where they
-- lead in the order the game fills them: what you pick up next lands in the top left, apart from the sort.
-- The layout is read when the window opens or an order is picked. After that slots stay where they are, so
-- nothing moves under the mouse; once the bags have changed, the menu row offers the same sort again.
-- An item's age is when its count in your bags last went up:
--   character.age = { [itemID] = { time, count } }   time 0: held before ages were kept
--   Order.Key()                 names the layout (nil: bag order); changes when a fresh one is wanted
--   Order.Places(bags, sizes)   every slot as { bag, slot }, in order
--   Order.Set(kind, reversed)   reversed nil keeps that order's saved direction
--   Order.Rows(grid)            the window menu's rows
--   Order.Latest()              the sort picked last: kind, its wording, whether it is in use; Order.Again() repeats it

local ADDON, ns = ...
local T = ns.T
local Store = ns.Store

local Order = {}
ns.Order = Order

T.defaults.order = "bags"
T.defaults.backward = false
T.defaults.costly = false
T.defaults.oldest = false
T.defaults.latest = "type"   -- the sort picked last, for the rail's "sort again"

local FIRST, LAST = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag
local HEARTHSTONE = 6948
local POOR = Enum.ItemQuality.Poor
local CLASS, USE, MISC = Enum.ItemClass, Enum.ItemConsumableSubclass, Enum.ItemMiscellaneousSubclass

-- flip: the setting that reverses it. rising: lowest first unless reversed. [false] / [true]: its wording
-- as it stands and reversed; tip: what its row says while it is in use (otherwise made from `by`).
local KINDS = {
	type = {
		flip = "backward", by = "type, then name",
		[false] = {
			name = "By type", again = "Re-sort by type",
			tip = "Sorted by type, then name: what to keep first, what can go last. Click again to sort from the last slot back, so new items land at the top left.",
		},
		[true] = {
			name = "By type, reversed", again = "Re-sort by type",
			tip = "Sorted by type, then name, from the last slot back, so new items land at the top left. Click again to sort from the first slot.",
		},
	},
	worth = {
		flip = "costly", rising = true, by = "vendor price",
		[false] = { name = "Cheapest first", again = "Re-sort by cheapest" },
		[true] = { name = "Most expensive first", again = "Re-sort by most expensive" },
	},
	age = {
		flip = "oldest", rising = false, by = "when you got each item",
		[false] = { name = "Newest first", again = "Re-sort by newest" },
		[true] = { name = "Oldest first", again = "Re-sort by oldest" },
	},
}
local LISTED = { "type", "worth", "age" }

local serial = 0        -- bumped to force a fresh layout
local partial = false   -- the layout was made before every price was loaded

local function Kind()
	local kind = T.db.order
	return KINDS[kind] and kind or nil
end

local function Reversed(kind)
	return T.db[KINDS[kind].flip] == true
end

function Order.Key()
	local kind = Kind()
	if not kind then return nil end
	return kind .. (Reversed(kind) and "-" or "+") .. serial
end

-- By type, the kinds within a group stand in these orders; one not listed follows them.
local function Ranks(list)
	local ranks = {}
	for rank, kind in ipairs(list) do ranks[kind] = rank end
	return ranks
end
local USED = Ranks({ USE.Potion, USE.Elixir, USE.Flasksphials, USE.Bandage, USE.Fooddrink, USE.Scroll, USE.Other, USE.Generic,
	USE.Device })
local REST = Ranks({ CLASS.Tradegoods, CLASS.Gem, CLASS.ItemEnhancement, CLASS.Recipe, CLASS.Questitem, CLASS.Key,
	CLASS.Container, CLASS.Quiver, CLASS.Miscellaneous })
local OTHER = 100

-- Where an item stands by type: its group, its kind within the group, and the kind within that.
--   1 the hearthstone   2 what you wear   3 what you use up   4 what your class runs on (ammunition, then
--   poisons, stones and oils, then reagents)   5 the rest   6 what your quests need (now, then later; within
--   each the sooner its quest comes)   7 what can go (quest leftovers, then junk)
local QUESTS = { now = 1, later = 2 }
local GOES = { over = 0, junk = 1 }
local function Stand(id, quality, bag, slot)
	if id == HEARTHSTONE then return 1, 0, 0 end
	local how, soon = ns.Marks.Stands(id, bag, slot)
	if how == "over" then return 7, GOES.over, 0 end
	if how then return 6, QUESTS[how], soon or math.huge end
	local _, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(id)
	class, sub = class or CLASS.Miscellaneous, sub or 0
	if quality == POOR then return 7, GOES.junk + class, sub end
	if class == CLASS.Weapon or class == CLASS.Armor then return 2, class, sub end
	if class == CLASS.Projectile then return 4, 1, sub end
	-- The game files these as consumables of no kind; the list is in Data/Coatings.lua.
	if ns.coatings and ns.coatings[id] then return 4, 2, 0 end
	if class == CLASS.Reagent or (class == CLASS.Miscellaneous and sub == MISC.Reagent) then return 4, 3, 0 end
	if class == CLASS.Consumable then return 3, USED[sub] or (OTHER + sub), 0 end
	return 5, REST[class] or (OTHER + class), sub
end

-- By type: a place carries where it stands, its name and its item from the third field on, then its count.
local function ByType(a, b)
	for field = 3, 7 do
		if a[field] ~= b[field] then return a[field] < b[field] end
	end
	if a[8] ~= b[8] then return a[8] > b[8] end
	if a[1] ~= b[1] then return a[1] < b[1] end
	return a[2] < b[2]
end

function Order.Places(bags, sizes)
	local kind = Kind()
	if not kind then return nil end
	local room, me = ns.Room, Store.Me()
	local age = me and me.age or {}
	local ranked, rest, bare = {}, {}, {}
	for _, bag in ipairs(bags) do
		for slot = 1, sizes[bag] or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			local place = { bag, slot }
			if not id then
				bare[#bare + 1] = place
			elseif kind == "type" then
				place[3], place[4], place[5] = Stand(id, info.quality, bag, slot)
				place[6], place[7], place[8] = info.itemName or "", id, info.stackCount or 1
				ranked[#ranked + 1] = place
			else
				if kind == "worth" then
					place[3] = room and room.Value(bag, slot)
				else
					place[3] = age[id] and age[id][1] or 0
				end
				if place[3] then ranked[#ranked + 1] = place else rest[#rest + 1] = place end
			end
		end
	end
	partial = kind == "worth" and room ~= nil and room.Unread() > 0
	if kind == "type" then
		table.sort(ranked, ByType)
		if not Reversed(kind) then
			for _, place in ipairs(bare) do ranked[#ranked + 1] = place end
			return ranked
		end
		-- Backward: the sort ends in the last slot, and the empty slots lead as the game fills them.
		for index = #ranked, 1, -1 do bare[#bare + 1] = ranked[index] end
		return bare
	end
	local rising = KINDS[kind].rising ~= Reversed(kind)
	table.sort(ranked, function(a, b)
		if a[3] ~= b[3] then
			if rising then return a[3] < b[3] end
			return a[3] > b[3]
		end
		if a[1] ~= b[1] then return a[1] < b[1] end
		return a[2] < b[2]
	end)
	for _, place in ipairs(rest) do ranked[#ranked + 1] = place end
	for _, place in ipairs(bare) do ranked[#ranked + 1] = place end
	return ranked
end

function Order.Set(kind, reversed)
	kind = KINDS[kind] and kind or "bags"
	T.db.order = kind
	if KINDS[kind] then
		T.db.latest = kind
		if reversed ~= nil then T.db[KINDS[kind].flip] = reversed and true or false end
	end
	serial = serial + 1
	if ns.Window then ns.Window.Refresh() end
end

-- The sort used last (by type until one is picked): its kind, its wording as it stands, and whether it
-- is the order in use.
function Order.Latest()
	local kind = KINDS[T.db.latest] and T.db.latest or "type"
	return kind, KINDS[kind][Reversed(kind)], Kind() == kind
end

-- Sorts by the latest sort again: a fresh layout of the same order.
function Order.Again()
	Order.Set((Order.Latest()))
end

-- Room.lua calls this once every price is loaded.
function Order.Priced()
	if not partial then return end
	partial = false
	serial = serial + 1
	if ns.Window then ns.Window.Refresh() end
end

-- The menu: bag order and each sort. The sort in use flips its direction on a click, and its wording with
-- it; once the bags have changed it offers the same sort again instead.
function Order.Rows(grid)
	local now = Kind()
	local rows = { {
		text = "Bag order", on = now == nil, keep = true,
		tip = "Shows your bags as they are, bag by bag.",
		click = function() Order.Set("bags") end,
	} }
	for _, kind in ipairs(LISTED) do
		local def = KINDS[kind]
		local reversed = Reversed(kind)
		local words, other = def[reversed], def[not reversed]
		local on = now == kind
		local again = on and grid ~= nil and not grid:Settled()
		local tip
		if again then
			tip = "Your bags changed since they were sorted. Click to sort them again."
		elseif on then
			tip = words.tip or ("Sorted by " .. def.by .. ". Click again for " .. other.name:lower() .. ".")
		else
			tip = "Shows your bags sorted by " .. def.by .. ". Nothing in your bags moves."
		end
		rows[#rows + 1] = {
			text = again and words.again or words.name, on = on, keep = true, tip = tip,
			click = function()
				if on and not again then Order.Set(kind, not reversed) else Order.Set(kind) end
			end,
		}
	end
	return rows
end

-- Ages

-- itemID -> how many are in the bags, from the last scan (Scan.lua).
-- Each bag's counts by item, kept while the scan keeps its list: a scan reads again only the bags that
-- changed (a new list for each), so a loot counts one bag, not every slot of every bag.
local counted = setmetatable({}, { __mode = "k" })   -- a bag's slot list -> { [item ID] = count }

local function Counts(list)
	local counts = counted[list]
	if counts then return counts end
	counts = {}
	for _, slot in ipairs(list) do
		local item, count = Store.Unpack(slot)
		local id = item and Store.ItemID(item)
		if id then counts[id] = (counts[id] or 0) + count end
	end
	counted[list] = counts
	return counts
end

local function Held(c)
	local held = {}
	for bag = FIRST, LAST do
		local list = c.bags[bag]
		if list then
			for id, count in pairs(Counts(list)) do held[id] = (held[id] or 0) + count end
		end
	end
	return held
end

local function Track()
	local c = Store.Me()
	if not (c and c.bags and c.bags[FIRST]) then return end
	local age, now = c.age, ns.Now()
	if not age then
		-- The first time, everything was here already.
		age, now = {}, 0
		c.age = age
	end
	local held = Held(c)
	for id, count in pairs(held) do
		local known = age[id]
		if not known then
			age[id] = { now, count }
		else
			if count > known[2] then known[1] = now end
			known[2] = count
		end
	end
	for id in pairs(age) do
		if not held[id] then age[id] = nil end
	end
end

-- For other addons (documented in ShyBags.lua)

function T:Sort(order, reversed)
	Order.Set(order, reversed == true)
	if Kind() then self:OpenWindow() end
	return T.db.order
end

function Order.Init()
	local c = Store.Me()
	if c and not c.age then Track() end
	-- The scan made at login is not compared: only what arrives while you play is new.
	Shy:On("SHY_BAGS_SCANNED", function(guid, source)
		if source == "bags" and guid == Store.Guid() then Track() end
	end)
end

local WORDS = {
	type = { "type", false }, ["type reversed"] = { "type", true },
	cheapest = { "worth", false }, expensive = { "worth", true },
	newest = { "age", false }, oldest = { "age", true },
	bags = { "bags" },
}

ns.Command("sort", "show your bags by type, cheapest, expensive, newest or oldest first, or as bags", function(rest)
	local pick = WORDS[strtrim(rest or ""):lower():gsub("%s+", " ")]
	if not pick then
		T:Print("/shybags sort type, type reversed, cheapest, expensive, newest, oldest or bags")
		return
	end
	Order.Set(pick[1], pick[2])
	local kind = Kind()
	T:Print(kind and ("bags shown " .. KINDS[kind][Reversed(kind)].name:lower() .. ".") or "bags shown in bag order.")
end)
