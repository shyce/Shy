-- What to sell at a vendor: everything in your bags you most likely want gone, each with why, ready for the vendor
-- window's sell page (ShySkin's) to show and sell in one press. Read from make room's list (Room.lua: junk, plain
-- materials, outgrown bound gear) and from unbound gear ShyGear calls no use to you, priced by the family's prices
-- (Shy.Price: the vendor's, and what the auction house pays less its cut):
--   junk       grey items and what is left of finished quests                                   checked
--   outgrown   bound gear ShyGear rates worse or that you can't use                              checked
--   plain      materials and unbound gear the auction house pays no more for than a vendor (or no price) checked
--   house      what the auction house pays more for than a vendor: listed to see, not sold unless ticked unchecked
--   misc       everything else in your bags a vendor buys, and what you kept                    unchecked
-- What you untick is kept and remembered: it isn't offered again for ten levels, then it is asked about again; kept
-- at the highest level, it is kept for good. Ticking it again lets it go. Kept, it waits under misc.
--   T:SaleList()            { groups = { { key, rows = { row } } }, count, value } (checked ones counted); a row:
--                           { id, name, quality, icon, link, count, value (the vendor's, all of it), house (the
--                           house's, all of it, less its cut, or nil), auctionable (the auction house takes it),
--                           best ("vendor" | "auction": where it fetches more), why, checked, kind,
--                           slots = { { bag, slot } } }
--   T:SaleCheck(id, on)     ticked or not (unticking what is checked by default keeps it)
--   T:Sell(rows)            sells those rows' stacks at the vendor, a few a second (the first at once): the count
--   T:Selling()             how a sale stands: nil, or { done, of }

local ADDON, ns = ...
local T = ns.T
local Store = ns.Store

local Sellout = {}
ns.Sellout = Sellout

T.defaults.keptFromSale = {}   -- [itemID] = the level it was kept at, or true: kept for good (at the highest level)

-- The family's prices (Shy.Price). None until the client restarts with the ShyCore that has them.
local Price = Shy.Price

local AGAIN = 10                 -- levels before something kept is asked about again
local PACE = 0.2                 -- seconds between two sales
local GROUPS = { "junk", "outgrown", "plain", "house", "misc" }
local CLASS = { Weapon = Enum.ItemClass.Weapon, Armor = Enum.ItemClass.Armor }
local BAGS = { Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag }   -- every bag you carry, the reagent bag too
local ORDINARY = Enum.BagIndex.Bag_4
local HEARTHSTONE = 6948

local ticked = {}                -- this visit: [id] = true / false as ticked by hand
local sale                       -- { queue, at, done, of, value } while selling

local function Level() return UnitLevel("player") or 1 end
local function Top() return GetMaxLevelForPlayerExpansion() end

-- Kept and not yet due to be asked about again.
local function Kept(id)
	local at = T.db.keptFromSale[id]
	if at == true then return true end
	return type(at) == "number" and Level() < at + AGAIN
end

local function Vendor(id) return Price and Price.Vendor(id) or nil end
local function House(id, count) return Price and Price.Fetch(id, count) or nil end

-- ShyGear's word on gear: its verdict's kind ("worse", "cant", "upgrade", ...), or nil.
local function Verdict(link)
	local gear = Shy.addons.Gear
	if not (gear and gear.Judge and link) then return nil end
	local ok, verdict = pcall(gear.Judge, gear, link)
	return ok and type(verdict) == "table" and verdict.kind or nil
end

-- A row for an item, or its stack added to the row it has.
local function Add(rows, info, bag, slot, sell, more)
	local id = info.itemID
	local r = rows[id]
	if not r then
		r = { id = id, name = info.itemName, quality = info.quality, icon = info.iconFileID, link = info.hyperlink,
			count = 0, value = 0, slots = {} }
		for key, value in pairs(more) do r[key] = value end
		rows[id] = r
	end
	r.count = r.count + (info.stackCount or 1)
	r.value = r.value + sell * (info.stackCount or 1)
	r.slots[#r.slots + 1] = { bag = bag, slot = slot }
	return r
end

-- Unbound gear ShyGear calls no use to you, anywhere in your ordinary bags: [id] = row.
local function LooseGear(rows)
	for bag = BAGS[1], ORDINARY do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			if id and not issecretvalue(id) and not info.isBound and not info.hasNoValue and (info.quality or 0) >= Enum.ItemQuality.Common then
				local _, _, _, equip, _, class = C_Item.GetItemInfoInstant(id)
				local sell = Vendor(id)
				if (class == CLASS.Weapon or class == CLASS.Armor) and equip and equip ~= "" and sell and sell > 0 then
					local kind = Verdict(info.hyperlink)
					if kind == "worse" or kind == "cant" then Add(rows, info, bag, slot, sell, { gear = kind, auctionable = true }) end
				end
			end
		end
	end
end

-- Everything else a vendor buys, in every bag you carry: [id] = row, under misc. Never quest items.
local function Rest(rows, taken)
	for bag = BAGS[1], BAGS[2] do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			if id and not issecretvalue(id) and not taken[id] and not info.hasNoValue and id ~= HEARTHSTONE then
				local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
				local sell = Vendor(id)
				if sell and sell > 0 and not (quest and (quest.isQuestItem or quest.questID)) then
					local r = Add(rows, info, bag, slot, sell, { kind = "misc", auctionable = (info.quality or 0) > 0 and not info.isBound })
					r.why = r.why or select(6, C_Item.GetItemInfo(id)) or ""
				end
			end
		end
	end
end

function Sellout.List()
	local rows = {}
	-- Make room's list: junk (1), plain materials (2), outgrown bound gear (3); a row an item.
	for _, e in ipairs(ns.Room and ns.Room.List() or {}) do
		local r = rows[e.id]
		if not r then
			r = { id = e.id, name = e.name, quality = e.quality, icon = e.icon, link = e.link, count = 0, value = 0, slots = {},
				tier = e.tier, over = e.over, auctionable = e.tier == 2 }
			rows[e.id] = r
		end
		r.count = r.count + (e.count or 1)
		r.value = r.value + (e.value or 0)
		r.slots[#r.slots + 1] = { bag = e.bag, slot = e.slot }
	end
	LooseGear(rows)
	for id, r in pairs(rows) do
		if Kept(id) then
			r.kind, r.why = "misc", "you're keeping it"
		elseif r.tier == 1 then
			r.kind, r.why = "junk", r.over and "left from a finished quest" or "junk"
		elseif r.tier == 3 then
			local kind = Verdict(r.link)
			r.kind, r.why = "outgrown", kind == "cant" and "you can't use it" or "worse than what you wear"
		else
			r.house = House(id, r.count)
			if Price and Price.Better(r.value, r.house) == "auction" then
				r.kind, r.why = "house", "worth listing"
			elseif r.gear and not r.house then
				-- Unbound gear with no price yet: worth a look at the auction house before a vendor has it.
				r.kind, r.why = "house", "no auction price yet"
			else
				r.kind = "plain"
				r.why = r.house and "the auction pays no more"
					or (r.gear == "cant" and "you can't use it" or r.gear and "worse than what you wear" or "no market for it")
			end
		end
	end
	local taken = {}
	for id in pairs(rows) do taken[id] = true end
	Rest(rows, taken)
	local groups = { junk = {}, outgrown = {}, plain = {}, house = {}, misc = {} }
	local count, value = 0, 0
	for id, r in pairs(rows) do
		if r.auctionable and r.house == nil then r.house = House(id, r.count) end
		r.best = (r.auctionable and Price) and Price.Better(r.value, r.house) or "vendor"
		local default = r.kind ~= "house" and r.kind ~= "misc"
		if ticked[id] ~= nil then r.checked = ticked[id] else r.checked = default end
		table.insert(groups[r.kind], r)
		if r.checked then count, value = count + 1, value + r.value end
	end
	local out = { groups = {}, count = count, value = value }
	for _, key in ipairs(GROUPS) do
		local list = groups[key]
		table.sort(list, function(a, b)
			if a.value ~= b.value then return a.value > b.value end
			return a.id < b.id
		end)
		if #list > 0 then out.groups[#out.groups + 1] = { key = key, rows = list } end
	end
	return out
end

-- Ticked or not. Unticking what a vendor would have by default keeps it, remembered: for ten levels, for good at the
-- highest level. Ticking it again lets it go. Ticking what isn't ticked by default remembers nothing.
function Sellout.Check(id, on, kind)
	ticked[id] = on and true or false
	if kind == "house" or kind == "misc" then return end
	if on then
		T.db.keptFromSale[id] = nil
	else
		T.db.keptFromSale[id] = Level() >= Top() and true or Level()
	end
end

-- A visit ended: what was ticked by hand is forgotten (what was kept stays kept).
function Sellout.Forget()
	wipe(ticked)
end

local function Next()
	if not sale then return end
	local item = table.remove(sale.queue, 1)
	if not item or not MerchantFrame:IsShown() then
		if sale.value > 0 then Shy:Fire("SHY_BAGS_SOLD", sale.value) end
		sale = nil
		Shy:Fire("SHY_BAGS_SALE", "done")
		return
	end
	local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
	if info and info.itemID == item.id and not info.isLocked then
		C_Container.UseContainerItem(item.bag, item.slot)
		sale.value = sale.value + (item.each or 0) * (info.stackCount or 1)
	end
	sale.done = sale.done + 1
	Shy:Fire("SHY_BAGS_SALE", "progress", sale.done, sale.of)
	C_Timer.After(PACE, Next)
end

function Sellout.Sell(rows)
	if sale or not MerchantFrame:IsShown() then return 0 end
	local queue = {}
	for _, r in ipairs(rows) do
		local each = r.count > 0 and r.value / r.count or 0
		for _, s in ipairs(r.slots) do queue[#queue + 1] = { bag = s.bag, slot = s.slot, id = r.id, each = each } end
	end
	if #queue == 0 then return 0 end
	sale = { queue = queue, done = 0, of = #queue, value = 0 }
	local of = #queue
	Next()   -- the first at once, from the press
	return of
end

function Sellout.Selling()
	return sale and { done = sale.done, of = sale.of } or nil
end

function T:SaleList() return Sellout.List() end
function T:SaleCheck(id, on, kind) Sellout.Check(id, on, kind) end
function T:Sell(rows) return Sellout.Sell(rows) end
function T:Selling() return Sellout.Selling() end

function Sellout.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("MERCHANT_CLOSED")
	events:SetScript("OnEvent", function()
		Sellout.Forget()
		if sale then sale.queue = {} end
	end)
end
