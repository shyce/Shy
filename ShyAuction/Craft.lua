-- What a recipe is worth to make, at this auction house's prices. What it makes is worth its market, or, where the auction house can't
-- sell it (bound when picked up, or never listed), what a vendor pays. Each reagent costs the cheaper of a vendor's price
-- (Data/Vendor.lua: what vendors sell, by the stack they sell it in) and its market. Sold at the auction house, the auction house keeps
-- its cut (5% at a faction's, 15% at a goblin's), so the profit is what you get less the reagents; the deposit comes
-- back when it sells, so it isn't counted. The profit counts every reagent at
-- its price, the ones you hold too (making it spends what you could sell); what you lack is apart: what it costs to buy
-- and whether your gold covers it. A recipe you don't know yet carries its own price and how many crafts pay it back.
-- Nothing is guessed: anything without a price leaves the profit unknown and says so.
--
--   Craft.Unit(item)        copper one costs you to get, and from where: "vendor" | "auction" | nil, "none"
--   Craft.Worth(item)       copper one fetches, and how: "auction" | "vendor" | nil
--   Craft.Plan(r)           r = { item, count (what one craft makes, a range's middle), reagents = { { item, need } },
--                           have = function(item) -> count, gold, recipe (the item that teaches it) } ->
--                           { value, worth, cut (the auction house's share of value), rate, cost, profit, unpriced, buy, afford,
--                           reagents = { { item, need, have, short,
--                           unit, from, buy } }, learn = { cost, from, crafts } }
--   Craft.Rank(plans)       the best profit first, a loss after the profits, the unpriced last

local ADDON, ns = ...

local Craft = {}
ns.Craft = Craft

local BIND_ON_PICKUP = 1

local function Vendor(item)
	local text = ns.vendor and ns.vendor[item]
	if not text then return nil end
	local buy, stack = text:match("^(%d+)%^?(%d*)")
	buy, stack = tonumber(buy), tonumber(stack) or 1
	if not buy or buy <= 0 then return nil end
	return buy / math.max(1, stack)
end

local function Market(item)
	local price = ns.Book.Price(item)
	return price and price.market or nil
end

function Craft.Unit(item)
	local vendor, market = Vendor(item), Market(item)
	if vendor and (not market or vendor <= market) then return vendor, "vendor" end
	if market then return market, "auction" end
	return nil, "none"
end

function Craft.Worth(item)
	local _, _, _, _, _, _, _, _, _, _, sell, _, _, bind = C_Item.GetItemInfo(item)
	local market = Market(item)
	if market and bind ~= BIND_ON_PICKUP then return market, "auction" end
	if sell and sell > 0 then return sell, "vendor" end
	return nil
end

function Craft.Plan(r)
	local plan = { reagents = {}, cost = 0, buy = 0, unpriced = false }
	local each, worth = Craft.Worth(r.item)
	plan.worth = worth
	plan.value = each and math.floor(each * (r.count or 1) + 0.5) or nil
	if not each then plan.unpriced = true end
	if plan.value and worth == "auction" then
		plan.rate = ns.Book.Cut()
		plan.cut = math.floor(plan.value * plan.rate + 0.5)
	end
	for _, reagent in ipairs(r.reagents or {}) do
		local unit, from = Craft.Unit(reagent.item)
		local have = r.have and r.have(reagent.item) or 0
		local short = math.max(0, reagent.need - have)
		local row = { item = reagent.item, need = reagent.need, have = have, short = short, unit = unit, from = from,
			buy = unit and math.floor(short * unit + 0.5) or nil }
		plan.reagents[#plan.reagents + 1] = row
		if unit then
			plan.cost = plan.cost + math.floor(reagent.need * unit + 0.5)
			plan.buy = plan.buy + row.buy
		else
			plan.unpriced = true
		end
	end
	if not plan.unpriced then plan.profit = plan.value - (plan.cut or 0) - plan.cost end
	plan.afford = r.gold == nil or r.gold >= plan.buy
	if r.recipe then
		local cost, from = Craft.Unit(r.recipe)
		plan.learn = { cost = cost, from = from }
		if cost and plan.profit and plan.profit > 0 then plan.learn.crafts = math.ceil(cost / plan.profit) end
	end
	return plan
end

function Craft.Rank(plans)
	local out = {}
	for i, plan in ipairs(plans) do out[i] = plan end
	table.sort(out, function(a, b)
		if (a.profit == nil) ~= (b.profit == nil) then return a.profit ~= nil end
		if a.profit and b.profit and a.profit ~= b.profit then return a.profit > b.profit end
		return false
	end)
	return out
end
