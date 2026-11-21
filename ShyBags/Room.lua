-- Room: vendor value of each stack, which items can safely go, and the window's "make room" mode.
-- Value is the client's sell price times the count (no tooltip scans, no server queries).
-- What can go, in order, then by value:
--   1  junk: grey items with a price, and leftovers of finished or abandoned quests (value 0, listed first)
--   2  plain materials: white, unbound trade goods, reagents and miscellaneous items
--   3  outgrown gear: bound weapons and armor ShyGear rates worse or unusable (only with ShyGear)
-- Never listed: active quest items, anything without a vendor price, consumables, green or better that is not
-- outgrown bound gear, unbound gear, ShyGear upgrades, containers with loot, T:Keep items, and anything in a
-- special bag (dropping it frees no ordinary slot).
-- The price label is the "top" channel of Marks.lua. It shows on every stack with a price while the bags are sorted
-- by price (Order.lua), otherwise on the cheapest one once the bags are nearly full. While making room it stays off
-- the items: the wing beside them lists what can go, and the one picked there is the slot left lit.
--   Room.Free()               free, total ordinary slots
--   Room.List()               everything that can go, cheapest first
--   Room.Lit(bag, slot)       the entry while that slot shows its price
--   Room.Value(bag, slot)     the stack's price as the labels show it; nil without one
--   Room.Unread()             items whose price the client has not loaded yet
--   Room.Coins(copper, tight) "1s 20c" in coin colors
--   Room.Told()               the wing's rows and text

local ADDON, ns = ...
local T = ns.T
local UI, Slot = Shy.UI, Shy.Slot
local C = UI.colors

local Room = {}
ns.Room = Room

Room.LOW = 3                -- free slots at which the bags count as nearly full
local FEW = 5               -- slots lit while making room
local FIRST, LAST = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4
local EVERY = Enum.BagIndex.ReagentBag   -- the last bag the window shows
local HEARTHSTONE = 6948
local POOR, COMMON = Enum.ItemQuality.Poor, Enum.ItemQuality.Common
local CLASS, MISC = Enum.ItemClass, Enum.ItemMiscellaneousSubclass

-- White items that count as plain materials: class -> true, or a set of subclasses.
local PLAIN = {
	[CLASS.Tradegoods] = true,
	[CLASS.Reagent] = true,
	[CLASS.Miscellaneous] = { [MISC.Junk] = true, [MISC.Reagent] = true, [MISC.Other] = true },
}

-- Coin colors are fixed; they do not follow the theme.
local COINS = { { 10000, "g", "ffffd100" }, { 100, "s", "ffc7c7cf" }, { 1, "c", "ffeda55f" } }

local list, at, seen       -- what can go; key -> entry; key -> value (false: none) of every filled slot
local loose = {}           -- key -> label entry of a priced slot that is not on the list
local stale = true
local free, total          -- ordinary slots, as last counted
local counted = false      -- the count is current
local plain = {}           -- bag -> holds any item
local sized = false        -- bag sizes are current
local state                -- { need, why } while making room
local keepers = {}         -- other addons' keep tests
local told                 -- what held for every slot at the last refresh (making room, the order)
local due = false
local unread = 0           -- items whose price the client had not loaded at the last read

local function Key(bag, slot) return bag * 1000 + slot end

