-- Buy: the game's categories and a search at the left; the items in the middle, each its lowest price against the
-- market, how many are listed and the last scans as a line (with nothing asked for, the deals your scans found); the
-- item picked at the right: its trend, the cheapest listings, how many to buy, Buy, and where to farm it instead.
-- A commodity is bought by the count (the game quotes the price, then a second press pays it); an item by the listing.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors
local Shop = Shy.Shop
local P = ns.Parts

-- head: where the card's sections start, under the item's name, market and listings.
local L = { side = 160, gap = 10, card = 248, row = 34, rung = 22, ladder = 6, step = 8, head = 60 }

local page, side, search, cats, mid, scroll, list, head, card
local state = { find = "", cat = nil, open = nil, rows = {}, pick = nil, ladder = {}, count = 1, quote = nil }

-- The game's categories (its own table, read only), a level of them at a time; never the WoW Token's.
local cats_
local function Categories()
	if not cats_ and AuctionCategories then
		cats_ = {}
		for _, cat in ipairs(AuctionCategories) do
			if not (cat.HasFlag and cat:HasFlag("WOW_TOKEN_FLAG")) then cats_[#cats_ + 1] = cat end
		end
	end
	return cats_ or {}
end

-- The auction house answers one question at a time: one asked while it is busy waits (ns.WhenReady), the newest only.
local function Ask(query)
	ns.WhenReady("browse", function()
		ns.Note("SendBrowseQuery", query.searchString, #query.itemClassFilters)
		C_AuctionHouse.SendBrowseQuery(query)
		ns.Window.Stale()
	end)
end

-- wide: the same words over every category (the one picked found nothing).
local function Browse(wide)
	local cat = state.cat
	if state.find == "" and not cat then
		state.browsing, state.hits, state.wide = false, nil, nil
		return
	end
	state.browsing, state.wide = true, wide and true or nil
	if not wide then state.hits = nil end
	state.rows = {}
	Ask({ searchString = state.find, sorts = ns.SORTS.browse, minLevel = 0, maxLevel = 0, filters = {},
		itemClassFilters = (cat and not wide) and cat.filters or {} })
end

-- Which categories the results stand in: { [category] = how many }, a top category counting its own.
local function Hits(rows)
	local hits = {}
	local function Holds(cat, class, subclass)
		for _, f in ipairs(cat.filters or {}) do
			if f.classID == class and (f.subClassID == nil or f.subClassID == subclass) then return true end
		end
		return false
	end
	for _, r in ipairs(rows) do
		local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(r.item)
		if class then
			for _, cat in ipairs(Categories()) do
				if Holds(cat, class, subclass) then
					hits[cat] = (hits[cat] or 0) + 1
					for _, sub in ipairs(cat.subCategories or {}) do
						if Holds(sub, class, subclass) then hits[sub] = (hits[sub] or 0) + 1 end
					end
				end
			end
		end
	end
	return hits
end

-- What the middle shows: the browse results, or with nothing asked for, the deals.
local function Rows()
	if state.browsing then return state.rows end
	local out = {}
	for _, deal in ipairs(ns.Book.Deals(60)) do
		out[#out + 1] = { item = deal.item, unit = deal.unit, quantity = deal.quantity }
	end
	return out
end

local function Heard()
	if not state.browsing then return end
	local results = C_AuctionHouse.GetBrowseResults() or {}
	local rows = {}
	for _, r in ipairs(results) do
		local key = r.itemKey
		if key and not issecretvalue(key.itemID) then
			rows[#rows + 1] = { item = key.itemID, key = key, unit = r.minPrice, quantity = r.totalQuantity }
		end
	end
	state.rows = rows
	-- Words that found nothing in the category picked: asked again over every category, and those that hold
	-- something are lit (a click narrows to one, the words kept).
	if #rows == 0 and state.cat and state.find ~= "" and not state.wide and C_AuctionHouse.HasFullBrowseResults() then
		Browse(true)
		return
	end
	if state.wide then state.hits = Hits(rows) end
	ns.Window.Stale()
end

-- What is listed of the item picked, cheapest first: asked again each visit, as the auction house forgets it when it closes.
local function Search()
	state.asked = state.pick
	ns.Search(state.key)
end

local function Pick(item, key)
	state.pick, state.key, state.quote, state.ladder = item, key or C_AuctionHouse.MakeItemKey(item), nil, {}
	ns.lastPick = item   -- (the Farm tab's For an item)
	state.count = 1
	Search()
	ns.Window.Stale()
end

local function Ladder()
	local item, out = state.pick, {}
	if not item then return out end
	local n = C_AuctionHouse.GetNumCommoditySearchResults(item) or 0
	if n > 0 then
		state.commodity = true
		for i = 1, math.min(n, L.ladder) do
			local r = C_AuctionHouse.GetCommoditySearchResultInfo(item, i)
			if r and not issecretvalue(r.unitPrice) then
				out[#out + 1] = { quantity = r.quantity, unit = r.unitPrice, mine = (r.numOwnerItems or 0) > 0 }
			end
		end
		return out
	end
	state.commodity = false
	-- (An item listing's buyout is the price each, however many it holds.)
	n = C_AuctionHouse.GetNumItemSearchResults(state.key) or 0
	for i = 1, math.min(n, L.ladder) do
		local r = C_AuctionHouse.GetItemSearchResultInfo(state.key, i)
		if r and r.buyoutAmount and not issecretvalue(r.buyoutAmount) and (r.quantity or 0) > 0 then
			out[#out + 1] = { quantity = r.quantity, unit = r.buyoutAmount, buyout = r.buyoutAmount,
				auction = r.auctionID, mine = r.containsOwnerItem }
		end
	end
	return out
end

-- Buying.
local function Buy(rung)
	if state.commodity then
		if state.quote then
			ns.Note("ConfirmCommoditiesPurchase", state.pick, state.count)
			C_AuctionHouse.ConfirmCommoditiesPurchase(state.pick, state.count)
			state.quote = nil
		else
			ns.Note("StartCommoditiesPurchase", state.pick, state.count)
			C_AuctionHouse.StartCommoditiesPurchase(state.pick, state.count)
			state.asking = true
		end
	elseif rung and rung.auction then
		ns.Note("PlaceBid", rung.auction, rung.buyout)
		C_AuctionHouse.PlaceBid(rung.auction, rung.buyout)
	end
	ns.Window.Stale()
end

-- The left: the search and the categories. A category is a group head (the family's: a band, its fold on the rail);
-- the open one's own hang under it on the rail, a branch into each.
local HEAD = { height = 24, rail = 12, gutter = 26, fold = 14, branch = 22, sub = 20 }

local function Choose(cat)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if not cat.parent then state.open = state.open ~= cat and cat or nil end
	state.cat = state.cat ~= cat and cat or (cat.parent and cat or nil)
	state.hits = nil
	Browse()
	ns.Window.Stale()
end

local function Head(i)
	local h = cats.heads[i]
	if h then return h end
	h = UI.GroupHead(cats, { height = HEAD.height, rail = HEAD.rail, gutter = HEAD.gutter, right = 6, foldSize = HEAD.fold,
		branches = HEAD.branch, line = true,
		click = function(self, button)
			if button ~= "LeftButton" or not self.cat then return end
			Choose(self.cat)
		end })
	cats.heads[i] = h
	return h
end

local function CatRow(i)
	local row = cats.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, cats)
	row:SetHeight(HEAD.sub)
	P.Wash(row)
	row.text = Shop.Text(row, UI.NameFont(11), C.dim)
	row.text:SetPoint("LEFT", 6, 0)
	row.text:SetPoint("RIGHT", -6, 0)
	row:SetScript("OnEnter", function(self) self.hot:Show() end)
	row:SetScript("OnLeave", function(self) self.hot:Hide() end)
	row:SetScript("OnClick", function(self) Choose(self.cat) end)
	cats.rows[i] = row
	return row
end

local function DrawSide(height)
	local y, heads, subs = 0, 0, 0
	for _, cat in ipairs(Categories()) do
		heads = heads + 1
		local h = Head(heads)
		h.cat = cat
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", 0, -y)
		h:SetPoint("RIGHT")
		h:Set(cat.name or "")
		local open = state.open == cat or (state.hits and state.hits[cat] and state.open == nil)
		h:SetOpen(open)
		local hit = state.hits and state.hits[cat]
		h:SetAccent((state.cat == cat and C.hot) or (hit and C.good) or nil)
		h:SetBadges(hit and { { text = tostring(hit), color = C.good } } or {})
		h:Show()
		local top = y
		y = y + HEAD.height
		if open and cat.subCategories then
			local nodes = {}
			for _, sub in ipairs(cat.subCategories) do
				subs = subs + 1
				local row = CatRow(subs)
				row.cat = sub
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", HEAD.branch + 2, -y)
				row:SetPoint("RIGHT")
				local hit = state.hits and state.hits[sub]
				row.text:SetText((sub.name or "") .. (hit and ("  |cff66ffc7%d|r"):format(hit) or ""))
				UI.Ink(row.text, (state.cat == sub or hit) and C.text or C.dim)
				row:Pick(state.cat == sub)
				row:Show()
				nodes[#nodes + 1] = y - top + HEAD.sub / 2
				y = y + HEAD.sub
			end
			h:Hang(y - top - HEAD.height + 2, nodes)
			y = y + 4
		else
			h:Hang()
		end
		y = y + 2
	end
	for i = heads + 1, #cats.heads do cats.heads[i]:Hide() end
	for i = subs + 1, #cats.rows do cats.rows[i]:Hide() end
	cats:SetHeight(math.max(1, y))
end

-- The right: the item card.
local function DrawCard(width, height)
	local item = state.pick
	card:SetShown(item ~= nil)
	if not item then return end
	local name, quality, icon = P.Name(item, state.key)
	card.icon:SetTexture(icon or 134400)
	card.slot:Quality(quality)
	card.name:SetText(name)
	local color = ITEM_QUALITY_COLORS[quality or 1]
	if color then card.name:SetTextColor(color.r, color.g, color.b) end
	local price = ns.Book.Price(item)
	card.market:SetText(price and ("Market %s each"):format(UI.Money(price.market, true, 11, card.market)) or "No market price yet")
	card.listed:SetText(price and ("%s listed  ·  %s"):format(BreakUpLargeNumbers(price.quantity or 0), ns.Book.Basis(price)) or "")
	local h = ns.Book.History(item)
	card.kick1:Say("By day", h and #h >= 2 and (h[#h] <= math.min(unpack(h)) and ("the lowest in %d days"):format(#h) or ("%d days"):format(#h))
		or "scan on another day to see it")
	card.chart:Set(h, width - 4, 56, h and #h >= 2 and h[#h] < h[1] and C.good or C.hot)
	card.chart:SetShown(h ~= nil and #h >= 2)

	-- The cheapest listings.
	state.ladder = Ladder()
	card.kick2:Say("Cheapest", #state.ladder == 0 and "asking the auction house..." or "")
	local most = 1
	for _, rung in ipairs(state.ladder) do most = math.max(most, rung.quantity) end
	for i = 1, L.ladder do
		local r, rung = card.rungs[i], state.ladder[i]
		r:SetShown(rung ~= nil)
		if rung then
			r.rung = rung
			r.bar:SetWidth(math.max(4, (width - 4) * rung.quantity / most))
			r.count:SetText(rung.quantity .. " ×" .. (rung.mine and "  |cff96beffyours|r" or ""))
			r.money:SetText(UI.Money(rung.unit, true, 11, r.money))
			r.buy:SetShown(not state.commodity and not rung.mine)
		end
	end

	-- How many, and Buy (a commodity's quote is paid with a second press).
	local available = 0
	for _, rung in ipairs(state.ladder) do available = available + (rung.mine and 0 or rung.quantity) end
	card.stepper:SetShown(state.commodity)
	card.buy:SetShown(state.commodity)
	if state.commodity then
		card.stepper:Set(state.count, 1, math.max(1, available), 1)
		local total, left = 0, state.count
		for _, rung in ipairs(state.ladder) do
			if left <= 0 then break end
			if not rung.mine then
				local take = math.min(left, rung.quantity)
				total, left = total + take * rung.unit, left - take
			end
		end
		if state.quote then
			card.buy:SetLabel(("Pay %s"):format(UI.Money(state.quote, true, 12)))
			card.buy:SetPrimary(true)
		else
			card.buy:SetLabel(("Buy %d"):format(state.count))
			card.buy:SetPrimary(true)
		end
		card.buy:SetUsable(available > 0 and GetMoney() >= total, available == 0 and "Nobody is selling it." or "Not enough gold.")
		card.total:SetText(total > 0 and ("%s in all"):format(UI.Money(total, true, 10, card.total)) or "")
	else
		card.total:SetText("")
	end
	-- (Only for what creatures are a way to get: an herb they carry once in a blue moon has no farm.)
	local farm = Shy.addons.Farm
	card.farm:SetShown(farm ~= nil and farm.Farmable ~= nil and farm:Farmable(item))
end

local function Build(frame)
	page = frame
	side = CreateFrame("Frame", nil, page)
	side:SetPoint("TOPLEFT", 10, -4)
	side:SetPoint("BOTTOMLEFT", 10, 6)
	side:SetWidth(L.side)
	search = Shop.Search(side, "Search the auction house", function(text)
		state.find = text
		state.searchAt = GetTime()
		C_Timer.After(0.4, function()
			if state.searchAt and GetTime() - state.searchAt >= 0.39 then
				Browse()
				ns.Window.Stale()
			end
		end)
	end)
	search:SetPoint("TOPLEFT")
	search:SetPoint("RIGHT")
	local catScroll = UI.ScrollArea(side, L.side, 300, { quiet = true, smooth = true })
	catScroll:SetPoint("TOPLEFT", 0, -30)
	catScroll:SetPoint("BOTTOMRIGHT")
	cats = catScroll.content
	cats.rows, cats.heads = {}, {}
	side.scroll = catScroll

	mid = CreateFrame("Frame", nil, page)
	mid:SetPoint("TOPLEFT", side, "TOPRIGHT", L.gap, 0)
	mid:SetPoint("BOTTOM", 0, 6)
	head = Shop.Kicker(mid)
	head:SetPoint("TOPLEFT")
	head:SetPoint("RIGHT")
	scroll = UI.ScrollArea(mid, 300, 300, { quiet = true, smooth = true })
	scroll:SetPoint("TOPLEFT", 0, -22)
	scroll:SetPoint("BOTTOMRIGHT")
	list = P.List(scroll, { height = L.row, click = function(row) Pick(row.id, row.key) end })

	card = CreateFrame("Frame", nil, page)
	card:SetPoint("TOPRIGHT", -12, -4)
	card:SetPoint("BOTTOM", 0, 6)
	card:SetWidth(L.card)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(40, 40)
	card.icon:SetPoint("TOPLEFT")
	card.slot = Shy.Slot.New(card, { to = card.icon, icon = card.icon, size = 40, hover = false })
	card.name = Shop.Text(card, UI.TitleFont(16), C.text)
	card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -1)
	card.name:SetPoint("RIGHT")
	card.market = Shop.Text(card, UI.NameFont(11), C.text)
	card.market:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
	card.listed = Shop.Text(card, UI.TextFont(10), C.dim)
	card.listed:SetPoint("TOPLEFT", card.market, "BOTTOMLEFT", 0, -2)
	card.kick1 = Shop.Kicker(card)
	card.kick1:SetPoint("TOPLEFT", 0, -L.head)
	card.kick1:SetPoint("RIGHT")
	card.chart = P.Spark(card)
	card.chart:SetPoint("TOPLEFT", 2, -L.head - 22)
	card.kick2 = Shop.Kicker(card)
	card.kick2:SetPoint("TOPLEFT", 0, -L.head - 86)
	card.kick2:SetPoint("RIGHT")
	card.rungs = {}
	for i = 1, L.ladder do
		local r = CreateFrame("Frame", nil, card)
		r:SetHeight(L.rung)
		r:SetPoint("TOPLEFT", 0, -L.head - 106 - (i - 1) * L.rung)
		r:SetPoint("RIGHT")
		r.bar = r:CreateTexture(nil, "BACKGROUND")
		r.bar:SetPoint("TOPLEFT", 0, -4)
		r.bar:SetPoint("BOTTOMLEFT", 0, 4)
		r.bar:SetColorTexture(1, 1, 1, 1)
		Shy.Theme.Tint(r.bar, Shy.Theme.Accent)
		r.bar:SetAlpha(0.22)
		r.count = Shop.Text(r, UI.NameFont(11), C.text)
		r.count:SetPoint("LEFT", 6, 0)
		r.money = Shop.Text(r, UI.NameFont(11), C.text)
		r.money:SetPoint("RIGHT", -52, 0)
		r.buy = Shop.Button(r, "accent", function(b) Buy(b:GetParent().rung) end)
		r.buy:Say("Buy")
		r.buy:SetPoint("RIGHT", 0, 0)
		card.rungs[i] = r
	end
	card.stepper = Shop.Stepper(card, { height = 24, max = "Max", onChange = function(n)
		state.count, state.quote = n, nil
		ns.Window.Stale()
	end })
	card.stepper:SetPoint("TOPLEFT", 0, -L.head - 116 - L.ladder * L.rung)
	-- (Buy takes what the card has left beside the count.)
	card.buy = UI.Button(card, "Buy", L.card - card.stepper:GetWidth() - L.step, function() Buy() end)
	card.buy:SetHeight(24)
	card.buy:SetPoint("LEFT", card.stepper, "RIGHT", L.step, 0)
	card.total = Shop.Text(card, UI.TextFont(10), C.dim)
	card.total:SetPoint("TOP", card.buy, "BOTTOM", 0, -3)
	card.farm = UI.Button(card, "Where to farm it", 140, function() ns.FarmPage.For(state.pick) end)
	card.farm:SetHeight(22)
	card.farm:SetPoint("BOTTOMLEFT", 0, 0)
	card.farm:SetPoint("RIGHT")
	card:Hide()
end

local function Draw(frame, width, height)
	local midWidth = math.max(200, width - 10 - L.side - L.gap - L.gap - L.card - 12)
	mid:SetWidth(midWidth)
	DrawSide(height)
	local rows = Rows()
	-- (The first row is picked as the page fills: the item card always has something to say.)
	if rows[1] then
		local found = false
		for _, r in ipairs(rows) do
			if r.item == state.pick then found = true break end
		end
		if not found then Pick(rows[1].item, rows[1].key) end
	end
	if state.pick and state.asked ~= state.pick then Search() end
	local found
	if state.wide then
		found = #rows > 0 and ("nothing in %s: %d found elsewhere, lit at the left"):format(state.cat and state.cat.name or "it", #rows)
			or ("nothing anywhere for \"%s\""):format(state.find)
	elseif ns.Waiting("browse") then
		found = "asking the auction house..."
	else
		found = ("%d found"):format(#rows)
	end
	head:Say(state.browsing and "Items" or "Deals now", state.browsing and found
		or (#rows > 0 and "under the market on your last scan" or "scan the auction house to find them"))
	scroll.content:SetWidth(midWidth - 14)
	list:Lay(#rows, function(row, i)
		local r = rows[i]
		row:Item(r.item, nil, r.key)
		local price = ns.Book.Price(r.item)
		local word, color = P.Versus(r.unit, price and price.market)
		row:Say(("%s listed"):format(BreakUpLargeNumbers(r.quantity or 0)))
		row:Price(r.unit, word, color)
		local h = ns.Book.History(r.item)
		row:Trend(h, h and #h >= 2 and (h[#h] < h[1] and C.good or h[#h] > h[1] and C.bad or C.hot) or C.hot)
		row:Pick(state.pick == r.item)
	end, height - 28)
	scroll:Update()
	DrawCard(L.card, height)
end

ns.AddPage({ key = "buy", label = "Buy", order = 1, Build = Build, Draw = Draw })
-- (Exposed for inspection.)
-- Pick: the item card on an item asked for from outside (T:Find).
ns.BuyPage = { state = state, Parts = function() return list, card, search end, Browse = function() Browse() end,
	Pick = function(item) Pick(item) end }

-- What the auction house says.
local events = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "COMMODITY_SEARCH_RESULTS_UPDATED",
	"ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_PRICE_UPDATED", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
	"AUCTION_HOUSE_CLOSED", "PLAYER_MONEY", "ITEM_KEY_ITEM_INFO_RECEIVED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", Shy.Clocked("auction: buy", function(_, event, ...)
	if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		Heard()
	elseif event == "COMMODITY_PRICE_UPDATED" then
		local unit, total = ...
		if state.asking and not issecretvalue(total) then
			state.asking, state.quote = nil, total
		end
		ns.Window.Stale()
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" or event == "COMMODITY_PURCHASE_FAILED" then
		state.quote, state.asking = nil, nil
		if state.pick then Search() end
		ns.Window.Stale()
	elseif event == "AUCTION_HOUSE_CLOSED" then
		state.quote, state.asking, state.asked = nil, nil, nil
	else
		ns.Window.Stale()
	end
end))
