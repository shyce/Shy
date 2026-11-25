-- What fills each crate, and what you hold. One stamp for both goes up when your bags, a price or a pick change. Every
-- answer is kept until it moves.
--   Plan.Of(crate)     its bundles for every crate of it you hold (at least one), the one to use first leading: each
--                      { item, need (one crate's), have (in your bags), bought (at the auction house, this visit),
--                      mailed, banked (what ShyBags last read there: told, never counted), fills (crates it fills
--                      now), short (what all of them lack: your bags and this visit's buying counted),
--                      unit (copper each, or nil), cost (one crate's), finish (short x unit; 0 with nothing short),
--                      ready (fills one now) }. One list per crate, filled again when the stamp moves: read it, don't
--                      keep it. nil for anything but a labelled crate
--   Plan.Pick(crate)   the bundle it fills with: the one picked, else the first. Plan.SetPick(crate, item) picks one
--   Plan.Shopping()    what to get to fill every crate you hold, each with its pick, a thing taken by two labels
--                      counted once, in the crates' order: { { item, count (still to buy), bought (this visit), done,
--                      unit, cost }... }, what is left costs in all (nil while something has no price), how many left
--   Plan.Held()        the crates in your bags: { unread = { item, bag, slot, count } or nil, labels = { { crate, bag,
--                      slot, count }, ... } by level then item, counts = { [crate] = n } }. One pass over the bags
--   Plan.Stack(item)   bag, slot of your biggest stack of a bundle's item, or nil
--   Plan.Bought(item)  how many of it you bought at the auction house this visit
--   Plan.Mailed(item), Plan.Banked(item)   how many ShyBags last read in your mailbox, your bank (0 without it)
--   Plan.Ready()       how many crates you can fill now, every label with its pick
--   Plan.Is(item)      "label" | "unread" | nil
--   Plan.Stamp()       goes up with every change

local ADDON, ns = ...

local Plan = {}
ns.Plan = Plan

local stamp = 0
local plans = {}   -- crate -> { at = stamp, list = { bundle... } }
local made = 0
local held = { at = -1, labels = {}, unread = nil, stacks = {}, counts = {} }
local picks = {}   -- crate -> the item of the bundle you picked, for the session
local shopping = { at = -1, list = {} }
local wanted = {}  -- the items any bundle takes -> true

for _, def in pairs(ns.crates) do
	for i = 2, #def, 2 do wanted[def[i]] = true end
end

-- Bought at the auction house: it comes by mail, so while you stand there it is counted as yours and not bought again.
-- Gone as you leave: from then on only your bags count, the mail and the bank told beside them (ShyBags' readings).
local bought = {}   -- item -> how many, this visit

function Plan.Bought(item) return bought[item] or 0 end

-- What ShyBags knows of your mailbox and bank (its own tables, read only), when it is on.
local function Bags(what)
	local bags = Shy.addons.Bags
	local fn = bags and bags[what]
	return fn and fn(bags) or nil
end

function Plan.Mailed(item)
	local mailed = Bags("Mailed")
	return mailed and mailed[item] or 0
end

function Plan.Banked(item)
	local banked = Bags("Banked")
	return banked and banked[item] or 0
end

function Plan.Stamp() return stamp end

function Plan.Is(item)
	if ns.crates[item] then return "label" end
	if ns.unread[item] then return "unread" end
end

-- What one costs you: a vendor's price or the auction house's, the cheaper.
local function Unit(item)
	local auction = Shy.addons.Auction
	if not (auction and auction.CraftUnit) then return nil end
	return (auction:CraftUnit(item))
end

-- Cheapest to fill them all first; what you hold costs nothing more, so it leads at a price alike.
local function Before(a, b)
	local x, y = a.finish, b.finish
	if (x == nil) ~= (y == nil) then return x ~= nil end
	if x ~= nil and x ~= y then return x < y end
	if (a.cost == nil) ~= (b.cost == nil) then return a.cost ~= nil end
	if a.cost and a.cost ~= b.cost then return a.cost < b.cost end
	if a.fills ~= b.fills then return a.fills > b.fills end
	return a.item < b.item
end

function Plan.Of(crate)
	local def = ns.crates[crate]
	if not def then return nil end
	local plan = plans[crate]
	if plan and plan.at == stamp then return plan.list end
	if not plan then
		plan = { list = {} }
		plans[crate] = plan
		made = made + 1
	end
	plan.at = stamp
	local count = math.max(1, Plan.Held().counts[crate] or 0)
	local list = plan.list
	for i = 2, #def, 2 do
		local b = list[i / 2]
		if not b then
			b = {}
			list[i / 2] = b
		end
		local item, need = def[i], def[i + 1]
		local have = C_Item.GetItemCount(item) or 0
		local unit = Unit(item)
		b.item, b.need, b.have, b.unit = item, need, have, unit
		b.bought, b.mailed, b.banked = Plan.Bought(item), Plan.Mailed(item), Plan.Banked(item)
		b.fills = math.min(count, math.floor(have / need))
		b.short = math.max(0, need * count - have - b.bought)
		b.ready = b.fills > 0
		b.cost = unit and unit * need or nil
		b.finish = b.short == 0 and 0 or unit and unit * b.short or nil
	end
	table.sort(list, Before)
	return list
end

function Plan.Pick(crate)
	local bundles = Plan.Of(crate)
	if not bundles then return nil end
	local item = picks[crate]
	for _, b in ipairs(bundles) do
		if b.item == item then return b end
	end
	return bundles[1]
end

function Plan.Shopping()
	if shopping.at == stamp then return shopping.list, shopping.total, shopping.left end
	shopping.at = stamp
	local list = shopping.list
	wipe(list)
	-- In one order that holds as you buy: the crates' own, first to last, each thing where it is first wanted.
	local want, order = {}, {}
	for _, at in ipairs(Plan.Held().labels) do
		local pick = Plan.Pick(at.crate)
		if not want[pick.item] then order[#order + 1] = pick.item end
		want[pick.item] = (want[pick.item] or 0) + pick.need * at.count
	end
	local total, left = 0, 0
	for _, item in ipairs(order) do
		local bought = Plan.Bought(item)
		local short = want[item] - (C_Item.GetItemCount(item) or 0) - bought
		if short > 0 or bought > 0 then
			local unit = Unit(item)
			local count = math.max(0, short)
			list[#list + 1] = { item = item, count = count, bought = bought, done = count == 0, unit = unit,
				cost = unit and unit * count or nil }
			if count > 0 then
				left = left + 1
				total = total and unit and total + unit * count or nil
			end
		end
	end
	shopping.total, shopping.left = total, left
	return list, total, left
end

local ready = { at = -1, n = 0 }
function Plan.Ready()
	if ready.at == stamp then return ready.n end
	local n = 0
	for _, at in ipairs(Plan.Held().labels) do n = n + Plan.Pick(at.crate).fills end
	ready.at, ready.n = stamp, n
	return n
end

local function ByLevel(a, b)
	local x, y = ns.crates[a.crate][1], ns.crates[b.crate][1]
	if x ~= y then return x < y end
	return a.crate < b.crate
end

function Plan.Held()
	if held.at == stamp then return held end
	wipe(held.labels)
	wipe(held.stacks)
	wipe(held.counts)
	held.unread = nil
	local seen, biggest = {}, {}
	-- (Every bag you carry, the reagent bag too: the game counts what is in it as yours.)
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local item = info and info.itemID
			if item and not issecretvalue(item) then
				local count = info.stackCount or 1
				if ns.crates[item] then
					local at = seen[item]
					if at then
						at.count = at.count + count
					else
						at = { crate = item, bag = bag, slot = slot, count = count }
						seen[item] = at
						held.labels[#held.labels + 1] = at
					end
					held.counts[item] = at.count
				elseif ns.unread[item] then
					local at = held.unread
					if at then at.count = at.count + count
					else held.unread = { item = item, bag = bag, slot = slot, count = count } end
				elseif wanted[item] and not info.isLocked and count > (biggest[item] or 0) then
					biggest[item] = count
					held.stacks[item] = { bag, slot }
				end
			end
		end
	end
	table.sort(held.labels, ByLevel)
	held.at = stamp   -- (only once whole: a pass cut short is made again next time)
	return held
end

function Plan.Stack(item)
	local at = Plan.Held().stacks[item]
	if at then return at[1], at[2] end
end

-- Bags and prices change many times a frame (a whole scan, a stack split): told once, next frame.
local Changed = Shy.Shop.Later(function()
	stamp = stamp + 1
	Shy:Fire("SHY_CRATES")
end)
Plan.Changed = Changed

function Plan.SetPick(crate, item)
	if picks[crate] == item then return end
	picks[crate] = item
	Changed()
end

function Plan.Start()
	local events = CreateFrame("Frame")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:SetScript("OnEvent", Shy.Clocked("crates: bags", function(_, event, item)
		-- (An item's name came: only ours are worth drawing again for.)
		if event == "GET_ITEM_INFO_RECEIVED" and not (wanted[item] or Plan.Is(item)) then return end
		Changed()
	end))
	-- What ShyBags read of your mailbox or bank changed.
	Shy:On("SHY_BAGS_SCANNED", function(_, source)
		if source == "mail" or source == "bank" or source == "sent" then Changed() end
	end)
	Shy:On("SHY_AUCTION", function(why, item, count)
		if why == "bought" and wanted[item] then bought[item] = (bought[item] or 0) + count end
		if why == "closed" then wipe(bought) end
		if why == "bought" or why == "scan" or why == "price" or why == "shown" or why == "closed" or why == "quote" or why == "failed" then
			Changed()
		end
	end)
	if Shy.Memory then
		Shy.Memory.Cache("crates: bundles", function()
			wipe(plans)
			made = 0
			held.at, shopping.at = -1, -1
		end, function() return made end)
	end
end