-- "1s 20c": the two largest coins. tight: at most six characters, else the larger coin alone.
function Room.Coins(copper, tight)
	local left, parts, plainText = math.floor(copper or 0), {}, {}
	for _, coin in ipairs(COINS) do
		local n = math.floor(left / coin[1])
		left = left - n * coin[1]
		if n > 0 and #parts < 2 then
			parts[#parts + 1] = "|c" .. coin[3] .. n .. coin[2] .. "|r"
			plainText[#plainText + 1] = n .. coin[2]
		end
	end
	if #parts == 0 then return "|c" .. COINS[3][3] .. "0c|r" end
	if tight and #table.concat(plainText, " ") > 6 then return parts[1] end
	return table.concat(parts, " ")
end

-- Vendor value of a slot's stack. Second return: true while the item's data is not loaded yet.
local function Price(info)
	if info.hasNoValue then return nil end
	local price = select(11, C_Item.GetItemInfo(info.hyperlink or info.itemID))
	if not price then return nil, true end
	if price <= 0 then return nil end
	return price * (info.stackCount or 1)
end

function Room.Worth(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	return info and (Price(info)) or nil
end

-- ShyGear's verdict kind, if ShyGear is loaded.
local function Verdict(link)
	local gear = Shy.addons.Gear
	if not (gear and gear.Judge and link) then return nil end
	local ok, verdict = pcall(gear.Judge, gear, link)
	return ok and type(verdict) == "table" and verdict.kind or nil
end

local function Kept(id, bag, slot)
	for _, keep in ipairs(keepers) do
		local ok, yes = pcall(keep, id, bag, slot)
		if ok and yes then return true end
	end
	return false
end

-- Returns 1, 2 or 3 (see the file header) for an item that can go, else nil.
local function Tier(info, bag, slot, value)
	if info.hasLoot then return nil end
	local id, quality = info.itemID, info.quality
	if id == HEARTHSTONE or quality == nil then return nil end
	-- Quest items stay, except leftovers of finished quests: junk whatever their quality or price.
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	if quest and (quest.isQuestItem or quest.questID) then
		if ns.Marks.Leftover(id, bag, slot) and not Kept(id, bag, slot) then return 1, true end
		return nil
	end
	if not value then return nil end
	local _, _, _, equip, _, class, sub = C_Item.GetItemInfoInstant(id)
	local gear = (class == CLASS.Weapon or class == CLASS.Armor) and equip ~= nil and equip ~= ""
	local tier
	if quality == POOR then
		tier = 1
		if gear then
			local kind = Verdict(info.hyperlink)
			if kind == "upgrade" or kind == "later" then return nil end
		end
	elseif gear then
		if info.isBound then
			local kind = Verdict(info.hyperlink)
			if kind == "worse" or kind == "cant" then tier = 3 end
		end
	elseif quality == COMMON and not info.isBound then
		local kinds = PLAIN[class]
		if kinds == true or (kinds and kinds[sub]) then tier = 2 end
	end
	if not tier then return nil end
	if Kept(id, bag, slot) then return nil end
	return tier
end

-- Free slots in ordinary bags (bag family 0).
local function Count()
	local open = 0
	for bag = FIRST, LAST do
		local n, family = C_Container.GetContainerNumFreeSlots(bag)
		local fits = family == 0
		if plain[bag] ~= fits then
			plain[bag] = fits
			sized = false
		end
		if fits then open = open + (n or 0) end
	end
	return open
end

local function Sizes()
	local slots = 0
	for bag = FIRST, LAST do
		if plain[bag] then slots = slots + C_Container.GetContainerNumSlots(bag) end
	end
	sized = true
	return slots
end

local function Tell(nowFree, nowTotal)
	if nowFree == free and nowTotal == total then return end
	free, total = nowFree, nowTotal
	Shy:Fire("SHY_BAGS_ROOM", free, total)
end

local function Recount()
	local open = Count()
	local slots = sized and total or Sizes()
	counted = true
	Tell(open, slots)
end

-- Recounts if asked mid-burst, before BAG_UPDATE_DELAYED.
function Room.Free()
	if not counted then Recount() end
	return free, total
end

-- What can go is in this order: the tier, then the cheapest, then by bag and slot (a total order).
local function Before(a, b)
	if a.tier ~= b.tier then return a.tier < b.tier end
	if a.value ~= b.value then return a.value < b.value end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end

local sizes = {}           -- bag -> its slots at the last read
local laters = {}          -- key -> true: a filled slot whose price was not loaded yet
local dirty = {}           -- bag -> changed since the last read (BAG_UPDATE)

-- One slot as it stands: its price into `worth`, and its entry when it can go.
local function ReadSlot(bag, slot, worth)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not (info and info.itemID) then return nil end
	local key = Key(bag, slot)
	local value, later = Price(info)
	if later then
		laters[key] = true
		unread = unread + 1
	end
	worth[key] = value or false
	local tier, over
	if plain[bag] then tier, over = Tier(info, bag, slot, value) end
	if not tier then return nil end
	return { bag = bag, slot = slot, id = info.itemID, link = info.hyperlink, name = info.itemName,
		count = info.stackCount or 1, value = value or 0, junk = info.quality == POOR or over == true, tier = tier,
		quality = info.quality, icon = info.iconFileID, over = over }
end

local function Ranked(found)
	local where = {}
	for rank, entry in ipairs(found) do
		entry.rank = rank
		where[Key(entry.bag, entry.slot)] = entry
	end
	return where
end

-- Every slot read again.
local function Read()
	local found, worth = {}, {}
	local open = Count()
	local slots = 0
	wipe(laters)
	wipe(dirty)
	unread = 0
	-- Special bags are read for their prices only: nothing in them can go, and they are not room.
	for bag = FIRST, EVERY do
		local size = C_Container.GetContainerNumSlots(bag)
		sizes[bag] = size
		if plain[bag] then slots = slots + size end
		for slot = 1, size do
			local entry = ReadSlot(bag, slot, worth)
			if entry then found[#found + 1] = entry end
		end
	end
	table.sort(found, Before)
	list, at, seen, stale = found, Ranked(found), worth, false
	loose = {}
	sized, counted = true, true
	Tell(open, slots)
end

-- Only the bags that changed (a loot, a sale) read again: their old entries go and their new ones are
-- merged into the kept order. Anything else (a bag of another kind or size) reads every slot.
local function Partial()
	local open = Count()
	if not sized then return Read() end
	for bag in pairs(dirty) do
		if bag >= FIRST and bag <= EVERY and C_Container.GetContainerNumSlots(bag) ~= sizes[bag] then return Read() end
	end
	local add = {}
	for bag in pairs(dirty) do
		dirty[bag] = nil
		if bag >= FIRST and bag <= EVERY then
			for slot = 1, sizes[bag] or 0 do
				local key = Key(bag, slot)
				local was = at[key]
				if was then
					was.gone = true
					at[key] = nil
				end
				seen[key], loose[key] = nil, nil
				if laters[key] then
					laters[key] = nil
					unread = unread - 1
				end
				local entry = ReadSlot(bag, slot, seen)
				if entry then add[#add + 1] = entry end
			end
		end
	end
	table.sort(add, Before)
	local merged, i, j = {}, 1, 1
	while true do
		local a = list[i]
		while a and a.gone do
			i = i + 1
			a = list[i]
		end
		local b = add[j]
		if not a and not b then break end
		if b and (not a or Before(b, a)) then
			merged[#merged + 1] = b
			j = j + 1
		else
			merged[#merged + 1] = a
			i = i + 1
		end
	end
	list, at = merged, Ranked(merged)
	counted = true
	Tell(open, total)
end

function Room.List()
	if stale or not list then
		Read()
	elseif next(dirty) then
		Partial()
	end
	return list
end

-- The list can change without a bag event (a quest was handed in).
function Room.Forget()
	stale = true
end

-- Slots still needed, and how many to light.
local function Short()
	if not (state and state.need) then return 1 end
	return math.max(1, state.need - (Room.Free()))
end

local function Shown()
	return math.max(FEW, Short() + 2)
end

function Room.On() return state ~= nil end

function Room.Lit(bag, slot)
	Room.List()
	local key = Key(bag, slot)
	local entry = at[key]
	if state then return entry and entry.rank <= Shown() and entry or nil end
	if T.db.order == "worth" then
		if entry then return entry end
		-- Sorted by price, every stack with a price shows it.
		local value = seen[key]
		if not value then return nil end
		local other = loose[key]
		if not other then
			other = { bag = bag, slot = slot, value = value, rank = math.huge }
			loose[key] = other
		end
		return other
	end
	if entry and entry.rank == 1 and (Room.Free()) <= Room.LOW then return entry end
	return nil
end

-- 0 for a quest leftover, which no vendor buys but which can go.
function Room.Value(bag, slot)
	Room.List()
	local key = Key(bag, slot)
	local entry = at[key]
	if entry then return entry.value end
	return seen[key] or nil
end

function Room.Unread()
	Room.List()
	return unread
end

-- Making room

local function Visible()
	return ns.Takeover ~= nil and (ns.Takeover.Visible()) == true
end

-- What each lit slot's mark says (bag * 1000 + slot -> its words), so only the slots whose marks changed
-- are drawn again; `told` is what holds for every slot (making room or not, the order), nil to draw all.
local marked = {}

local function Marked()
	Room.List()
	local short = Short()
	local now = {}
	for _, entry in ipairs(list) do
		if Room.Lit(entry.bag, entry.slot) then
			now[Key(entry.bag, entry.slot)] = entry.value .. (entry.rank <= short and "!" or "")
		end
	end
	-- Sorted by price, every stack with a price shows it.
	if T.db.order == "worth" and not state then
		for key, value in pairs(seen) do
			if value and not now[key] then now[key] = value end
		end
	end
	return now
end

local function Follow()
	if not Visible() then
		told = nil
		return
	end
	local now = Marked()
	-- A layout made before every price was loaded is made again once they are.
	if ns.Order and unread == 0 then ns.Order.Priced() end
	local head = (state and "room" or "") .. "|" .. tostring(T.db.order)
	if head ~= told then
		told, marked = head, now
		ns.Marks.Refresh()
		return
	end
	local changed
	for key, says in pairs(now) do
		if marked[key] ~= says then
			changed = changed or {}
			changed[key] = true
		end
	end
	for key in pairs(marked) do
		if now[key] == nil then
			changed = changed or {}
			changed[key] = true
		end
	end
	marked = now
	if changed then ns.Marks.Refresh(changed) end
end

local function Soon()
	if due then return end
	due = true
	C_Timer.After(0.2, function()
		due = false
		Follow()
	end)
end

-- Chat fallback while the default bags are in use.
local function Say()
	local first = Room.List()[1]
	if first then
		T:Print("cheapest item you could drop or sell: " .. (first.link or first.name) .. " " .. Room.Coins(first.value))
	else
		T:Print("nothing is safe to drop or sell.")
	end
end

function Room.Start(opts)
	local Takeover, Window = ns.Takeover, ns.Window
	if not (Takeover and Window and Takeover.IsOn()) then
		Say()
		return false
	end
	state = { need = opts and opts.need or nil, why = opts and opts.why or nil }
	told = nil
	Takeover.Open()
	Window.Look(nil)
	Window.Open("room")
	Follow()
	return true
end

function Room.Stop()
	if not state then return end
	state = nil
	told = nil
	local Window = ns.Window
	if Window and Window.Wing and Window.Wing() == "room" then Window.Open(nil) end
	Follow()
end

function Room.Toggle()
	if state then Room.Stop() else Room.Start() end
end

-- Returns rows, the reason line, the how-to line, whether that line is urgent, and the lit count.
function Room.Told()
	local rows, lit = {}, 0
	local short = Short()
	for index, entry in ipairs(Room.List()) do
		entry.lit = Room.Lit(entry.bag, entry.slot) ~= nil
		entry.lead = entry.lit and entry.rank <= short
		if entry.lit then lit = lit + 1 end
		rows[index] = entry
	end
	local vendor = MerchantFrame ~= nil and MerchantFrame:IsShown()
	local why = state and state.why or "Cheapest items you could drop"
	local how = vendor and "Pick one to sell." or "Pick one to drop."
	return rows, why, how, vendor, lit
end

-- The price label across the top of a slot

local function MakeLabel(tile)
	local mark = { tile = tile }
	mark.band = tile:CreateTexture(nil, "OVERLAY", nil, 2)
	mark.band:SetHeight(11)
	UI.Paint(mark.band, C.bg, 0.88)
	mark.line = tile:CreateTexture(nil, "OVERLAY", nil, 3)
	mark.line:SetPoint("TOPLEFT", mark.band, "BOTTOMLEFT", 0, 0)
	mark.line:SetPoint("TOPRIGHT", mark.band, "BOTTOMRIGHT", 0, 0)
	mark.line:SetHeight(1)
	mark.text = tile:CreateFontString(nil, "OVERLAY")
	mark.text:SetDrawLayer("OVERLAY", 4)
	mark.text:SetFont(Shy.FONT_ROUNDED, 9, "")
	mark.text:SetPoint("CENTER", mark.band, "CENTER", 0, 0)
	mark.text:SetWordWrap(false)
	mark.text:SetTextColor(1, 1, 1)
	mark.parts = { mark.band, mark.line }   -- clipped to the slot's shape by Tile.lua
	return mark
end

local function ShowLabel(mark, entry)
	local on = entry ~= nil
	mark.band:SetShown(on)
	mark.line:SetShown(on)
	mark.text:SetShown(on)
	if not on then return end
	-- Inside the frame, and below the lip on shapes that have one, so the quality color stays visible.
	local top = Slot.Lipped() and 5 or 3
	if mark.top ~= top then
		mark.top = top
		mark.band:ClearAllPoints()
		mark.band:SetPoint("TOPLEFT", mark.tile, "TOPLEFT", 3, -top)
		mark.band:SetPoint("TOPRIGHT", mark.tile, "TOPRIGHT", -3, -top)
	end
	mark.text:SetText(Room.Coins(entry.value, true))
	UI.Paint(mark.line, entry.rank <= Short() and C.alert or Shy.Skin.colors.metal)
end

ns.Marks.Register({
	id = "worth", channel = "top", title = "Cheapest to drop",
	desc = "With your bags nearly full, the cheapest thing to drop shows its vendor price. Sorted by price, everything does.",
	test = function(item)
		if not item.live or state then return nil end
		return Room.Lit(item.bag, item.slot)
	end,
	make = MakeLabel,
	show = ShowLabel,
})

-- For other addons (documented in ShyBags.lua)

local function Copy(entry)
	return { bag = entry.bag, slot = entry.slot, id = entry.id, link = entry.link, name = entry.name,
		count = entry.count, value = entry.value, junk = entry.junk }
end

function T:Room()
	return Room.Free()
end

function T:Cheapest(n)
	local out = {}
	for index, entry in ipairs(Room.List()) do
		if n and index > n then break end
		out[index] = Copy(entry)
	end
	return out
end

-- Returns {} and does nothing when `need` slots are already free.
function T:MakeRoom(opts)
	if opts == false then
		Room.Stop()
		return {}
	end
	opts = type(opts) == "table" and opts or {}
	local need = math.max(1, math.floor(tonumber(opts.need) or 1))
	if (Room.Free()) >= need then return {} end
	Room.Start({ need = need, why = type(opts.why) == "string" and opts.why or nil })
	return self:Cheapest(Shown())
end

function T:Keep(test)
	keepers[#keepers + 1] = test
	stale = true
	Soon()
end

-- Events

-- For /shy bags check: the free-slot count against a manual count, and hasNoValue against the sell price.
function Room.Check()
	local byHand, special = 0, 0
	local priced, none, odd = 0, 0, 0
	for bag = FIRST, LAST do
		local _, family = C_Container.GetContainerNumFreeSlots(bag)
		if family ~= nil and family ~= 0 then special = special + 1 end
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if not info then
				if family == 0 then byHand = byHand + 1 end
			else
				local price = select(11, C_Item.GetItemInfo(info.hyperlink or info.itemID))
				if price == nil then
					odd = odd + 1
				elseif (price > 0) == (info.hasNoValue == true) then
					odd = odd + 1
				elseif price > 0 then
					priced = priced + 1
				else
					none = none + 1
				end
			end
		end
	end
	stale = true
	local open, slots = Count(), Sizes()
	local first = Room.List()[1]
	local note = open .. " free of " .. slots .. " (slot by slot " .. byHand .. "), " .. special .. " special bags; "
		.. priced .. " priced, " .. none .. " without a price, " .. odd .. " where price and \"no value\" disagree or no price was read; "
		.. #list .. " can go" .. (first and (", cheapest " .. tostring(first.name) .. " " .. first.value .. "c") or "")
	return open == byHand and odd == 0, note
end

function Room.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("BAG_UPDATE")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("BAG_CONTAINER_UPDATE")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	events:RegisterEvent("PLAYER_LEVEL_UP")
	events:RegisterEvent("MERCHANT_SHOW")
	events:RegisterEvent("MERCHANT_CLOSED")
	events:SetScript("OnEvent", function(_, event, bag)
		if event == "BAG_UPDATE" then
			-- That bag alone is read again when next asked (BAG_UPDATE_DELAYED does the rest).
			if type(bag) == "number" then dirty[bag] = true else stale = true end
			counted = false
		elseif event == "BAG_UPDATE_DELAYED" then
			Recount()
			if state and state.need and free >= state.need then
				Room.Stop()
			else
				Follow()
			end
		elseif event == "BAG_CONTAINER_UPDATE" then
			sized, stale = false, true
			Recount()
		elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
			-- The wing's how-to line differs at a vendor.
			if state and ns.Window and Visible() then ns.Window.Refresh() end
		elseif event ~= "GET_ITEM_INFO_RECEIVED" or unread > 0 then
			-- GET_ITEM_INFO_RECEIVED fires for any item, so it only counts while a price is missing.
			stale = true
			if Visible() then Soon() end
		end
	end)
	Shy:On("SHY_SLOT", function()
		told = nil
		Follow()
	end)
	Recount()
end

T:Command("room", "light the cheapest things you could drop or sell, or stop", function()
	Room.Toggle()
end)
