-- The vendor: a counter. A window of our own in place of the game's (MerchantFrame), built for what a vendor is for:
-- in and out fast, nothing missed, no surprises. It is a desk (Shop.Desk): the game's window stays the panel the game
-- opens and closes, emptied and taking no mouse; ours is its child, in the make of the quest giver's window, so a
-- talk that leads to the goods turns into them where it stands; it flows to any size.
--
-- The band, the visit's chores: the vendor's face with a coin at its corner, who they are, then Repair all and Sell
-- junk as buttons with what each costs or makes, one press each, and pills of what was done and what to know (what
-- mending cost, what the junk made, how worn your gear is, bags nearly full).
-- A strip under it: All, For you (what a quest or your supplies ask for, gear ShyGear calls an upgrade, a recipe you
-- can learn and don't know) and Buyback, each with its count, and a search.
-- The sheet, on the window's own plain color:
--   to buy: the quest items this vendor sells that you still need (Shy.addons.Quest:Wanted(itemID)), then food,
--   water, potions or reagents to restock (Shy.addons.Quest:Supplies(itemIDs)), a card each with a button that buys
--   what is missing, and one button for them all; each stays for the visit, bought or not, so nothing moves under
--   the mouse.
--   for sale: every good, its picture (a stack's count on it, ShyGear's mark on an upgrade), its name in its
--   quality's color, its price under it, how many are left and how many you carry, and a word where it matters
--   (quest, restock, upgrade, can learn, known), in as few columns as hold them.
-- The foot, the purchase: your gold in its middle, and for the good you clicked a count at its left end (to step
-- or type, Max on the same plate) and Buy with the sum at its right end, so the count holds its place under the
-- mouse whatever Buy says; a hover beside the window says what is being bought, how many, and what it leaves you.
-- A right click still buys one at once; Shift is the game's own (a link, its split box); a drag picks it up.
--
-- At the band's top right, with ShyBags: Sell, with how many things and what they come to. It turns the sheet into
-- what to sell (ShyBags' sale list, weighed by vendor and auction house prices and by ShyGear): junk, outgrown gear,
-- what isn't worth listing, all ticked; what the auction house pays more for and Misc (everything else a vendor buys),
-- not ticked. Each is under the family's group heads, a row each with why, the vendor's price and the auction
-- house's, the better one lit. Untick what you keep (ShyBags remembers it for ten levels, for good
-- at the highest); the foot's Sell sells the ticked, a few a second; Back to the goods turns the sheet back.
-- ShyBags reports its own selling and repairing as SHY_BAGS_SOLD / SHY_BAGS_REPAIRED; anything else is noticed as junk
-- or a repair cost that was there and is gone.
-- Blizzard's window stays on its first tab: its second blocks right-click selling (ContainerFrameItemButton_OnClick),
-- and switching tabs from here would write on its frame.
-- Buying one is Blizzard's MerchantItemButton_OnClick / _OnModifiedClick, handed a row of ours with the fields its
-- item buttons carry (ID, price, extendedCost, name, link, texture, count, showNonrefundablePrompt, SplitStack), so
-- every click and confirmation behaves as default; a count is BuyMerchantItem a purchase at a time, or Blizzard's
-- own confirmation where the game asks first. Something of yours let go of anywhere on the window is sold, through
-- Blizzard's own handlers.
-- A currency's vendor (Merchant's Favor's) sorts beside the strip: Best (for you: ShyGear's upgrades,
-- the most first, then what you can wear later, soonest first, then the rest, what you can't use last), Price or
-- Level (what you can wear now, highest first, then what you grow into); a good's word is what ShyGear found ("+4% damage", "at level 34", "can't use"). A vendor that takes a
-- currency shows what you have of it in the foot, beside your gold.
-- Not included: single-item repair, guild repair, the spec filter.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local Slot = Shy.Slot
local C = UI.colors
local Shop = ns.Shop
local Talk = Shy.Talk
local WIN = Talk and Talk.WIN

local L = {
	strip = 24, stripTop = 8, stripFoot = 6,   -- the filter's strip under the band: its height, the room over and under it
	stripGap = 6,                          -- between its two lines, where it takes two
	search = 150, searchLeast = 96,        -- the search box, and the least it is worth showing at
	top = 2,                               -- from the strip to the sheet's first line
	cap = 18,                              -- a caption's line
	card = 46, cardGap = 4, cardSlot = Slot.SIZES.medium, cardPad = 10,   -- an order: its height, the gap, its slot and inset
	after = 8,                             -- from the last order to the list's caption
	row = 38, rowGap = 2, rowSlot = Slot.SIZES.medium, rowPad = 6,        -- a good: its height, the gap, its slot and inset
	rowLeft = 6 + Slot.SIZES.medium + 9, rowEnd = 8,                      -- ... where its words start, and how far in they end
	col = 196, colGap = 10, cols = 3,      -- a column's least width, between two, the most of them
	bar = 6,                               -- the scroll bar's room, at the sheet's right: the goods keep as far from
	                                       -- the window's one side as from its other
	under = 12,                            -- under the last row
	pills = -44,                           -- the band's second line, under who the vendor is
	count = 128, key = 22,                 -- the foot's count (its steps, the number and Max on one plate), and its height
	apart = 12,                            -- between your gold and what stands at either end of the foot
	buyPad = 34,                           -- Buy's room round its words
	silver = 100,                          -- the copper in a silver
	buys = 10,                             -- the most purchases one press of Buy makes
	tight = 4,                             -- this few bag slots free is worth saying
	orders = 4,                            -- orders shown at once
	lag = 0.6,                             -- seconds for ShyQuest to read a changed quest log (it polls at 4 Hz)
	asked = 3,                             -- seconds a sell or repair click stands as done before the game says so
}
local DOT = " \194\183 "
local ALL, FOR_YOU, BACK = 1, 2, 3   -- the strip's choices
local BEST, CHEAP, LEVEL = 1, 2, 3   -- a gear vendor's sorts

local WORDS = {
	title = "Vendor", modes = { "All", "For you", "Buyback" }, search = "Search", sorts = { "Best", "Price", "Level" },
	cant = "can't use", worse = "no better", same = "about the same", atLevel = "at level %d", needs = "needs level %d",
	skill = "needs %d skill", trade = "another trade", cantWear = "can't wear it",
	buy = "TO BUY", sale = "FOR SALE", forYou = "FOR YOU", sold = "BUY BACK",
	none = "Nothing for sale", noBack = "Nothing to buy back", noneForYou = "Nothing here stands out for you",
	noFind = "Nothing by that name",
	hint = "Click to choose how many", hintOne = "Right-click buys one", hintBack = "Click to buy it back",
	gear = "Gear %d%%", worn = "Gear worn", repairs = "Repairs", repaired = "Repaired", guild = "Repaired by the guild",
	soldJunk = "Sold junk", full = "Bags full", room = "Bags: %d free",
	all = "Buy all", repair = "Repair all", sell = "Sell junk", short = "Not enough gold", max = "Max",
	asksAll = "The game asks before buying these, so use each one's own button.",
	asksSome = "The game asks before buying some of these, so use their own buttons.",
	buyN = "Buy %d", buyIt = "Buy", buying = "Buying", times = "%d \195\151 %s", leaves = "Leaves you", done = "Bought", of = "%d of %d", out = "sold out", left = "%d left", have = "you have %d",
	quest = "quest", restock = "restock", upgrade = "upgrade", learn = "can learn", known = "known",
	forQuest = "For %s", aQuest = "a quest", stockUp = "Stock up", missing = "Buy what's missing",
	stacks = "Sold in stacks of %d.", afford = "You can afford %d of the %d you need.",
	onePurchase = "One purchase buys %d of the %d you need.", noneLeft = "The vendor has none left.",
	gone = "The vendor has none left",
	sellKey = "Sell", goodsKey = "Back to the goods", sellIt = "Sell", selling = "Selling %d of %d",
	sellNone = "Nothing in your bags a vendor should have.",
	sellGroups = { junk = "Junk", outgrown = "Outgrown gear", plain = "Not worth listing", house = "Better at the auction house", misc = "Misc" },
	sellSays = { junk = "Grey items and leftovers from finished quests.", outgrown = "Bound gear worse than what you wear, or that you can't use.",
		plain = "The auction house pays no more for these than a vendor.", house = "The auction house pays more. Tick one to sell it here anyway.",
		misc = "Everything else in your bags. Nothing here is ticked until you tick it." },
	vendorPays = "Vendor", housePays = "Auction", noPrice = "not known",
	sellTip = "Untick what you want to keep. You won't be asked about it again for ten levels.",
}
local SELL = "sell"   -- the sheet as what to sell

local M              -- the module
local desk           -- our window (Shop.Desk)
local own = { cards = {}, rows = {}, sellHeads = {}, sellRows = {} }   -- our frames, made once
local visit = {}     -- this visit: mode, pick, count, find, orders, known, sold, repaired, selling, repairing, role, waiting
local goods = {}     -- the vendor's items, as last read
local Refresh, Stale, Draw

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

-- Reading the vendor

-- A recipe you already know: the game says so on its tooltip. Asked once a visit for each (the answer is kept
-- once the tooltip has its lines).
local function Known(g)
	local known = visit.known or {}
	visit.known = known
	if known[g.index] ~= nil then return known[g.index] end
	local data = C_TooltipInfo.GetMerchantItem(g.index)
	local lines = type(data) == "table" and not issecretvalue(data) and data.lines
	if type(lines) ~= "table" or #lines < 2 then return false end
	local found = false
	for _, line in ipairs(lines) do
		local text = line.leftText
		if not issecretvalue(text) and text == ITEM_SPELL_KNOWN then found = true end
	end
	known[g.index] = found
	return found
end

-- What a good is to you: how many you carry, whether ShyGear calls it an upgrade ("upgrade", or "later" for one a
-- level or two off), and for a recipe whether you know it or could learn it.
local function Insight(g)
	g.have = g.id and C_Item.GetItemCount(g.id) or 0
	local gear = Shy.addons.Gear
	g.wearable = g.link ~= nil and C_Item.IsEquippableItem(g.link) or nil
	if g.wearable and gear and gear.Judge and gear.MarkFor then
		local ok, verdict = pcall(gear.Judge, gear, g.link)
		g.verdict = ok and verdict or nil
		g.gear = g.verdict and gear:MarkFor(g.verdict) or nil
	end
	g.level = g.link and select(5, C_Item.GetItemInfo(g.link)) or nil
	if g.id and select(6, C_Item.GetItemInfoInstant(g.id)) == Enum.ItemClass.Recipe then
		g.known = Known(g)
		g.learn = not g.known and g.info.isUsable == true
		-- A recipe is worth what it makes: that item judged as gear (and its level), your skill against its rank.
		local teach = ns.recipeTeaches and ns.recipeTeaches[g.id]
		if teach then
			g.recipe = true
			local skill = C_SkillInfo.GetSkillLineInfoByID(teach[2])
			g.skill, g.skillAt = skill and skill.rank or 0, teach[3]
			local makes = teach[1] > 0 and ("item:" .. teach[1]) or nil
			if makes and C_Item.IsEquippableItem(makes) then
				g.level = select(5, C_Item.GetItemInfo(makes)) or nil
				if gear and gear.Judge and gear.MarkFor and not g.known then
					local ok, verdict = pcall(gear.Judge, gear, makes)
					g.verdict = ok and verdict or nil
					g.gear = g.verdict and gear:MarkFor(g.verdict) or nil
				end
			end
		end
	end
end

-- The currencies this vendor takes (Merchant's Favor), in the order its goods first ask them: { id, icon, have }; and
-- what a good costs in the first one it asks (g.spend), to sort by.
local function Costs(g)
	if not g.info.hasExtendedCost then return end
	for i = 1, GetMerchantItemCostInfo(g.index) or 0 do
		local texture, value, link = GetMerchantItemCostItem(g.index, i)
		local id = type(link) == "string" and not issecretvalue(link) and tonumber(link:match("currency:(%d+)"))
		if id and value then
			g.spend = g.spend or value
			local wallet = visit.wallet
			if not wallet.has[id] then
				local about = C_CurrencyInfo.GetCurrencyInfo(id)
				wallet.has[id] = true
				wallet[#wallet + 1] = { id = id, icon = texture or (about and about.iconFileID), have = about and about.quantity or 0 }
			end
		end
	end
end

local function ReadGoods()
	wipe(goods)
	visit.wallet = { has = {} }
	visit.waiting = nil
	for index = 1, GetMerchantNumItems() do
		local info = C_MerchantFrame.GetItemInfo(index)
		if info then
			if info.currencyID then
				info.name, info.texture, info.numAvailable = CurrencyContainerUtil.GetCurrencyContainerInfo(info.currencyID, info.numAvailable, info.name, info.texture, nil)
			end
			local g = { index = index, info = info, id = GetMerchantItemID(index), link = GetMerchantItemLink(index) }
			Insight(g)
			Costs(g)
			goods[#goods + 1] = g
		end
	end
end

-- An item's quality and its color, or nil while the item isn't cached.
local function Quality(link)
	if not link then return nil end
	local quality = select(3, C_Item.GetItemInfo(link))
	if not quality then
		visit.waiting = true   -- until GET_ITEM_INFO_RECEIVED
		return nil
	end
	local color = ColorManager.GetColorDataForItemQuality(quality)
	if color then return quality, color.r, color.g, color.b end
	return quality
end

-- An item's name in its quality's color, and its slot saying the quality.
local function Dress(text, slot, link)
	local quality, r, g, b = Quality(link)
	if r then UI.Ink(text, r, g, b) else UI.Ink(text, C.text) end
	slot:Quality(quality)
end

-- An item's price text: gold plus any alternate currencies.
local function Price(g)
	local info = g.info
	local price = info.price or 0
	local parts = {}
	if price > 0 or not info.hasExtendedCost then parts[1] = Shop.Money(price) end
	if info.hasExtendedCost then
		for i = 1, MAX_ITEM_COST do
			local texture, value = GetMerchantItemCostItem(g.index, i)
			if texture and value and value > 0 then parts[#parts + 1] = ("%d|T%s:10:10:2:0|t"):format(value, texture) end
		end
	end
	return table.concat(parts, " ")
end

-- Vendor value of the grey items in your bags.
local function JunkValue()
	local total = 0
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
				local price = select(11, C_Item.GetItemInfo(info.itemID)) or 0
				total = total + price * (info.stackCount or 1)
			end
		end
	end
	return total
end

-- Durability of your gear in percent, or nil when nothing has durability.
local function Gear()
	local have, most = 0, 0
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local now, whole = GetInventoryItemDurability(slot)
		if now and whole and whole > 0 then have, most = have + now, most + whole end
	end
	if most == 0 then return nil end
	return math.floor(have / most * 100)
end

local function Room()
	local bags = Shy.addons.Bags
	if bags and bags.Room then return (bags:Room()) end
	return C_Container.CalculateTotalNumberOfFreeBagSlots()
end

-- From ShyQuest: missing, quest title, have, need.
local function Wanted(id)
	local quest = Shy.addons.Quest
	if not id or not quest or not quest.Wanted then return nil end
	return quest:Wanted(id)
end

-- Sets the fields Blizzard's click code reads from its item buttons, on a button of ours.
local function Fields(button, g)
	local info = g.info
	button:SetID(g.index)
	if info.hasExtendedCost and (info.price or 0) <= 0 then button.price = nil else button.price = info.price end
	button.extendedCost = info.hasExtendedCost or nil
	button.name, button.link, button.texture = info.name, g.link, info.texture
	button.count = info.stackCount
	button.showNonrefundablePrompt = not C_MerchantFrame.IsMerchantItemRefundable(g.index)
	button.hasItem = true
end

-- How many to buy for `missing`: whole vendor stacks, capped by one purchase's maximum, the
-- vendor's stock and your gold (or `money`). Returns that, its cost, the uncapped-by-gold count and its cost.
local function Plan(g, missing, money)
	local info = g.info
	local stack = math.max(1, info.stackCount or 1)
	local want = math.ceil(missing / stack) * stack
	local most = GetMerchantItemMaxStack(g.index) or stack
	if want > most then want = math.max(stack, math.floor(most / stack) * stack) end
	if info.numAvailable and info.numAvailable >= 0 then want = math.min(want, info.numAvailable * stack) end
	local price = info.price or 0
	local qty = want
	if price > 0 then qty = math.min(qty, math.floor((money or GetMoney()) / price) * stack) end
	if qty > 0 and CanAffordMerchantItem(g.index) == false then qty = 0 end   -- alternate currencies
	return qty, math.floor(price * qty / stack + 0.5), want, math.floor(price * want / stack + 0.5)
end

-- Whether the game buys a good without asking first.
local function Direct(g)
	local info = g.info
	return not info.hasExtendedCost and (info.price or 0) < MERCHANT_HIGH_PRICE_COST and C_MerchantFrame.IsMerchantItemRefundable(g.index)
end

-- The good picked for the foot's purchase, while it is still on the list.
local function Picked()
	if not visit.pick or (visit.mode or ALL) == BACK then return nil end
	for _, g in ipairs(goods) do
		if g.index == visit.pick then return g end
	end
end

-- The most of a good one press of Buy takes, and what it comes in: whole stacks, as many purchases as L.buys (one,
-- where the game asks first), within the vendor's stock, your gold and your bags.
local function Most(g)
	local info = g.info
	local stack = math.max(1, info.stackCount or 1)
	local per = GetMerchantItemMaxStack(g.index) or stack
	per = math.max(stack, math.floor(per / stack) * stack)
	local most = Direct(g) and per * math.min(L.buys, math.max(1, Room())) or per
	if info.numAvailable and info.numAvailable >= 0 then most = math.min(most, info.numAvailable * stack) end
	local price = info.price or 0
	if price > 0 then most = math.min(most, math.floor(GetMoney() / price) * stack) end
	if most > 0 and CanAffordMerchantItem(g.index) == false then most = 0 end
	return most, stack, per
end

-- Clicks

-- The stack split popup's callback, as Blizzard's item button handles it.
local function SplitStack(button, split)
	if button.extendedCost or button.showNonrefundablePrompt then
		MerchantFrame_ConfirmExtendedItemCost(button, split)
	elseif split > 0 then
		BuyMerchantItem(button:GetID(), split)
	end
end

-- Something of yours let go of on the window is sold: Blizzard's own handlers, as on its window.
local function Drop()
	local drop = MerchantFrame:GetScript("OnReceiveDrag")
	if drop then drop(MerchantFrame) end
end

local function Release()
	if not GetCursorInfo() then return end
	local up = MerchantFrame:GetScript("OnMouseUp")
	if up then up(MerchantFrame) end
end

-- A good clicked is the foot's purchase; clicked again, it is let go.
local function Pick(g)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if own.count then own.count.box:ClearFocus() end
	visit.wide = nil   -- Buy's width is held for one good
	if visit.pick == g.index then
		visit.pick, visit.count = nil, nil
	else
		visit.pick, visit.count = g.index, nil
	end
	Refresh()
end

local function RowClick(self, button)
	if self.kind == "back" then
		if IsModifiedClick() then
			HandleModifiedItemClick(GetBuybackItemLink(self:GetID()))
		else
			BuybackItem(self:GetID())
		end
	elseif IsModifiedClick() then
		MerchantItemButton_OnModifiedClick(self, button)
	elseif button == "RightButton" then
		MerchantItemButton_OnClick(self, button)
	elseif GetCursorInfo() then
		Drop()
	elseif self.good then
		Pick(self.good)
	end
end

-- The game's tooltip at the picture's top right corner.
local function RowEnter(self)
	UI.GameTipAt(self, self.icon)
	if self.kind == "back" then
		GameTooltip:SetBuybackItem(self:GetID())
		ShowBuybackSellCursor(self:GetID())
	else
		GameTooltip:SetMerchantItem(self:GetID())
		GameTooltip_ShowCompareItem(GameTooltip)
		SetCursor(CanAffordMerchantItem(self:GetID()) == false and "BUY_ERROR_CURSOR" or "BUY_CURSOR")
	end
	GameTooltip:Show()
end

local function RowLeave()
	GameTooltip:Hide()
	ResetCursor()
end

-- Buys what the order on this button still needs. A purchase the game confirms first (alternate
-- currency, non-refundable, high price) goes through Blizzard's own popup.
local function BuyOrder(self)
	local order = self.order
	local g = order and order.good
	if not g or order.missing <= 0 then return end
	local qty = Plan(g, order.missing)
	if qty <= 0 then return end
	if self.extendedCost or self.showNonrefundablePrompt then
		MerchantFrame_ConfirmExtendedItemCost(self, qty)
	elseif self.price and self.price >= MERCHANT_HIGH_PRICE_COST then
		MerchantFrame_ConfirmHighCostItem(self, qty)
	else
		BuyMerchantItem(self:GetID(), qty)
	end
end

-- What "Buy all" buys: { { good, qty }, ... }, its cost, and whether an order was left to its own button.
local function All()
	local list, money, cost, left = {}, GetMoney(), 0, false
	for _, order in ipairs(visit.orders or {}) do
		local g = order.good
		if g and order.missing > 0 then
			if Direct(g) then
				local qty, spent = Plan(g, order.missing, money)
				if qty > 0 then
					list[#list + 1] = { good = g, qty = qty }
					money, cost = money - spent, cost + spent
				end
			else
				left = true
			end
		end
	end
	return list, cost, left
end

local function BuyAll()
	for _, buy in ipairs((All())) do BuyMerchantItem(buy.good.index, buy.qty) end
end

-- The foot's Buy: the picked good, as many as its count says. One the game asks about first goes to Blizzard's own
-- confirmation, a purchase's worth; any other is bought a purchase at a time.
local function BuyPicked(self)
	local g = Picked()
	if not g then return end
	local most, stack, per = Most(g)
	local n = math.min(visit.count or stack, most)
	if n <= 0 then return end
	if not Direct(g) then
		Fields(self, g)
		if self.extendedCost or self.showNonrefundablePrompt then
			MerchantFrame_ConfirmExtendedItemCost(self, n)
		else
			MerchantFrame_ConfirmHighCostItem(self, n)
		end
		return
	end
	while n > 0 do
		local take = math.min(n, per)
		BuyMerchantItem(g.index, take)
		n = n - take
	end
end

-- The foot's purchase, said in a hover: what and how many with the sum, then what it leaves you, or why it can't
-- be bought.
local function Deal()
	local g = Picked()
	if not g then return nil end
	local most, stack = Most(g)
	local n = visit.count or stack
	local price = g.info.price or 0
	local cost = math.floor(price * n / stack + 0.5)
	local _, r, gg, b = Quality(g.link)
	local rows = { { icon = g.info.texture, text = WORDS.times:format(n, g.info.name or ""), color = r and { r, gg, b } or nil,
		right = price > 0 and Shop.Money(cost) or nil } }
	if n > most then
		rows[#rows + 1] = { text = g.info.numAvailable == 0 and WORDS.gone or WORDS.short, color = C.bad }
	elseif price > 0 then
		rows[#rows + 1] = { text = WORDS.leaves, right = Shop.Money(GetMoney() - cost), quiet = true }
	end
	return { strip = WORDS.buying, sections = { { rows = rows } } }
end

-- Shows it beside the window, level with the foot (as a good's tooltip stands beside its row, on the side with
-- room, never over the goods), or says it again there as the count changes.
local function Tell()
	local content = Deal()
	if content then Shy.Hover.Show(own.deal, content, { at = UI.Beside(desk.box, own.deal, { up = true }), keep = false }) end
end

-- After a sell or repair click the window shows it as done at once (which also blocks a double
-- click). If the game hasn't confirmed within L.asked seconds, the button comes back.
local function Ask(key, sum, amount)
	visit[key] = { at = GetTime(), sum = sum, amount = amount }
	visit[sum] = (visit[sum] or 0) + amount
	C_Timer.After(L.asked + 0.1, function() Stale() end)
end

local function Asked(key)
	local ask = visit[key]
	if not ask then return false end
	if GetTime() - ask.at <= L.asked then return true end
	local left = (visit[ask.sum] or 0) - ask.amount
	visit[ask.sum] = left > 0 and left or nil
	visit[key] = nil
	return false
end

local function SellJunk()
	if Asked("selling") or C_MerchantFrame.GetNumJunkItems() == 0 then return end
	Ask("selling", "sold", JunkValue())
	C_MerchantFrame.SellAllJunkItems()
	Stale()
end

local function Repair()
	if Asked("repairing") then return end
	local cost, needed = GetRepairAllCost()
	if not needed or cost <= 0 or GetMoney() < cost then return end
	Ask("repairing", "repaired", cost)
	RepairAllItems()
	PlaySound(SOUNDKIT.ITEM_REPAIR)
	Stale()
end

-- A gear vendor's sort.
local function SetSort(i)
	if (visit.sort or BEST) == i then return end
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	visit.sort = i
	own.area:SetVerticalScroll(0)
	Refresh()
end

-- The strip's choice.
local function SetMode(i)
	if (visit.mode or ALL) == i then return end
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	visit.mode = i
	own.area:SetVerticalScroll(0)
	Refresh()
end

-- What to sell (ShyBags' sale list)

local function Bags()
	local bags = Shy.addons.Bags
	return bags and bags.SaleList and bags or nil
end

local function ToggleSell()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	visit.page = visit.page ~= SELL and SELL or nil
	own.area:SetVerticalScroll(0)
	Refresh()
end

-- The ticked rows sold, a few a second (ShyBags).
local function SellTicked()
	local bags, sale = Bags(), visit.sale
	if not (bags and sale) then return end
	local rows = {}
	for _, g in ipairs(sale.groups) do
		for _, r in ipairs(g.rows) do
			if r.checked then rows[#rows + 1] = r end
		end
	end
	if #rows > 0 then bags:Sell(rows) end
	Stale()
end

local function TickRow(r)
	local bags = Bags()
	if not (bags and r) then return end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	bags:SaleCheck(r.id, not r.checked, r.kind)
	Refresh()
end

-- Building

-- A button of the foot: words alone while quiet, the one filled button the page's answer. Its hover says only why
-- it waits (UI.Button's own).
local function FootButton(word, onClick)
	local b = UI.Button(own.foot, word, 96, onClick)
	b:SetHeight(L.key)
	b:SetFrameLevel(own.foot:GetFrameLevel() + 2)
	b.dims = true
	b:Hide()
	return b
end

-- A caption in small capitals.
local function Caption(parent)
	local cap = Text(parent, UI.TextFont(10), C.dim)
	cap:Hide()
	return cap
end

-- An order: what to buy and why, as a card in its tone (a quest's gold, a restock's accent), with its button.
local function Card(i)
	local card = own.cards[i]
	if card then return card end
	card = CreateFrame("Frame", nil, own.stock)
	card:SetHeight(L.card)
	card.fill = card:CreateTexture(nil, "BACKGROUND")
	card.fill:SetAllPoints()
	card.edge = card:CreateTexture(nil, "BORDER")
	card.edge:SetPoint("TOPLEFT")
	card.edge:SetPoint("BOTTOMLEFT")
	card.edge:SetWidth(2)
	card.item = CreateFrame("Frame", nil, card)
	card.item:SetSize(L.cardSlot, L.cardSlot)
	card.item:SetPoint("LEFT", L.cardPad, 0)
	card.item:EnableMouse(true)
	card.icon = card.item:CreateTexture(nil, "ARTWORK")
	card.icon:SetAllPoints()
	card.icon:SetTexCoord(unpack(Shop.ICON))
	card.slot = Slot.New(card.item, { to = card.icon, icon = card.icon, size = L.cardSlot, hover = false })
	card.item:SetScript("OnEnter", function(self)
		local g = card.buy.order and card.buy.order.good
		if not g then return end
		UI.GameTipAt(self)
		GameTooltip:SetMerchantItem(g.index)
		GameTooltip:Show()
	end)
	card.item:SetScript("OnLeave", function() GameTooltip:Hide() end)
	card.buy = Shop.Button(card, "go", BuyOrder)
	card.buy:SetHeight(20)
	card.buy:SetPoint("RIGHT", -L.cardPad, 0)
	card.word = Text(card, UI.NameFont(11), C.good)
	card.word:SetPoint("RIGHT", -L.cardPad - 2, 0)
	card.word:SetText(WORDS.done)
	card.name = Text(card, UI.TitleFont(13))
	card.name:SetPoint("BOTTOMLEFT", card.item, "RIGHT", 10, 1)
	card.count = Text(card, UI.NameFont(11), C.alert)
	card.count:SetPoint("TOPLEFT", card.item, "RIGHT", 10, -2)
	own.cards[i] = card
	return card
end

-- A good: its picture in a slot (a stack's count on it), its name, and under the name its price, what is left and
-- what you carry. Its texts are .title, .cost and .stack, not .name, .price and .count: a row is handed to
-- Blizzard's click code, which reads the item's name, price and stack from fields with those names.
local function Row(i)
	local row = own.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, own.stock)
	row:SetHeight(L.row)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:RegisterForDrag("LeftButton")
	-- Picked: your color washed in from the left. Under the mouse: a lighter row.
	row.lit = row:CreateTexture(nil, "BACKGROUND")
	row.lit:SetAllPoints()
	row.lit:SetColorTexture(1, 1, 1, 1)
	row.lit:Hide()
	row.hot = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.row, 0.95)
	row.hot:Hide()
	local rule = row:CreateTexture(nil, "BORDER")
	rule:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
	rule:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
	rule:SetHeight(1)
	UI.Paint(rule, C.rowEdge, 0.7)
	-- A bar at its edge: a good that is wanted in the order's tone, the one picked in your color.
	row.bar = row:CreateTexture(nil, "ARTWORK")
	row.bar:SetSize(2, L.row - 12)
	row.bar:SetPoint("LEFT", 0, 0)
	row.bar:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(L.rowSlot, L.rowSlot)
	row.icon:SetPoint("LEFT", L.rowPad, 0)
	row.icon:SetTexCoord(unpack(Shop.ICON))
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, size = L.rowSlot, hover = false })
	row.stack = row:CreateFontString(nil, "OVERLAY")
	row.stack:SetFontObject(NumberFontNormal)
	row.stack:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 0)
	row.slot:Count(row.stack)
	row.title = Text(row, UI.TitleFont(12))
	row.title:SetPoint("TOPLEFT", L.rowLeft, -6)
	row.cost = Text(row, UI.NameFont(11), C.dim)
	row.cost:SetPoint("BOTTOMLEFT", L.rowLeft, 6)
	row.tag = Text(row, UI.NameFont(10), C.dim)
	row.tag:SetPoint("BOTTOMRIGHT", -L.rowEnd, 6)
	row.tag:SetJustifyH("RIGHT")
	row.tag:SetWordWrap(false)
	row.sub = Text(row, UI.NameFont(10), C.dim)
	row.sub:SetPoint("LEFT", row.cost, "RIGHT", 7, 0)
	-- (Cut short at the word, never run under it.)
	row.sub:SetPoint("RIGHT", row.tag, "LEFT", -8, 0)
	row.sub:SetWordWrap(false)

	row.SplitStack = SplitStack
	row.UpdateTooltip = RowEnter
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		RowEnter(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		RowLeave()
	end)
	row:SetScript("OnClick", RowClick)
	row:SetScript("OnDragStart", function(self)
		if self.kind ~= "back" then MerchantItemButton_OnClick(self, "LeftButton") end
	end)
	row:SetScript("OnReceiveDrag", Drop)
	row:SetScript("OnHide", function(self)
		if self.hasStackSplit == 1 then StackSplitFrame:Hide() end
	end)
	own.rows[i] = row
	return row
end

local function Build()
	desk = Shop.Desk({
		id = "shyskin.merchant", title = WORDS.title, glyph = "coin",
		frame = function() return MerchantFrame end,
		on = function() return M ~= nil and M.on == true end,
		try = function(fn) Shop.Try(M, fn) end,
		flow = function() if Stale then Stale() end end,
		close = function() CloseMerchant() end,
	})
	local box, shell = desk.box, desk.shell
	own.box, own.shell, own.band, own.foot, own.ground, own.driver = box, shell, shell.band, shell.foot, shell.ground, desk.driver

	-- The band's chores: Repair all in the merchant's gold, Sell junk in your color, each with its sum.
	own.repair = Shop.Button(shell.band, "go", Repair)
	own.junk = Shop.Button(shell.band, "accent", SellJunk)
	-- At its top right, with ShyBags: what to sell.
	own.sellKey = Shop.Button(shell.band, "accent", ToggleSell)
	own.sellKey:Hide()

	-- The strip: what is listed, and a search.
	local strip = CreateFrame("Frame", nil, box)
	strip:SetHeight(L.strip)
	strip:SetPoint("TOPLEFT", shell.band, "BOTTOMLEFT", WIN.pad - 2, -L.stripTop)
	strip:SetFrameLevel(box:GetFrameLevel() + 3)
	own.strip = strip
	own.filter = UI.Segments(strip, WORDS.modes, SetMode, { height = L.strip })
	own.filter:SetPoint("TOPLEFT")
	-- (A gear vendor's sort, beside it.)
	own.sort = UI.Segments(strip, WORDS.sorts, SetSort, { height = L.strip })
	own.sort:SetPoint("LEFT", own.filter, "RIGHT", 10, 0)
	own.sort:Hide()
	own.search = Shop.Search(strip, WORDS.search, function(text)
		if (visit.find or "") == text then return end
		visit.find = text ~= "" and text or nil
		own.area:SetVerticalScroll(0)
		Stale()
	end)
	own.search:SetHeight(L.strip - 2)
	own.search:SetPoint("TOPRIGHT", 0, -1)

	-- The foot: your gold in its middle, always. With a good picked, its count at the left end (to step or type,
	-- Max on its plate) and Buy with the sum at the right end, a fixed place each: nothing Buy's words do can move
	-- the count from under the mouse. With none picked, how to buy stands where each of them will. What is being
	-- bought is said in a hover.
	own.gold = Text(shell.foot, UI.NameFont(12), C.head)
	own.gold:SetPoint("CENTER")
	own.hint = Text(shell.foot, UI.TextFont(11), C.dim)
	own.hint:SetPoint("LEFT", WIN.button, 0)
	own.hintOne = Text(shell.foot, UI.TextFont(11), C.dim)
	own.hintOne:SetPoint("RIGHT", -WIN.button, 0)
	own.hintOne:SetJustifyH("RIGHT")
	own.hintOne:SetText(WORDS.hintOne)
	own.b = { buy = FootButton(WORDS.buyIt, BuyPicked), sell = FootButton(WORDS.sellIt, SellTicked), back = FootButton(WORDS.goodsKey, ToggleSell) }
	own.count = Shop.Stepper(shell.foot, { width = L.count, height = L.key, max = WORDS.max, onChange = function(n)
		visit.count = n
		Stale()
	end })
	own.count:SetPoint("LEFT", WIN.button, 0)
	own.count:SetFrameLevel(shell.foot:GetFrameLevel() + 2)
	own.count:Hide()
	-- The purchase's hover: one frame from the count to Buy owns it and says where it stands, so it is the same
	-- hover in the same place from either of them.
	local deal = CreateFrame("Frame", nil, shell.foot)
	deal:SetPoint("TOPLEFT", own.count, "TOPLEFT")
	deal:SetPoint("BOTTOMRIGHT", own.b.buy, "BOTTOMRIGHT")
	deal:Hide()
	own.deal = deal
	local function Leave() Shy.Hover.Hide(deal) end
	for _, piece in ipairs({ own.count.less, own.count.more, own.count.max, own.count.box, own.b.buy }) do
		piece:HookScript("OnEnter", Tell)
		piece:HookScript("OnLeave", Leave)
	end

	-- Something of yours let go of on the ground between the rows is sold.
	shell.ground:EnableMouse(true)
	shell.ground:SetScript("OnReceiveDrag", Drop)
	shell.ground:SetScript("OnMouseUp", Release)

	-- The orders and the goods, scrolling between the strip and the foot. All of it hangs from one frame, which
	-- rises into place as the window opens.
	local area = UI.ScrollArea(box, WIN.w, WIN.h, { smooth = true, shades = C.panel })
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -L.stripFoot)
	area:SetPoint("BOTTOMRIGHT", shell.foot, "TOPRIGHT", -6, 2)
	area:SetFrameLevel(box:GetFrameLevel() + 3)
	own.area, own.sheet = area, area.content
	own.stock = CreateFrame("Frame", nil, own.sheet)
	own.stock:SetPoint("TOPLEFT")
	own.stock:SetSize(WIN.w, 1)
	own.buyCap = Caption(own.stock)
	own.buyCap:SetText(WORDS.buy)
	own.all = Shop.Button(own.stock, "go", BuyAll)
	own.all:Hide()
	own.listCap = Caption(own.stock)
	own.none = Text(own.stock, UI.TextFont(12), C.dim)
	own.none:Hide()
	-- What to sell, in the goods' place.
	own.sellPage = CreateFrame("Frame", nil, own.sheet)
	own.sellPage:SetPoint("TOPLEFT")
	own.sellPage:SetSize(WIN.w, 1)
	own.sellPage:Hide()
	own.sellNone = Text(own.sellPage, UI.TextFont(12), C.dim)
	own.sellNone:SetPoint("TOPLEFT", 4, -(L.top + 6))
	own.sellNone:SetText(WORDS.sellNone)

	-- The opening: the sheet's pieces a line after a line, the sheet rising; the band's and the foot's with the first.
	desk.risers = { { own.stock, own.sheet } }
	desk.Pieces = function()
		local list = { own.buyCap, own.all, own.listCap, own.none }
		for _, pool in ipairs({ own.cards, own.rows }) do
			for _, piece in ipairs(pool) do
				if piece:IsShown() then list[#list + 1] = piece end
			end
		end
		return list
	end
	desk.Firsts = function()
		local list = { own.repair, own.junk, own.sellKey, own.strip, own.gold, own.hint, own.hintOne, own.count, own.b.buy }
		for _, pill in ipairs(shell.pills) do list[#list + 1] = pill end
		return list
	end
	desk.Draw = function() Draw() end
end

-- What to buy

-- From ShyQuest: what to restock from these goods, most urgent first.
local function Restock()
	local quest = Shy.addons.Quest
	if not quest or not quest.Supplies then return nil end
	local ids = {}
	for _, g in ipairs(goods) do
		if g.id then ids[#ids + 1] = g.id end
	end
	return quest:Supplies(ids)
end

-- What is wanted from these goods now: every item here a quest still needs, then what ShyQuest
-- says to restock.
local function Wants()
	local list = {}
	for _, g in ipairs(goods) do
		local missing, title, have, need = Wanted(g.id)
		if missing and missing > 0 then
			g.wanted = true
			have = have or 0
			list[#list + 1] = { key = "quest" .. g.id, good = g, why = WORDS.forQuest:format(title or WORDS.aQuest),
				missing = missing, have = have, need = need or have + missing, name = g.info.name, texture = g.info.texture, link = g.link }
		end
	end
	for _, want in ipairs(Restock() or {}) do
		for _, g in ipairs(goods) do
			if g.id == want.id then
				g.stock = true
				list[#list + 1] = { key = want.key, good = g, stock = true, why = want.title, missing = want.missing,
					have = want.have, need = want.need, name = g.info.name, texture = g.info.texture, link = g.link }
				break
			end
		end
	end
	return list
end

-- The orders to show: each wanted this visit, in the order they came, a filled one as "Bought"
-- (so a second click meant for it can't buy another). Past L.orders the filled make room first.
local function ReadOrders()
	local now, by = Wants(), {}
	for _, order in ipairs(now) do by[order.key] = order end
	local list, kept = visit.orders or {}, {}
	visit.orders = list
	for i, shown in ipairs(list) do
		local order = by[shown.key]
		if order then
			list[i], kept[order.key] = order, true
		elseif shown.missing > 0 then
			shown.missing, shown.have, shown.good = 0, shown.need, nil
		end
	end
	for _, order in ipairs(now) do
		if not kept[order.key] then list[#list + 1] = order end
	end
	while #list > L.orders do
		local gone = #list
		for i, order in ipairs(list) do
			if order.missing <= 0 then
				gone = i
				break
			end
		end
		table.remove(list, gone)
	end
	return list
end

-- What stands out for you among the goods: wanted by a quest or your supplies, an upgrade, a recipe to learn.
local function ForYou(g)
	return g.wanted or g.stock or g.gear == "upgrade" or g.gear == "later" or g.learn or false
end

-- Best for you: upgrades (the most first: gear, and recipes you can learn that make it), what you can wear later (the
-- soonest first), recipes you can learn, the rest of the gear, recipes you need more skill for (the nearest first),
-- what you can't use, anything else (in the vendor's order), recipes you know, recipes of another trade.
local RANK = { upgrade = 1, later = 2, learn = 3, same = 4, worse = 5, skill = 6, cant = 7, other = 8, known = 9, trade = 10 }
local function Kind(g)
	if g.recipe then
		if g.known then return "known" end
		if g.skill == 0 then return "trade" end
		if g.skill < g.skillAt then return "skill" end
	end
	local v = g.verdict
	if v and RANK[v.kind] then return v.kind end
	if g.recipe then return "learn" end
	return g.wearable and "cant" or "other"
end
local function Rank(g) return RANK[Kind(g)] end
local function Spend(g) return g.spend or g.info.price or 0 end
local SORTS = {
	[BEST] = function(a, b)
		local x, y = Rank(a), Rank(b)
		if x ~= y then return x < y end
		local v, w = a.verdict, b.verdict
		if x == 1 and (v.score or 0) ~= (w.score or 0) then return (v.score or 0) > (w.score or 0) end
		if x == 2 and (v.later or 0) ~= (w.later or 0) then return (v.later or 0) < (w.later or 0) end
		if x == RANK.skill and a.skillAt ~= b.skillAt then return a.skillAt < b.skillAt end
		return a.index < b.index
	end,
	[CHEAP] = function(a, b)
		if Spend(a) ~= Spend(b) then return Spend(a) < Spend(b) end
		return a.index < b.index
	end,
	-- What you can wear now first, the highest of it first; then what you grow into, the nearest first.
	[LEVEL] = function(a, b)
		local me = UnitLevel("player")
		local x, y = a.level or 0, b.level or 0
		if (x <= me) ~= (y <= me) then return x <= me end
		if x ~= y then return (x <= me) == (x > y) end
		return a.index < b.index
	end,
}

-- The buy button (or "Bought") of a card; its hover says only what its face can't. Returns the room the name and
-- the count have left of `room`.
local function Offer(card, order, room)
	local missing, g = order.missing, order.good
	card.buy.order = order
	if missing > 0 and g then
		local qty, cost, want, wantCost = Plan(g, missing)
		local head = order.stock and WORDS.stockUp or WORDS.missing
		Fields(card.buy, g)
		if qty > 0 then
			card.buy:Say(WORDS.buyN:format(qty) .. DOT .. Shop.Money(cost))
			card.buy.tip = qty > missing and { head, WORDS.stacks:format(g.info.stackCount) }
				or qty < want and { head, WORDS.afford:format(qty, missing) }
				or qty < missing and { head, WORDS.onePurchase:format(qty, missing) }
				or nil
		else
			card.buy:Say(WORDS.buyN:format(math.max(want, 1)) .. DOT .. Shop.Money(wantCost))
			card.buy.tip = { head, want == 0 and WORDS.noneLeft or WORDS.short .. "." }
		end
		card.buy:SetOff(qty <= 0)
		card.buy:Show()
		card.word:Hide()
	else
		card.buy:Hide()
		card.word:Show()
	end
	local taken = card.buy:IsShown() and card.buy:GetWidth() + 8 or card.word:GetStringWidth() + 10
	return room - taken
end

local function FillCard(card, order, width)
	local missing = order.missing
	local open = missing > 0 and order.good ~= nil
	-- Gold is a quest's; a restock wears the accent. Bought, it goes quiet.
	local tone = order.stock and C.hot or C.alert
	UI.Paint(card.fill, open and tone or C.text, open and 0.10 or 0.05)
	UI.Paint(card.edge, open and tone or C.good, 0.9)
	card.icon:SetTexture(order.texture)
	card.name:SetText(order.name or "")
	Dress(card.name, card.slot, order.link)
	local why = (missing > 0 and order.why) and UI.Wrap(C.dim, DOT .. order.why) or ""
	card.count:SetText(WORDS.of:format(order.have, order.need) .. why)
	UI.Ink(card.count, missing > 0 and tone or C.good)
	local room = math.max(40, Offer(card, order, width - 2 * L.cardPad - L.cardSlot - 10))
	card.name:SetWidth(room)
	card.count:SetWidth(room)
end

-- The goods

-- A row's words in the width it has, once they are set: the name whole across it; under it the price, then what is
-- left and what you carry in the room the price and the tag leave. Each is cut where it would run past its room.
local function LayRow(row, width)
	local room = width - L.rowLeft - L.rowEnd
	row.title:SetWidth(room)
	local tag = row.tag:GetText()
	if tag and tag ~= "" then room = room - row.tag:GetStringWidth() - 8 end
	local cost = row.cost:GetUnboundedStringWidth()
	row.cost:SetWidth(cost > room and room or 0)
	row.sub:SetWidth(math.max(1, room - cost - 7))
end

-- ShyGear's mark on a row's picture, made when the first upgrade is seen.
local function GearMark(row, kind)
	if kind and not row.gear then
		local gear = Shy.addons.Gear
		if gear and gear.Mark then row.gear = gear:Mark(row, row.icon) end
	end
	if row.gear then row.gear:Set(kind) end
end

local function Lit(row, on)
	if on then
		local r, g, b = Theme.Accent()
		row.lit:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.24), CreateColor(r, g, b, 0.02))
	end
	row.lit:SetShown(on)
end

-- ShyGear's word for an upgrade, its biggest gain alone ("+13% survival"): the rest is on the item's card.
local function GearWords(v)
	local gear = Shy.addons.Gear
	if not (gear and gear.Words) then return nil end
	local ok, words = pcall(gear.Words, gear, v)
	if not (ok and type(words) == "string" and words ~= "") then return nil end
	return words:match("^([^,]+)") or words
end

local function FillGood(row, g)
	local info = g.info
	row.kind, row.good = "good", g
	Fields(row, g)
	row.icon:SetTexture(info.texture)
	row.title:SetText(info.name or "")
	Dress(row.title, row.slot, g.link)
	row.stack:SetText((info.stackCount or 0) > 1 and info.stackCount or "")
	GearMark(row, g.gear)
	-- What is left, and what you carry.
	local out = info.numAvailable == 0
	local said = {}
	if out then
		said[#said + 1] = UI.Wrap(C.bad, WORDS.out)
	elseif info.numAvailable and info.numAvailable > 0 then
		said[#said + 1] = WORDS.left:format(info.numAvailable)
	end
	if g.have > 0 then said[#said + 1] = WORDS.have:format(g.have) end
	row.sub:SetText(table.concat(said, DOT))
	-- The word that matters most, and its color: a quest's gold, your supplies' accent, an upgrade's green.
	local word, tone = "", C.dim
	local v = g.verdict
	local kind = Kind(g)
	if g.wanted then word, tone = WORDS.quest, C.alert
	elseif g.stock then word, tone = WORDS.restock, C.hot
	elseif kind == "known" then word = WORDS.known
	elseif kind == "trade" then word = WORDS.trade
	elseif kind == "skill" then word, tone = WORDS.skill:format(g.skillAt), C.alert
	elseif v and v.kind == "upgrade" then word, tone = GearWords(v) or WORDS.upgrade, C.good
	elseif v and v.kind == "later" then word, tone = v.later and WORDS.atLevel:format(v.later) or WORDS.upgrade, C.hot
	elseif v and v.kind == "cant" then word = g.recipe and WORDS.cantWear or WORDS.cant
	elseif v and v.kind == "worse" then word = WORDS.worse
	elseif v and v.kind == "same" then word = WORDS.same
	elseif g.learn then word, tone = WORDS.learn, C.hot
	elseif g.known then word = WORDS.known end
	row.tag:SetText(word)
	UI.Ink(row.tag, tone)
	local picked = visit.pick == g.index
	Lit(row, picked)
	row.bar:SetShown(picked or g.wanted or g.stock or false)
	UI.Paint(row.bar, picked and Theme.Accent or (g.wanted and C.alert or C.hot))
	row.cost:SetText(Price(g))
	-- As default: red for unusable, dim for unaffordable or out of stock; a recipe you know is dim too.
	local afford = CanAffordMerchantItem(g.index) ~= false
	local usable = info.isPurchasable and info.isUsable
	UI.Ink(row.cost, afford and C.dim or C.bad)
	if usable then row.icon:SetVertexColor(1, 1, 1) else row.icon:SetVertexColor(0.9, 0, 0) end
	local faint = (out or not afford or g.known) and 0.5 or 1
	row.icon:SetAlpha(faint)
	row.title:SetAlpha(faint)
end

local function FillBack(row, index)
	local name, texture, price, quantity, _, usable = GetBuybackItemInfo(index)
	row.kind, row.good = "back", nil
	row:SetID(index)
	-- Rows are reused between the two lists, so every item field is reset.
	row.price, row.extendedCost, row.showNonrefundablePrompt, row.count = price, nil, nil, quantity
	row.name, row.texture, row.link = name, texture, GetBuybackItemLink(index)
	row.hasItem = true
	row.icon:SetTexture(texture)
	row.title:SetText(name or "")
	Dress(row.title, row.slot, row.link)
	row.stack:SetText((quantity or 0) > 1 and quantity or "")
	GearMark(row, nil)
	row.sub:SetText("")
	row.tag:SetText("")
	Lit(row, false)
	row.bar:Hide()
	row.cost:SetText(Shop.Money(price or 0))
	local afford = GetMoney() >= (price or 0)
	UI.Ink(row.cost, afford and C.dim or C.bad)
	if usable then row.icon:SetVertexColor(1, 1, 1) else row.icon:SetVertexColor(0.9, 0, 0) end
	row.icon:SetAlpha(afford and 1 or 0.5)
	row.title:SetAlpha(afford and 1 or 0.5)
end

-- Drawing

-- What there is to sell and to mend here, and what was, read once a draw for the band:
-- junk, junkValue (some to sell), sold (what selling made), cost, short (a repair to pay, and gold short of it),
-- repaired (what mending cost).
local function Services(repairs)
	local s = {}
	local count = C_MerchantFrame.IsSellAllJunkEnabled() and C_MerchantFrame.GetNumJunkItems() or 0
	local value = count > 0 and JunkValue() or 0
	if count > 0 then
		visit.junkSeen = math.max(visit.junkSeen or 0, value)
	else
		-- Junk that was here and is gone was sold, by hand or by another addon.
		if visit.junkSeen and not visit.sold then visit.sold = visit.junkSeen end
		visit.junkSeen, visit.selling = nil, nil
	end
	if count > 0 and not Asked("selling") then s.junk, s.junkValue = count, value end
	s.sold = visit.sold
	if not repairs then return s end
	local cost, needed = GetRepairAllCost()
	local whole = not needed or cost <= 0
	if whole then
		-- A repair cost that was here and is gone was paid.
		if visit.costSeen and not visit.repaired then visit.repaired = visit.costSeen end
		visit.costSeen, visit.repairing = nil, nil
	else
		visit.costSeen = math.max(visit.costSeen or 0, cost)
	end
	if not whole and not Asked("repairing") then s.cost, s.short = cost, GetMoney() < cost end
	s.repaired = visit.repaired
	return s
end

-- The sell page

local SELLROW = { tall = 36, gap = 2, box = 16, slot = Slot.SIZES.compact, head = 26, between = 6, indent = 22, coins = 11, edge = 6, apart = 10 }

local function SellHead(i)
	local h = own.sellHeads[i]
	if h then return h end
	h = UI.GroupHead(own.sellPage, { height = SELLROW.head, rail = 13, gutter = 26, right = 6, foldSize = 18, line = true,
		tip = function(self) return self.name, self.say end,
		click = function(self, button)
			if button ~= "LeftButton" or not self.key then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			visit.sellFolds = visit.sellFolds or {}
			visit.sellFolds[self.key] = not visit.sellFolds[self.key] or nil
			Refresh()
		end })
	own.sellHeads[i] = h
	return h
end

-- A thing to sell: its tick, its picture (its count on it), its name in its quality's color and under it why; at the
-- right, what a vendor pays and under it what the auction house would, the better one lit. A click ticks it.
local function SellRow(i)
	local row = own.sellRows[i]
	if row then return row end
	row = CreateFrame("Button", nil, own.sellPage)
	row:SetHeight(SELLROW.tall)
	row.hot = row:CreateTexture(nil, "BACKGROUND")
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.hot, 0.08)
	row.hot:Hide()
	row.tick = UI.Checkbox(row, "", function() return row.r ~= nil and row.r.checked == true end, function() TickRow(row.r) end,
		{ box = SELLROW.box })
	row.tick:SetPoint("LEFT", 2, 0)
	row.pic = CreateFrame("Frame", nil, row)
	row.pic:SetSize(SELLROW.slot, SELLROW.slot)
	row.pic:SetPoint("LEFT", SELLROW.box + 10, 0)
	row.icon = row.pic:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexCoord(unpack(Shop.ICON))
	row.slot = Slot.New(row.pic, { icon = row.icon, size = SELLROW.slot, hover = false })
	row.count = row.pic:CreateFontString(nil, "OVERLAY")
	row.slot:Count(row.count)
	local left = SELLROW.box + 10 + SELLROW.slot + 9
	-- Two prices, the sums at the right; their words and the name stand where the page's widest sum leaves room.
	row.money = Text(row, UI.TextFont(SELLROW.coins), C.dim)
	row.money:SetPoint("TOPRIGHT", -SELLROW.edge, -5)
	row.money:SetJustifyH("RIGHT")
	row.house = Text(row, UI.TextFont(SELLROW.coins), C.dim)
	row.house:SetPoint("BOTTOMRIGHT", -SELLROW.edge, 5)
	row.house:SetJustifyH("RIGHT")
	row.moneyWord = Text(row, UI.TextFont(SELLROW.coins), C.dim)
	row.houseWord = Text(row, UI.TextFont(SELLROW.coins), C.dim)
	row.name = Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("TOPLEFT", left, -5)
	row.name:SetWordWrap(false)
	row.why = Text(row, UI.TextFont(10), C.dim)
	row.why:SetPoint("BOTTOMLEFT", left, 6)
	row.why:SetWordWrap(false)
	row:SetScript("OnClick", function(self) TickRow(self.r) end)
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if not (self.r and self.r.link) then return end
		UI.GameTipAt(self)   -- off the row's top right corner, clear of its name
		GameTooltip:SetHyperlink(self.r.link)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	own.sellRows[i] = row
	return row
end

-- One price line: its word, then the sum. The one it fetches more at in full, the other quiet.
local function PriceLine(label, at, word, copper, lit)
	label:SetText(word)
	UI.Ink(label, lit and C.text or C.dim)
	at:SetText(copper and UI.Money(copper, false, SELLROW.coins, at) or WORDS.noPrice)
	UI.Ink(at, lit and C.hot or C.dim)
end

local function FillSell(row, r)
	row.r = r
	row.icon:SetTexture(r.icon or 134400)
	row.icon:SetDesaturated(not r.checked)
	row.slot:Quality(r.quality)
	row.count:SetText(r.count > 1 and r.count or "")
	row.name:SetText(r.name or "")
	local color = r.quality and ColorManager.GetColorDataForItemQuality(r.quality)
	if color then row.name:SetTextColor(color.r, color.g, color.b) else UI.Ink(row.name, C.text) end
	row.why:SetText(r.why or "")
	local auction = r.best == "auction"
	PriceLine(row.moneyWord, row.money, WORDS.vendorPays, r.value or 0, not auction)
	row.house:SetShown(r.auctionable == true)
	row.houseWord:SetShown(r.auctionable == true)
	if r.auctionable then PriceLine(row.houseWord, row.house, WORDS.housePays, r.house, auction) end
	row.tick:Refresh()
	row:SetAlpha(r.checked and 1 or 0.75)
end

local function Wide(text)
	if not text:IsShown() then return 0 end
	local w = text:GetUnboundedStringWidth()
	return (issecretvalue(w) or not w) and 0 or w
end

-- The prices as one column down the page: as wide as its widest sum, the words lined up at its left.
local function LayPrices(count)
	local sums, words = 0, 0
	for i = 1, count do
		local row = own.sellRows[i]
		sums = math.max(sums, Wide(row.money), Wide(row.house))
		words = math.max(words, Wide(row.moneyWord), Wide(row.houseWord))
	end
	local at = SELLROW.edge + sums + SELLROW.apart + words
	for i = 1, count do
		local row = own.sellRows[i]
		row.moneyWord:SetPoint("TOPLEFT", row, "TOPRIGHT", -at, -5)
		row.houseWord:SetPoint("BOTTOMLEFT", row, "BOTTOMRIGHT", -at, 5)
		row.name:SetPoint("RIGHT", row, "RIGHT", -(at + SELLROW.apart), 0)
		row.why:SetPoint("RIGHT", row, "RIGHT", -(at + SELLROW.apart), 0)
	end
end

local function DrawSell(width)
	local page, sale = own.sellPage, visit.sale
	own.stock:Hide()
	page:Show()
	page:SetWidth(width)
	local y, hi, ri = L.top, 0, 0
	local folds = visit.sellFolds or {}
	for _, g in ipairs(sale and sale.groups or {}) do
		hi = hi + 1
		local h = SellHead(hi)
		h.key, h.name, h.say = g.key, WORDS.sellGroups[g.key], WORDS.sellSays[g.key]
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
		h:SetWidth(width - 4)
		h:Set(h.name)
		local ticked, worth = 0, 0
		for _, r in ipairs(g.rows) do
			if r.checked then ticked, worth = ticked + 1, worth + (r.value or 0) end
		end
		local tone = g.key == "house" and C.good or C.dim
		h:SetBadges({ { text = ticked > 0 and (ticked .. DOT .. Shop.Money(worth)) or #g.rows, color = tone } })
		h:SetAccent(g.key == "house" and C.good or nil)
		local open = not folds[g.key]
		h:SetOpen(open)
		h:Show()
		y = y + SELLROW.head
		if open then
			local top = y
			local nodes = {}
			for _, r in ipairs(g.rows) do
				ri = ri + 1
				local row = SellRow(ri)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", page, "TOPLEFT", SELLROW.indent, -y)
				row:SetWidth(width - 4 - SELLROW.indent)
				FillSell(row, r)
				row:Show()
				nodes[#nodes + 1] = y - top + SELLROW.head + SELLROW.tall / 2
				y = y + SELLROW.tall + SELLROW.gap
			end
			h:Hang(y - top, nodes)
		else
			h:Hang()
		end
		y = y + SELLROW.between
	end
	LayPrices(ri)
	for i = hi + 1, #own.sellHeads do own.sellHeads[i]:Hide() end
	for i = ri + 1, #own.sellRows do own.sellRows[i]:Hide() end
	own.sellNone:SetShown(hi == 0)
	page:SetHeight(math.max(1, y))
	own.sheet:SetHeight(y + L.under)
	own.area:Update()
end

-- The band: who the vendor is; under it the chores still to do as buttons, then pills of what was done and what
-- to know; with nothing to say of the visit, where you are, as a talk's band has it.
local function DrawBand(s, repairs, wide)
	local shell = own.shell
	local role, place = desk:Meet("npc", visit)
	-- Sell at the top right: what is ticked to sell, how many and what they come to; on its page, the way back.
	local sale = visit.sale
	local key = own.sellKey
	key:SetShown(sale ~= nil)
	local keyRoom = 0
	if sale then
		key:Say(visit.page == SELL and WORDS.goodsKey
			or (sale.count > 0 and (WORDS.sellKey .. " " .. sale.count .. DOT .. Shop.Money(sale.value)) or WORDS.sellKey))
		key:SetOff(false)
		key.tip = visit.page ~= SELL and { WORDS.sellKey, WORDS.sellTip } or nil
		key:ClearAllPoints()
		key:SetPoint("TOPRIGHT", shell.band, "TOPRIGHT", -WIN.pad, -12)
		keyRoom = key:GetWidth() + 10
	end
	local words = math.max(80, wide - shell.left - WIN.pad - 4 - keyRoom)
	shell.role:SetWidth(words)

	local x = shell.left
	local function Chore(button, shown, text, off)
		button:SetShown(shown)
		if not shown then return end
		button:Say(text)
		button:SetOff(off)
		button.tip = off and { text, WORDS.short .. "." } or nil
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", shell.band, "TOPLEFT", x, L.pills)
		x = x + button:GetWidth() + WIN.pillGap
	end
	Chore(own.repair, s.cost ~= nil, WORDS.repair .. DOT .. Shop.Money(s.cost or 0), s.short)
	Chore(own.junk, s.junk ~= nil, WORDS.sell .. DOT .. Shop.Money(s.junkValue or 0), false)

	-- What was done first, then what to know; how worn your gear is comes last (the button beside it says there is
	-- mending to do), so it is the one left out where the band runs short.
	local facts = {}
	if not s.cost and s.repaired then
		facts[#facts + 1] = { text = (visit.byGuild and WORDS.guild or WORDS.repaired) .. DOT .. Shop.Money(s.repaired), tone = "good" }
	elseif not s.cost and repairs then
		facts[#facts + 1] = { text = WORDS.repairs }
	end
	if not s.junk and s.sold then
		facts[#facts + 1] = { text = WORDS.soldJunk .. DOT .. Shop.Money(s.sold), tone = "good" }
	end
	local free = Room()
	if free == 0 then
		facts[#facts + 1] = { text = WORDS.full, tone = "bad" }
	elseif free <= L.tight then
		facts[#facts + 1] = { text = WORDS.room:format(free), tone = "alert" }
	end
	if s.cost then
		local gear = Gear()
		facts[#facts + 1] = { text = gear and WORDS.gear:format(gear) or WORDS.worn, tone = "alert" }
	end
	local shown = shell:Pills(facts, L.pills, x)
	local bare = shown == 0 and x == shell.left
	shell.sub:SetShown(bare)
	shell.sub:SetText(role ~= "" and place or "")
	shell.sub:SetWidth(words)
end

-- The strip: its counts, the choice lit, and the search where there is room for it.
-- The strip: the filter, a currency vendor's sort and the search on one line where they fit; else the filter alone
-- on the first and the rest on a second, so a narrow window loses none of them. Returns how tall it is.
local function DrawStrip(width, mode, backs, forYou)
	own.strip:SetWidth(width)
	own.filter:SetCount(ALL, #goods)
	own.filter:SetCount(FOR_YOU, forYou > 0 and forYou or nil)
	own.filter:SetCount(BACK, backs > 0 and backs or nil)
	if own.filter.selected ~= mode then own.filter:Select(mode) end
	local sorts = visit.gearVendor == true and mode ~= BACK
	own.sort:SetShown(sorts)
	if sorts and own.sort.selected ~= (visit.sort or BEST) then own.sort:Select(visit.sort or BEST) end
	local filter, sort = own.filter:GetWidth(), sorts and own.sort:GetWidth() or 0
	local wrapped = filter + 10 + (sorts and sort + 10 or 0) + L.searchLeast > width
	local y = wrapped and -(L.strip + L.stripGap) or 0
	own.sort:ClearAllPoints()
	if wrapped then own.sort:SetPoint("TOPLEFT", 0, y) else own.sort:SetPoint("LEFT", own.filter, "RIGHT", 10, 0) end
	local used = wrapped and 0 or filter + 10
	local room = width - used - (sorts and sort + 10 or 0)
	own.search:ClearAllPoints()
	own.search:SetPoint("TOPRIGHT", 0, y - 1)
	own.search:SetShown(room >= L.searchLeast)
	own.search:SetWidth(math.min(L.search, math.max(L.searchLeast, room)))
	local tall = wrapped and L.strip * 2 + L.stripGap or L.strip
	own.strip:SetHeight(tall)
	return tall
end

-- The sheet: what to buy as cards, then the goods the strip asks for (or what you sold) in columns, down the first
-- and then the next.
local function DrawSheet(orders, list, mode, width, room)
	local stock = own.stock
	own.sheet:SetWidth(width)
	local y, line = L.top, 0

	-- The orders stand over the goods, whichever of those the strip shows.
	local count, open = mode == BACK and 0 or #orders, 0
	for _, order in ipairs(orders) do
		if order.missing > 0 and order.good then open = open + 1 end
	end
	own.buyCap:SetShown(count > 0)
	own.all:SetShown(count > 0 and open > 1)
	if count > 0 then
		own.buyCap:ClearAllPoints()
		own.buyCap:SetPoint("TOPLEFT", stock, "TOPLEFT", 2, -(y + 4))
		UI.Ink(own.buyCap, open > 0 and C.hot or C.dim)
		own.buyCap.line, own.all.line = line, line
		if open > 1 then
			local buys, cost, asks = All()
			own.all:Say(#buys > 0 and (WORDS.all .. DOT .. Shop.Money(cost)) or WORDS.all)
			own.all:SetOff(#buys == 0)
			own.all.tip = (#buys == 0 and { WORDS.all, asks and WORDS.asksAll or WORDS.short .. "." })
				or (asks and { WORDS.all, WORDS.asksSome }) or nil
			own.all:ClearAllPoints()
			own.all:SetPoint("TOPRIGHT", stock, "TOPLEFT", width, -y)
		end
		y = y + L.cap + 4
	end
	for i = 1, count do
		local card = Card(i)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", stock, "TOPLEFT", 0, -y)
		card:SetWidth(width)
		FillCard(card, orders[i], width)
		card.line = line
		card:Show()
		line = line + 1
		y = y + L.card + L.cardGap
	end
	for i = count + 1, #own.cards do own.cards[i]:Hide() end
	if count > 0 then y = y + L.after end

	-- The list's caption.
	local n = #list
	local cap = own.listCap
	cap:SetText((mode == BACK and WORDS.sold or mode == FOR_YOU and WORDS.forYou or WORDS.sale) .. DOT .. n)
	cap:ClearAllPoints()
	cap:SetPoint("TOPLEFT", stock, "TOPLEFT", 2, -y)
	cap:Show()
	cap.line = line
	line = line + 1
	y = y + L.cap

	-- As few columns as hold the goods in the room there is, as many as the width has when they scroll anyway.
	local most = math.max(1, math.min(L.cols, math.floor((width + L.colGap) / (L.col + L.colGap))))
	local fit = math.max(1, math.floor((room - y - L.under + L.rowGap) / (L.row + L.rowGap)))
	local cols = math.max(1, math.min(most, math.ceil(n / fit)))
	local colW = math.floor((width - (cols - 1) * L.colGap) / cols)
	local per = math.max(1, math.ceil(n / cols))
	for i = 1, n do
		local row = Row(i)
		local column, at = math.floor((i - 1) / per), (i - 1) % per
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", stock, "TOPLEFT", column * (colW + L.colGap), -(y + at * (L.row + L.rowGap)))
		row:SetWidth(colW)
		if mode == BACK then FillBack(row, list[i]) else FillGood(row, list[i]) end
		LayRow(row, colW)
		row.line = line + at
		row:Show()
	end
	for i = n + 1, #own.rows do own.rows[i]:Hide() end
	own.none:SetShown(n == 0)
	if n == 0 then
		own.none:SetText(visit.find and WORDS.noFind or mode == BACK and WORDS.noBack or mode == FOR_YOU and WORDS.noneForYou or WORDS.none)
		own.none:ClearAllPoints()
		own.none:SetPoint("TOPLEFT", stock, "TOPLEFT", 2, -(y + 8))
		own.none.line = line
	end
	y = y + (n == 0 and 1 or per) * (L.row + L.rowGap) + L.under
	own.sheet:SetHeight(y)
	stock:SetSize(width, y)
	own.area:Update()
end

-- The widest a sum up to `most` copper is written: every coin it can have, full under its largest (a round sum
-- drops its small coins, so the sums on the way to it are the wider).
local function Widest(most)
	for _, coin in ipairs({ COPPER_PER_GOLD, L.silver }) do
		if most >= coin then return most - most % coin + coin - 1 end
	end
	return most
end

-- Your gold in the foot's middle; short of room there, in the middle of what the two ends leave; gone with none.
-- left, right: what stands at each end (0: nothing), from the foot's edges.
-- Your gold, and what you have of each currency this vendor takes (Merchant's Favor) before it.
local function Purse()
	local parts = {}
	for _, c in ipairs(visit.wallet or {}) do
		parts[#parts + 1] = ("|T%s:12:12:0:0|t %s"):format(tostring(c.icon or ""), BreakUpLargeNumbers(c.have))
	end
	parts[#parts + 1] = UI.Money(GetMoney(), nil, 12)
	return table.concat(parts, DOT)
end

local function LayGold(gold, wide, left, right)
	local from, to = left > 0 and left + L.apart or 0, wide - (right > 0 and right + L.apart or 0)
	local x = 0
	if wide / 2 - gold / 2 < from or wide / 2 + gold / 2 > to then x = (from + to) / 2 - wide / 2 end
	own.gold:SetShown(to - from >= gold)
	own.gold:ClearAllPoints()
	own.gold:SetPoint("CENTER", own.foot, "CENTER", math.floor(x + 0.5), 0)
end

-- The foot: your gold in its middle; at its ends how to buy, or the picked good's purchase: its count at the left,
-- Buy with the sum at the right. The count never moves; Buy keeps one width for a good, wide enough for any sum its
-- count can come to.
local function DrawFoot(mode, wide)
	local B, shell = own.b, own.shell
	own.gold:SetText(Purse())
	local gold = own.gold:GetUnboundedStringWidth()
	gold = (issecretvalue(gold) or not gold) and 0 or gold
	local foot = wide - 4
	local g = Picked()
	B.buy:SetShown(g ~= nil)
	own.count:SetShown(g ~= nil)
	own.deal:SetShown(g ~= nil)
	if not g then
		if Shy.Hover.Owner() == own.deal then Shy.Hover.Hide(own.deal, true) end
		LayGold(gold, foot, 0, 0)
		-- How to buy, where the count and Buy will stand: each where it clears your gold.
		local side = foot / 2 - gold / 2 - L.apart - WIN.button
		own.hint:SetText(mode == BACK and WORDS.hintBack or WORDS.hint)
		own.hint:SetShown(own.hint:GetUnboundedStringWidth() <= side)
		own.hintOne:SetShown(mode ~= BACK and own.hintOne:GetUnboundedStringWidth() <= side)
		return
	end
	own.hint:Hide()
	own.hintOne:Hide()
	-- The count: what an order for it still asks, else one purchase; within what one press can buy.
	local most, stack = Most(g)
	local n = visit.count
	if not n then
		n = stack
		for _, order in ipairs(visit.orders or {}) do
			if order.good == g and order.missing > 0 then n = math.max(stack, (Plan(g, order.missing))) end
		end
	end
	own.count:Set(n, stack, math.max(stack, most), stack)
	n = own.count:Get()
	visit.count = n
	-- (The count stands beside it, so Buy says only the sum.)
	local price = g.info.price or 0
	local function Words(count)
		return WORDS.buyIt .. (price > 0 and (DOT .. Shop.Money(math.floor(price * count / stack + 0.5))) or "")
	end
	local top = math.floor(price * math.max(most, n) / stack + 0.5)
	B.buy.text:SetText(UI.MoneyFit(WORDS.buyIt .. (price > 0 and (DOT .. Shop.Money(Widest(top))) or ""), B.buy.text))
	local widest = B.buy.text:GetUnboundedStringWidth()
	widest = (issecretvalue(widest) or not widest) and 0 or math.ceil(widest)
	visit.wide = math.max(visit.wide or 0, widest + L.buyPad)
	B.buy.keep = visit.wide
	B.buy.text:SetText(Words(n))
	B.buy:SetUsable(most >= n)
	-- Buy at the right end; the count keeps its place at the left; your gold between them.
	local right = shell:Answers({ B.buy }, L.count + gold + 2 * L.apart)
	LayGold(gold, foot, WIN.button + L.count, -right - WIN.between)
	if Shy.Hover.Owner() == own.deal then Tell() end
end

-- The sell page's foot: your gold, Sell (the ticked, how many and what they come to) and the way back to the goods.
local function DrawSellFoot(wide)
	local B, shell = own.b, own.shell
	B.buy:Hide()
	own.count:Hide()
	own.deal:Hide()
	own.hint:Hide()
	own.hintOne:Hide()
	own.gold:SetText(Purse())
	local gold = own.gold:GetUnboundedStringWidth()
	gold = (issecretvalue(gold) or not gold) and 0 or gold
	local bags, sale = Bags(), visit.sale
	local selling = bags and bags.Selling and bags:Selling()
	B.sell:Show()
	B.back:Show()
	local words = selling and WORDS.selling:format(selling.done, selling.of)
		or (sale and sale.count > 0 and (WORDS.sellIt .. " " .. sale.count .. DOT .. Shop.Money(sale.value))) or WORDS.sellIt
	B.sell.text:SetText(UI.MoneyFit(words, B.sell.text))
	B.sell:SetUsable(not selling and sale ~= nil and sale.count > 0)
	local right = shell:Answers({ B.sell, B.back }, gold + 2 * L.apart)
	LayGold(gold, wide - 4, 0, -right - WIN.between)
end

Draw = function()
	local f = MerchantFrame
	-- (Created the first time a vendor takes a currency other than gold.)
	for i = 1, MAX_MERCHANT_CURRENCIES do Shop.PutAway(f, _G["MerchantToken" .. i]) end

	local box = own.box
	local wide, tall = UI.BodySize(box)   -- (what it holds stands on its body: UI.Body)
	if issecretvalue(wide) or not wide or wide <= 0 then wide = WIN.w end
	if issecretvalue(tall) or not tall or tall <= 0 then tall = WIN.h end
	-- The game's own window, empty under ours, is as wide (up to the width ours is made at): what the game opens
	-- beside it stands clear of ours, and a window dragged wide never crowds the game's other panels off the screen.
	Shop.Size(f, math.min(wide, WIN.w), f:GetHeight())

	ReadGoods()
	-- A currency's vendor (Merchant's Favor's): sorted for you. Any other keeps its own order.
	visit.gearVendor = #visit.wallet > 0
	local backs = GetNumBuybackItems()
	local orders = ReadOrders()
	local forYou = 0
	for _, g in ipairs(goods) do
		if ForYou(g) then forYou = forYou + 1 end
	end
	-- A choice with nothing left in it gives way to the goods.
	local mode = visit.mode or ALL
	if (mode == BACK and backs == 0) or (mode == FOR_YOU and forYou == 0) then mode = ALL end
	visit.mode = mode
	-- What the strip asks for, by the search.
	local find = visit.find and visit.find:lower()
	local list = {}
	if mode == BACK then
		for i = 1, backs do
			local name = GetBuybackItemInfo(i)
			if not find or (name and name:lower():find(find, 1, true)) then list[#list + 1] = i end
		end
	else
		for _, g in ipairs(goods) do
			local name = g.info.name
			if (mode == ALL or ForYou(g)) and (not find or (name and name:lower():find(find, 1, true))) then list[#list + 1] = g end
		end
		-- A gear vendor's goods in the sort picked; any other's in the vendor's own order.
		if visit.gearVendor then table.sort(list, SORTS[visit.sort or BEST]) end
	end

	-- What to sell, with ShyBags; its page only while there is a sale list to show.
	local bags = Bags()
	visit.sale = bags and bags:SaleList() or nil
	if not visit.sale then visit.page = nil end
	local selling = visit.page == SELL

	local repairs = CanMerchantRepair() and true or false
	DrawBand(Services(repairs), repairs, wide)
	-- The sheet's width (the window's, less the band's inset, the area's and the scroll bar's) and the area's height.
	local width = math.floor(wide - 4 - (WIN.pad - 2) - 6 - L.bar)
	local room = tall - (UI.HEAD.window.line + UI.LINE) - WIN.band - WIN.foot - 6 - L.stripTop - L.stripFoot
	own.strip:SetShown(not selling)
	own.area:ClearAllPoints()
	if selling then
		own.area:SetPoint("TOPLEFT", own.shell.band, "BOTTOMLEFT", WIN.pad - 2, -L.stripTop)
	else
		own.area:SetPoint("TOPLEFT", own.strip, "BOTTOMLEFT", 0, -L.stripFoot)
	end
	own.area:SetPoint("BOTTOMRIGHT", own.shell.foot, "TOPRIGHT", -6, 2)
	if selling then
		DrawSell(width)
		DrawSellFoot(wide)
	else
		own.sellPage:Hide()
		own.stock:Show()
		own.b.sell:Hide()
		own.b.back:Hide()
		room = room - DrawStrip(width, mode, backs, forYou)
		DrawSheet(orders, list, mode, width, room)
		DrawFoot(mode, wide)
	end
	desk:Motion()
end

Refresh = function()
	if not (M and M.on and own.box) then return end
	-- Nothing is drawn while closed; what the bus reported is kept for when it opens.
	if MerchantFrame:IsShown() then Shop.Try(M, Draw) end
end

Stale = Shop.Later(function() Refresh() end)

local function EndVisit()
	wipe(visit)
	if not desk then return end
	if desk.motion then desk:Rest() end
	own.search:SetText("")
	own.search:ClearFocus()
	own.count.box:ClearFocus()
end

-- The module

local EVENTS = { "MERCHANT_UPDATE", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY",
	"QUEST_LOG_UPDATE", "GET_ITEM_INFO_RECEIVED" }

local function Hook()
	-- Blizzard updates its hidden cells whenever the vendor's data changes.
	hooksecurefunc("MerchantFrame_Update", function()
		if M.on then Stale() end
	end)
	MerchantFrame:HookScript("OnShow", function()
		if not (M.on and desk) then return end
		Shy.HUD.Update(own.box)
		Shop.Try(M, function()
			own.area:SetVerticalScroll(0)
			desk:Begin("npc")
		end)
		Refresh()
	end)
	MerchantFrame:HookScript("OnHide", EndVisit)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function(_, event)
		if event == "MERCHANT_CLOSED" then
			EndVisit()
		elseif M.on and MerchantFrame:IsShown() and (event ~= "GET_ITEM_INFO_RECEIVED" or visit.waiting) then
			Stale()
			-- ShyQuest reads the quest log a moment after it changes, so ask again once it has.
			if (event == "BAG_UPDATE_DELAYED" or event == "QUEST_LOG_UPDATE") and visit.orders and #visit.orders > 0 and not visit.again then
				visit.again = true
				C_Timer.After(L.lag, function()
					visit.again = nil
					if M.on and MerchantFrame:IsShown() then Stale() end
				end)
			end
		end
	end)
	-- ShyBags sells junk and repairs as the vendor opens, possibly before the window shows.
	Shy:On("SHY_BAGS_SOLD", function(copper)
		visit.sold = (visit.sold or 0) + (copper or 0)
		if M.on then Stale() end
	end)
	Shy:On("SHY_BAGS_REPAIRED", function(copper, byGuild)
		visit.repaired = (visit.repaired or 0) + (copper or 0)
		visit.byGuild = byGuild and true or nil
		if M.on then Stale() end
	end)
	-- ShyGear's word on something changed (an item it waited on, your gear, your level).
	Shy:On("SHY_GEAR", function()
		if M.on then Stale() end
	end)
	-- A sale going on (ShyBags), and the auction house's prices changing what is worth listing.
	Shy:On("SHY_BAGS_SALE", function()
		if M.on and MerchantFrame:IsShown() then Stale() end
	end)
	Shy:On("SHY_AUCTION", function(why)
		if (why == "scan" or why == "price") and M.on and MerchantFrame:IsShown() then Stale() end
	end)
end

local function Paint(m, kit)
	Shop.Try(m, function()
		if not desk then Build() end
		Shy.HUD.Update(own.box)
		Shop.Empty(kit, MerchantFrame, own.box)
		Refresh()
	end)
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	if desk then desk:Rest() end
	Shop.Refill(MerchantFrame)
	Shop.Unsize(MerchantFrame)
	if own.box then Shy.HUD.Update(own.box) end
end

M = ns.Module({
	id = "merchant",
	title = "Vendors",
	desc = "Vendors get a window you can resize, with repair and sell junk on top and upgrades marked.",
	group = "rebuilt",
	words = "merchant shop buy sell repair",
	Ready = function() return MerchantFrame ~= nil and Shop ~= nil and WIN ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,   -- exposed for inspection
})
