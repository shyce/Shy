-- Sell: what's in your bags that the house takes, worth first (its market against the vendor's), and the listing of the
-- item picked: the price each (a copper under the cheapest, or what you type), how many, for how long, the deposit, the
-- house's cut, what you get, Post; and what is on the house now. An auction can't be reposted in place: one cancelled
-- or run out comes back by mail, and is posted again from here once you have it.
-- Post waits for the house's answer before the next can go. A post goes only from your press (the game allows it no
-- other way): while the house is busy Post rests and says so, ready again as soon as the house is (or after a few
-- seconds, should it not say). A search asked while it is busy is sent once it is ready. This house leaves a single
-- item (not a commodity) priced under a silver unanswered, and answers nothing more until you log in again: such a
-- post isn't sent, and the card says why. The house's warning is answered here (Post anyway) and its errors said
-- under Post: the game's own sell frames, hidden, can't answer for ours.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors
local Shop = Shy.Shop
local P = ns.Parts

local L = { list = 300, row = 34, card = 330, rung = 22, ladder = 4 }
local DURATION = { 1, 2, 3 }                      -- the game's three: 2, 8 and 24 hours here (AUCTION_DURATION_*)
local WAIT = 10                                   -- seconds a post waits for the house's answer
local BUSY = 3                                    -- seconds Post rests for a busy house that doesn't say it is ready
local LEAST = 100                                 -- the least a single item's buyout may be here (a silver)
local WORDS = { busy = "The house is busy, a moment.", reading = "Reading the item, a moment.",
	posting = "Posting\226\128\166", anyway = "Post anyway",
	unanswered = "The house didn't answer that post. It answers nothing more until you log out and back in.",
	least = "This house doesn't answer a single item under 1 silver (and then stops answering until you log in again). Price it at 1 silver or more." }
local STATUS = Enum.ItemCommodityStatus

local page, scroll, list, card
-- asked: an item whose search waits for the house; posting: when a post was sent; kept: that post, should the house ask
-- to be sure; sure: the house asked (Post anyway); busy: since when the house has been busy; said: words under Post.
local state = { pick = nil, price = nil, typed = false, count = 1, duration = 3 }
local goods = {}

-- What the house takes from your bags, an entry an item: { item, count, location (its first stack), worth, unit }.
local function Read()
	wipe(goods)
	local by = {}
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and not info.isBound and not issecretvalue(info.itemID) then
				local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
				if C_AuctionHouse.IsSellItemValid(location, false) then
					local g = by[info.itemID]
					if not g then
						g = { item = info.itemID, count = 0, location = location, stack = info.stackCount or 1 }
						by[info.itemID] = g
						goods[#goods + 1] = g
					end
					g.count = g.count + (info.stackCount or 1)
				end
			end
		end
	end
	for _, g in ipairs(goods) do
		local price = ns.Book.Price(g.item)
		g.unit = price and price.market
		local _, _, _, _, _, _, _, _, _, _, sell = C_Item.GetItemInfo(g.item)
		g.vendor = sell or 0
		g.worth = (g.unit or 0) * g.count
	end
	table.sort(goods, function(a, b)
		if (a.unit ~= nil) ~= (b.unit ~= nil) then return a.unit ~= nil end
		if a.worth ~= b.worth then return a.worth > b.worth end
		return a.item < b.item
	end)
end

-- A price the way you'd type it: "1g 17s 5c".
local function Typed(copper)
	if not copper then return "" end
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

local function Picked()
	for _, g in ipairs(goods) do
		if g.item == state.pick then return g end
	end
end

local function Cheapest(item)
	local n = C_AuctionHouse.GetNumCommoditySearchResults(item) or 0
	local out = {}
	if n > 0 then
		for i = 1, math.min(n, L.ladder) do
			local r = C_AuctionHouse.GetCommoditySearchResultInfo(item, i)
			if r and not issecretvalue(r.unitPrice) then out[#out + 1] = { quantity = r.quantity, unit = r.unitPrice, mine = (r.numOwnerItems or 0) > 0 } end
		end
		return out, true
	end
	local key = C_AuctionHouse.MakeItemKey(item)
	n = C_AuctionHouse.GetNumItemSearchResults(key) or 0
	for i = 1, math.min(n, L.ladder) do
		local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
		if r and r.buyoutAmount and not issecretvalue(r.buyoutAmount) and (r.quantity or 0) > 0 then
			out[#out + 1] = { quantity = r.quantity, unit = math.floor(r.buyoutAmount / r.quantity + 0.5), mine = r.containsOwnerItem }
		end
	end
	return out, false
end

local function Ready() return C_AuctionHouse.IsThrottledMessageSystemReady() end

-- A price the house takes: whole silver at a house that takes no copper.
local function Fit(copper)
	if not copper or C_AuctionHouse.SupportsCopperValues() then return copper end
	return math.max(COPPER_PER_SILVER, math.floor(copper / COPPER_PER_SILVER) * COPPER_PER_SILVER)
end

-- The house busy, and not yet waited on long enough: Post rests, and looks again once the house is ready.
local function Busy()
	if Ready() then
		state.busy = nil
		return false
	end
	if not state.busy then
		state.busy = GetTime()
		C_Timer.After(BUSY, ns.Window.Stale)   -- drawn again once waited on long enough
	end
	if GetTime() - state.busy >= BUSY then return false end
	ns.OnReady("sell", ns.Window.Stale)
	return true
end

-- The search for the item picked, sent once the house can take it.
local function Pick(item)
	state.pick, state.typed, state.price, state.count = item, false, nil, nil
	ns.lastPick = item   -- (the Farm tab's For an item)
	state.sure, state.kept, state.said = nil, nil, nil
	-- Asked by the key of the very item in your bags, as the game's own sell window does.
	local g = Picked()
	local key = g and C_Item.DoesItemExist(g.location) and C_AuctionHouse.GetItemKeyFromItem(g.location)
	ns.Search(key or C_AuctionHouse.MakeItemKey(item))
	ns.Window.Stale()
end

-- The most one post can take: a commodity all you hold, an item as many as the game lets go in one go (each its own
-- auction).
local function Most(g, commodity)
	if commodity then return g.count end
	return math.max(1, C_AuctionHouse.GetAvailablePostCount(g.location) or 1)
end

local function Settled()
	state.posting, state.kept, state.sure = nil, nil, nil
end

-- From the press on Post only.
local function Post()
	local g = Picked()
	if not (g and state.price) or state.posting or Busy() then return end
	if state.sure then
		-- The house asked to be sure: the same post, confirmed.
		local p = state.sure
		state.sure, state.said, state.posting = nil, nil, GetTime()
		ns.Note("ConfirmPost", p.location, p.duration, p.quantity, p.unit)
		if p.commodity then
			C_AuctionHouse.ConfirmPostCommodity(p.location, p.duration, p.quantity, p.unit)
		else
			C_AuctionHouse.ConfirmPostItem(p.location, p.duration, p.quantity, nil, p.unit)
		end
		C_Timer.After(WAIT, ns.Window.Stale)
		return ns.Window.Stale()
	end
	local location = g.location
	if not C_Item.DoesItemExist(location) then return ns.Window.Stale() end
	local status = C_AuctionHouse.GetItemCommodityStatus(location)
	if status ~= STATUS.Item and status ~= STATUS.Commodity then
		state.said = WORDS.reading
		C_Item.RequestLoadItemDataByID(g.item)
		return ns.Window.Stale()
	end
	local p = { location = location, duration = DURATION[state.duration], unit = Fit(state.price), commodity = status == STATUS.Commodity }
	if not p.commodity and p.unit < LEAST then
		state.said = WORDS.least
		return ns.Window.Stale()
	end
	p.quantity = math.max(1, math.min(state.count, Most(g, p.commodity)))
	-- Kept first: the house may ask to be sure before the call returns.
	state.kept, state.posting, state.said = p, GetTime(), nil
	local asks
	if p.commodity then
		asks = C_AuctionHouse.PostCommodity(location, p.duration, p.quantity, p.unit)
	else
		asks = C_AuctionHouse.PostItem(location, p.duration, p.quantity, nil, p.unit)
	end
	ns.Note(p.commodity and "PostCommodity" or "PostItem", location, p.duration, p.quantity, p.unit, asks)
	if not asks and not state.sure then state.kept = nil end
	C_Timer.After(WAIT, ns.Window.Stale)
	ns.Window.Stale()
end

local function DrawCard(width)
	local g = Picked()
	card:SetShown(g ~= nil)
	if not g then return end
	local name, quality, icon = P.Name(g.item)
	card.icon:SetTexture(icon or 134400)
	card.slot:Quality(quality)
	card.name:SetText(name)
	local color = ITEM_QUALITY_COLORS[quality or 1]
	if color then card.name:SetTextColor(color.r, color.g, color.b) end
	card.have:SetText(("%d in your bags"):format(g.count))

	local ladder = Cheapest(g.item)
	local exists = C_Item.DoesItemExist(g.location)
	local commodity = exists and C_AuctionHouse.GetItemCommodityStatus(g.location) == STATUS.Commodity
	local cheapest
	for _, rung in ipairs(ladder) do
		if not rung.mine then cheapest = rung.unit break end
	end
	local copper = C_AuctionHouse.SupportsCopperValues()
	local market = ns.Book.Price(g.item)
	card.market:SetText(market and ("Market %s each"):format(UI.Money(market.market, true, 11, card.market)) or "No market price yet")
	-- A copper under the cheapest, unless you typed a price.
	if not state.typed then
		state.price = Fit(cheapest and math.max(1, cheapest - 1) or (market and market.market) or nil)
		if not card.price:HasFocus() then card.price:SetText(Typed(state.price)) end
	end
	card.hint:SetText(state.typed and "your price" or cheapest and (copper and "a copper under the cheapest" or "just under the cheapest")
		or market and "the market" or "type a price")

	local most = exists and Most(g, commodity) or 1
	state.count = math.max(1, math.min(state.count or most, most))
	card.count:Set(state.count, 1, most, 1)
	card.duration:Select(state.duration)

	local location, duration = g.location, DURATION[state.duration]
	local deposit = 0
	if C_Item.DoesItemExist(location) then
		deposit = (commodity and C_AuctionHouse.CalculateCommodityDeposit(g.item, duration, state.count)
			or C_AuctionHouse.CalculateItemDeposit(location, duration, state.count)) or 0
	end
	local cut = ns.Book.Cut()
	local total = (Fit(state.price) or 0) * state.count
	card.deposit:SetText(UI.Money(deposit, true, 10, card.deposit))
	card.cutWord:SetText(("The house keeps %d%%"):format(cut * 100))
	card.cut:SetText(UI.Money(math.floor(total * cut), true, 10, card.cut))
	card.net:SetText(UI.Money(math.floor(total * (1 - cut)), true, 13, card.net))
	-- A post sent waits for the house's answer (or a while, should none come).
	if state.posting and GetTime() - state.posting > WAIT then
		-- No answer: the house holds that post, and answers nothing more until you log in again.
		Settled()
		state.said = WORDS.unanswered
	end
	card.post:SetLabel(state.posting and WORDS.posting or state.sure and WORDS.anyway or ("Post %d"):format(state.count))
	card.post:SetPrimary(true)
	local poor = GetMoney() < deposit
	local busy = not state.posting and Busy()
	local cheap = exists and not commodity and state.price ~= nil and Fit(state.price) < LEAST
	card.post:SetUsable(state.price ~= nil and not poor and not state.posting and not busy and not cheap,
		(not state.price and "Type a price first.") or (poor and "Not enough gold for the deposit.") or nil)
	card.why:SetText(state.said or (cheap and WORDS.least) or (poor and state.price and "Not enough gold for the deposit.") or (busy and WORDS.busy) or "")
	UI.Ink(card.why, (busy and not state.said) and C.dim or C.bad)

	card.kick:Say("On the house now", #ladder == 0 and "nobody is selling it" or "")
	local top = 1
	for _, rung in ipairs(ladder) do top = math.max(top, rung.quantity) end
	for i = 1, L.ladder do
		local r, rung = card.rungs[i], ladder[i]
		r:SetShown(rung ~= nil)
		if rung then
			r.bar:SetWidth(math.max(4, (width - 4) * rung.quantity / top))
			r.count:SetText(rung.quantity .. " ×" .. (rung.mine and "  |cff96beffyours|r" or ""))
			r.money:SetText(UI.Money(rung.unit, true, 11, r.money))
		end
	end
end

local function Field(parent, label, y)
	local word = Shop.Text(parent, UI.TextFont(10), C.dim)
	word:SetPoint("TOPLEFT", 0, y - 6)
	word:SetText(label)
	return word
end

local function Build(frame)
	page = frame
	local kick = Shop.Kicker(page)
	kick:SetPoint("TOPLEFT", 10, -4)
	kick:SetWidth(L.list)
	kick:Say("In your bags", "worth first")
	page.kick = kick
	scroll = UI.ScrollArea(page, L.list, 300, { quiet = true, smooth = true })
	scroll:SetPoint("TOPLEFT", 10, -26)
	scroll:SetPoint("BOTTOMLEFT", 10, 6)
	list = P.List(scroll, { height = L.row, spark = false, click = function(row) Pick(row.id) end })

	card = CreateFrame("Frame", nil, page)
	card:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 14, 22)
	card:SetPoint("BOTTOMRIGHT", -12, 6)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(40, 40)
	card.icon:SetPoint("TOPLEFT")
	card.slot = Shy.Slot.New(card, { to = card.icon, icon = card.icon, size = 40, hover = false })
	card.name = Shop.Text(card, UI.TitleFont(16), C.text)
	card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -1)
	card.market = Shop.Text(card, UI.NameFont(11), C.text)
	card.market:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
	card.have = Shop.Text(card, UI.TextFont(10), C.dim)
	card.have:SetPoint("TOPLEFT", card.market, "BOTTOMLEFT", 0, -2)

	local listing = Shop.Kicker(card)
	listing:SetPoint("TOPLEFT", 0, -52)
	listing:SetPoint("RIGHT")
	listing:Say("Your listing")
	Field(card, "Each", -72)
	card.price = CreateFrame("EditBox", nil, card)
	card.price:SetSize(110, 22)
	card.price:SetPoint("TOPLEFT", 70, -72)
	card.price:SetAutoFocus(false)
	card.price:SetFontObject(UI.NameFont(12))
	card.price:SetTextInsets(6, 6, 0, 0)
	UI.Skin(card.price, C.bg, C.border)
	card.price:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	card.price:SetScript("OnEscapePressed", function(self)
		state.typed = false
		self:ClearFocus()
		ns.Window.Stale()
	end)
	card.price:SetScript("OnTextChanged", function(self, typed)
		if not typed then return end
		local copper = UI.ParseMoney(self:GetText())
		if copper and copper > 0 then
			state.price, state.typed, state.said = copper, true, nil   -- (a new price: old words go)
			ns.Window.Stale()
		end
	end)
	card.hint = Shop.Text(card, UI.TextFont(10), C.good)
	card.hint:SetPoint("LEFT", card.price, "RIGHT", 8, 0)
	Field(card, "How many", -100)
	card.count = Shop.Stepper(card, { width = 110, height = 22, max = "All", onChange = function(n)
		state.count = n
		ns.Window.Stale()
	end })
	card.count:SetPoint("TOPLEFT", 70, -100)
	Field(card, "For", -128)
	card.duration = UI.Segments(card, { AUCTION_DURATION_ONE, AUCTION_DURATION_TWO, AUCTION_DURATION_THREE }, function(i)
		state.duration = i
		ns.Window.Stale()
	end, { height = 22 })
	card.duration:SetPoint("TOPLEFT", 70, -128)

	local y = -160
	local function Sum(word, big)
		local left = Shop.Text(card, big and UI.NameFont(12) or UI.TextFont(10), big and C.text or C.dim)
		left:SetPoint("TOPLEFT", 0, y)
		left:SetText(word)
		local right = Shop.Text(card, big and UI.NameFont(13) or UI.NameFont(10), C.text)
		right:SetPoint("TOPRIGHT", 0, y)
		right:SetJustifyH("RIGHT")
		y = y - (big and 22 or 16)
		return right, left
	end
	card.deposit = Sum("Deposit, back when it sells")
	card.cut, card.cutWord = Sum("The house keeps 5%")
	card.net = Sum("You get", true)
	card.post = UI.Button(card, "Post", 160, function() Post() end)
	card.post:SetHeight(26)
	card.post:SetPoint("TOPLEFT", 0, y - 4)
	card.post:SetPoint("RIGHT")
	-- Under Post: what holds it back, the house's warning or error.
	card.why = Shop.Text(card, UI.TextFont(10), C.bad)
	card.why:SetPoint("TOPLEFT", 0, y - 36)
	card.why:SetPoint("RIGHT")
	card.why:SetWordWrap(true)
	card.why:SetMaxLines(2)
	y = y - 14

	card.kick = Shop.Kicker(card)
	card.kick:SetPoint("TOPLEFT", 0, y - 42)
	card.kick:SetPoint("RIGHT")
	card.rungs = {}
	for i = 1, L.ladder do
		local r = CreateFrame("Frame", nil, card)
		r:SetHeight(L.rung)
		r:SetPoint("TOPLEFT", 0, y - 62 - (i - 1) * L.rung)
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
		r.money:SetPoint("RIGHT", -6, 0)
		card.rungs[i] = r
	end
	card:Hide()
end

local function Draw(frame, width, height)
	Read()
	if not state.pick and goods[1] then Pick(goods[1].item) end
	scroll.content:SetWidth(L.list - 14)
	list:Lay(#goods, function(row, i)
		local g = goods[i]
		row:Item(g.item, g.count)
		if g.unit then
			row:Say(("%s for all %d"):format(UI.Money(g.worth, true, 10, row.sub), g.count))
			local times = g.vendor > 0 and g.unit / g.vendor or nil
			row:Price(g.unit, times and times >= 1.5 and ("%.1f× the vendor"):format(times) or "near the vendor's price", times and times >= 1.5 and C.good or C.dim)
		else
			row:Say(g.vendor > 0 and ("vendor %s each"):format(UI.Money(g.vendor, true, 10, row.sub)) or "")
			row:Price(nil, "no market price yet", C.dim)
		end
		row:Pick(state.pick == g.item)
	end, height - 32)
	scroll:Update()
	DrawCard(width - L.list - 10 - 14 - 12)
end

local function Count()
	return 0
end

ns.AddPage({ key = "sell", label = "Sell", order = 2, Build = Build, Draw = Draw, Count = Count })
-- (Exposed for inspection.)
ns.SellPage = { state = state, Parts = function() return list, card end }

local events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "AUCTION_HOUSE_AUCTION_CREATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
	"AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_POST_ERROR", "AUCTION_HOUSE_SHOW_ERROR",
	"AUCTION_MULTISELL_FAILURE", "AUCTION_HOUSE_CLOSED" }) do
	events:RegisterEvent(event)
end
-- The game's words with its line breaks as spaces.
local function Words(text) return type(text) == "string" and text:gsub("|n", " "):gsub("%s+", " ") or "" end
events:SetScript("OnEvent", Shy.Clocked("auction: sell", function(_, event, arg)
	if event == "AUCTION_HOUSE_AUCTION_CREATED" then
		state.typed, state.said = false, nil
		Settled()
		PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN)
	elseif event == "AUCTION_HOUSE_POST_WARNING" then
		-- Ours to answer: the game's dialog can only confirm its own frames' posts.
		if state.kept then
			StaticPopup_Hide("AUCTION_HOUSE_POST_WARNING")
			state.sure, state.kept, state.posting = state.kept, nil, nil
			state.said = Words(CONFIRM_AUCTION_POSTING_TEXT)
		end
	elseif event == "AUCTION_HOUSE_POST_ERROR" then
		Settled()
		state.said = Words(AUCTION_POSTING_ERROR_TEXT)
	elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
		if state.posting then
			Settled()
			local util = rawget(_G, "AuctionHouseUtil")
			state.said = util and Words(util.GetErrorText(arg)) or nil
		end
	elseif event == "AUCTION_MULTISELL_FAILURE" or event == "AUCTION_HOUSE_CLOSED" then
		Settled()
	end
	if ns.Window.Page() == "sell" then ns.Window.Stale() end
end))
