-- Sell: what's in your bags that the house takes, worth first (its market against the vendor's), and the listing of the
-- item picked: the price each (a copper under the cheapest, or what you type, or a row of the house's clicked), how
-- many (all of it, unless you say), for how long, the deposit, the house's cut, what you get, Post; and what is on the
-- house now. An auction can't be reposted in place: one cancelled or run out comes back by mail, and is posted again
-- from here once you have it.
-- How many goes up in as many posts as the game needs: one post takes what the game says it can from your biggest
-- stack (all of it, or that stack alone), so the rest goes up a press at a time, your biggest stacks first. The posts
-- are drawn as a strip, what is up filled in; each press posts the next, and Space posts while this page is up. What
-- went up is read from your bags, so the strip is right whatever the house took. Once all of an item is up, the next
-- in the list is picked.
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
local Theme = Shy.Theme
local Shop = Shy.Shop
local P = ns.Parts

local L = { list = 300, row = 34, rung = 22, ladder = 4, field = 70, price = 110, count = 150, rail = 6, gap = 2,
	segs = 24, digits = 18 }
local DURATION = { 1, 2, 3 }                      -- the game's three: 2, 8 and 24 hours here (AUCTION_DURATION_*)
local WAIT = 10                                   -- seconds a post waits for the house's answer
local BUSY = 3                                    -- seconds Post rests for a busy house that doesn't say it is ready
local LEAST = 100                                 -- the least a single item's buyout may be here (a silver)
local KEY = { key = "SPACE", button = "ShyAuctionPostKey", word = "Space" }
local WORDS = { busy = "The house is busy, a moment.", reading = "Reading the item, a moment.",
	posting = "Posting\226\128\166", anyway = "Post anyway",
	unanswered = "The house didn't answer that post. It answers nothing more until you log out and back in.",
	least = "This house doesn't answer a single item under 1 silver (and then stops answering until you log in again). Price it at 1 silver or more.",
	poor = "Not enough gold for the deposit.", moving = "Put down the stack you're moving first.", vendor = "A vendor pays more for these: %s." }
local STATUS = Enum.ItemCommodityStatus

local page, scroll, list, card
-- pick: the item picked; at: its place in the list (the next one slides into it once it's all up); count: how many
-- still to post (nil: all you have); run: the posts made of the item picked ({ item, done = { n a press }, last = how
-- many you had }); up: the last item all posted ({ item, n }); asked: an item whose search waits for the house;
-- posting: when a post was sent; kept: that post, should the house ask to be sure; sure: the house asked (Post
-- anyway); busy: since when the house has been busy; said: words under Post.
local state = { pick = nil, price = nil, typed = false, count = nil, duration = 3 }
local goods = {}
local plan = {}

-- Items the house took when last asked, so a stack you are moving (its slot locked, which the house refuses to look
-- at) still counts as yours. Forgotten as the house closes.
local sellable = {}

-- Posted from first: a stack you aren't moving, the biggest.
local function BySize(a, b)
	if a.locked ~= b.locked then return not a.locked end
	if a.count ~= b.count then return a.count > b.count end
	return a.n < b.n
end

-- What the house takes from your bags, an entry an item: { item, count, stacks (biggest first: { location, count }),
-- location (the biggest stack's), worth, unit, vendor }. Where your stacks stand in your bags changes nothing.
local function Read()
	wipe(goods)
	local by, n = {}, 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and not info.isBound and not issecretvalue(info.itemID) then
				local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
				local ok = sellable[info.itemID]
				if not info.isLocked then
					ok = C_AuctionHouse.IsSellItemValid(location, false)
					sellable[info.itemID] = ok or nil
				end
				if ok then
					local g = by[info.itemID]
					if not g then
						g = { item = info.itemID, count = 0, stacks = {} }
						by[info.itemID] = g
						goods[#goods + 1] = g
					end
					n = n + 1
					local count = info.stackCount or 1
					g.count = g.count + count
					g.stacks[#g.stacks + 1] = { location = location, count = count, n = n, locked = info.isLocked }
				end
			end
		end
	end
	for _, g in ipairs(goods) do
		table.sort(g.stacks, BySize)
		g.location = g.stacks[1].location
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
	-- What went up since the last press: what left your bags while it was sent (the house took it), counted to it.
	local run = state.run
	if run then
		local have = by[run.item] and by[run.item].count or 0
		if have < run.last and #run.done > 0 and run.sent and GetTime() - run.sent < WAIT + BUSY then
			local gone = run.last - have
			run.done[#run.done] = run.done[#run.done] + gone
			if state.count then state.count = state.count - gone end
			if state.count and state.count <= 0 then state.count = nil end
		end
		run.last = have
	end
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
	for i, g in ipairs(goods) do
		if g.item == state.pick then return g, i end
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
	-- (An item listing's buyout is the price each, however many it holds.)
	local key = C_AuctionHouse.MakeItemKey(item)
	n = C_AuctionHouse.GetNumItemSearchResults(key) or 0
	for i = 1, math.min(n, L.ladder) do
		local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
		if r and r.buyoutAmount and not issecretvalue(r.buyoutAmount) and (r.quantity or 0) > 0 then
			out[#out + 1] = { quantity = r.quantity, unit = r.buyoutAmount, mine = r.containsOwnerItem }
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
	state.pick, state.typed, state.price, state.count, state.run = item, false, nil, nil, nil
	ns.lastPick = item   -- (the Farm tab's For an item)
	state.sure, state.kept, state.said = nil, nil, nil
	-- Asked by the key of the very item in your bags, as the game's own sell window does.
	local g = Picked()
	local key = g and C_Item.DoesItemExist(g.location) and C_AuctionHouse.GetItemKeyFromItem(g.location)
	ns.Search(key or C_AuctionHouse.MakeItemKey(item))
	ns.Window.Stale()
end

-- An item right-clicked in your bags: Sell, with it picked (whatever was picked before).
function ns.SellItem(location)
	if not (location and location:IsValid() and C_Item.DoesItemExist(location)) then return end
	local item = C_Item.GetItemID(location)
	if not item or issecretvalue(item) then return end
	state.up = nil
	if item ~= state.pick then Pick(item) end
	ns.Window.Open("sell")
end

-- How many one post takes: what the game says can go from your biggest stack (all you hold, or that stack alone).
local function Each(g)
	local most = C_Item.DoesItemExist(g.location) and C_AuctionHouse.GetAvailablePostCount(g.location) or 0
	if most <= 0 then most = g.stacks[1].count end
	return math.max(1, math.min(g.count, most))
end

-- The posts that put want up, the next first: one, a stack a post (your biggest first), or as much as a post takes.
local function Plan(g, want)
	wipe(plan)
	local each = Each(g)
	if each >= want then
		plan[1] = want
	elseif each == g.stacks[1].count then
		for _, stack in ipairs(g.stacks) do
			if want <= 0 then break end
			plan[#plan + 1] = math.min(stack.count, want)
			want = want - plan[#plan]
		end
	else
		while want > 0 do
			plan[#plan + 1] = math.min(each, want)
			want = want - plan[#plan]
		end
	end
	return plan
end

local function Settled()
	state.posting, state.kept, state.sure = nil, nil, nil
end

-- From a press only (Post, or Space while the page is up).
local function Post()
	local g = Picked()
	if not (g and state.price) or state.posting or g.stacks[1].locked or Busy() then return end
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
	p.quantity = Plan(g, math.min(state.count or g.count, g.count))[1]
	-- What leaves your bags from here is counted to this press.
	local run = state.run
	if not (run and run.item == g.item) then
		run = { item = g.item, done = {}, last = g.count }
		state.run = run
	end
	run.done[#run.done + 1], run.sent = 0, GetTime()
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

-- The posts as a strip across the card: what is up filled with your color, the next lit, the rest waiting; each
-- one's count under it where there's room. Past L.segs posts the strip is one bar filled as far as is up.
local function DrawStrip(width, done, todo, sending)
	local strip = card.strip
	local up, left = 0, 0
	for _, n in ipairs(done) do up = up + n end
	for _, n in ipairs(todo) do left = left + n end
	local total = up + left
	local many = #done + #todo > L.segs
	local k, x = 0, 0
	local function Seg(n, kind)
		k = k + 1
		local s = strip.segs[k]
		if not s then
			s = { bar = strip:CreateTexture(nil, "ARTWORK"), word = Shop.Text(strip, UI.NameFont(10), C.dim) }
			s.bar:SetColorTexture(1, 1, 1, 1)
			s.bar:SetHeight(L.rail)
			strip.segs[k] = s
		end
		local wide = math.max(2, width * n / math.max(1, total))
		s.bar:ClearAllPoints()
		s.bar:SetPoint("TOPLEFT", x, 0)
		s.bar:SetWidth(math.max(1, wide - (many and 0 or L.gap)))
		if kind == "up" then UI.Paint(s.bar, Theme.Accent, 1)
		elseif kind == "next" then UI.Paint(s.bar, Theme.Accent, sending and 0.7 or 0.45)
		else UI.Paint(s.bar, C.border, 0.9) end
		s.bar:Show()
		s.word:ClearAllPoints()
		s.word:SetPoint("TOP", s.bar, "BOTTOM", 0, -3)
		s.word:SetText((not many and wide >= L.digits) and n or "")
		UI.Ink(s.word, kind == "up" and C.text or kind == "next" and C.hot or C.dim)
		s.word:Show()
		if kind == "next" then
			strip.lit:ClearAllPoints()
			strip.lit:SetPoint("TOPLEFT", s.bar, "BOTTOMLEFT", 0, -1)
			strip.lit:SetPoint("TOPRIGHT", s.bar, "BOTTOMRIGHT", 0, -1)
		end
		x = x + wide
	end
	if many then
		if up > 0 then Seg(up, "up") end
		if todo[1] then Seg(todo[1], "next") end
		if left - (todo[1] or 0) > 0 then Seg(left - todo[1], "wait") end
	else
		for _, n in ipairs(done) do if n > 0 then Seg(n, "up") end end
		for i, n in ipairs(todo) do Seg(n, i == 1 and "next" or "wait") end
	end
	strip.lit:SetShown(todo[1] ~= nil)
	for i = k + 1, #strip.segs do
		strip.segs[i].bar:Hide()
		strip.segs[i].word:Hide()
	end
	return up, left
end

local function DrawCard(width)
	local g, at = Picked()
	card:SetShown(g ~= nil)
	if not g then return end
	state.at = at
	local name, quality, icon = P.Name(g.item)
	card.icon:SetTexture(icon or 134400)
	card.slot:Quality(quality)
	card.name:SetText(name)
	local color = ITEM_QUALITY_COLORS[quality or 1]
	if color then card.name:SetTextColor(color.r, color.g, color.b) end
	card.have:SetText(#g.stacks > 1 and ("%d in your bags, in %d stacks"):format(g.count, #g.stacks) or ("%d in your bags"):format(g.count))

	local ladder = Cheapest(g.item)
	local exists = C_Item.DoesItemExist(g.location)
	local commodity = exists and C_AuctionHouse.GetItemCommodityStatus(g.location) == STATUS.Commodity
	local cheapest
	for _, rung in ipairs(ladder) do
		if not rung.mine then cheapest = rung.unit break end
	end
	local copper = C_AuctionHouse.SupportsCopperValues()
	local market = ns.Book.Price(g.item)
	card.market:SetText(market and ("Market %s each  |cffc8c8c8%s|r"):format(UI.Money(market.market, true, 11, card.market), ns.Book.Basis(market))
		or "No market price yet")
	-- A copper under the cheapest, unless you typed a price.
	if not state.typed then
		state.price = Fit(cheapest and math.max(1, cheapest - 1) or (market and market.market) or nil)
		if not card.price:HasFocus() then card.price:SetText(Typed(state.price)) end
	end
	local versus, tone = P.Versus(Fit(state.price), market and market.market)
	card.hint:SetText(state.typed and (versus ~= "" and versus or "your price")
		or cheapest and (copper and "a copper under the cheapest" or "just under the cheapest")
		or market and "the market" or "type a price")
	UI.Ink(card.hint, state.typed and tone or C.good)

	-- How many: all you have unless you say; the posts it takes drawn under it.
	local count = math.max(1, math.min(state.count or g.count, g.count))
	card.count:Set(count, 1, g.count, 1)
	local run = state.run and state.run.item == g.item and state.run or nil
	local done = run and run.done or {}
	-- (The press being sent shows as the next post until its count is read from your bags.)
	local last = done[#done]
	local sending = state.posting ~= nil
	if sending and last == 0 then done = { unpack(done, 1, #done - 1) } end
	local todo = Plan(g, count)
	local up = DrawStrip(width - L.field, done, todo, sending)
	local presses, went = #todo, 0
	for _, n in ipairs(done) do if n > 0 then went = went + 1 end end
	if up > 0 then
		card.posts:SetText(("%d up, %d to go%s"):format(up, count, presses > 1 and (" in %d posts"):format(presses) or ""))
	elseif presses > 1 then
		card.posts:SetText(("%d posts, one press each"):format(presses))
	else
		card.posts:SetText(count > 1 and ("all %d in one post"):format(count) or "")
	end
	card.duration:Select(state.duration)

	local location, duration = g.location, DURATION[state.duration]
	local deposit, first = 0, 0
	if exists then
		local function Deposit(n)
			return (commodity and C_AuctionHouse.CalculateCommodityDeposit(g.item, duration, n)
				or C_AuctionHouse.CalculateItemDeposit(location, duration, n)) or 0
		end
		deposit, first = Deposit(count), Deposit(todo[1])
	end
	local cut = ns.Book.Cut()
	local total = (Fit(state.price) or 0) * count
	local net = math.floor(total * (1 - cut))
	card.deposit:SetText(UI.Money(deposit, true, 10, card.deposit))
	card.cutWord:SetText(("The house keeps %d%%"):format(cut * 100))
	card.cut:SetText(UI.Money(math.floor(total * cut), true, 10, card.cut))
	card.netWord:SetText(count < g.count and ("You get for %d"):format(count) or "You get")
	card.net:SetText(UI.Money(net, true, 13, card.net))
	-- A post sent waits for the house's answer (or a while, should none come).
	if state.posting and GetTime() - state.posting > WAIT then
		-- No answer: the house holds that post, and answers nothing more until you log in again.
		Settled()
		state.said = WORDS.unanswered
	end
	local which = (went + presses > 1) and ("  \194\183  %d of %d"):format(went + 1, went + presses) or ""
	card.post:SetLabel(state.posting and WORDS.posting or state.sure and WORDS.anyway or ("Post %d%s"):format(todo[1], which))
	card.post:SetPrimary(true)
	local poor = GetMoney() < first
	local busy = not state.posting and Busy()
	local moving = g.stacks[1].locked
	local cheap = exists and not commodity and state.price ~= nil and Fit(state.price) < LEAST
	card.usable = state.price ~= nil and not poor and not state.posting and not busy and not cheap and not moving
	card.post:SetUsable(card.usable, (not state.price and "Type a price first.") or (poor and WORDS.poor) or (moving and WORDS.moving) or nil)
	card.post.key:SetShown(T.db.spacePosts == true and not state.posting)
	-- What a vendor pays, should it be more than the house would.
	local vendor = g.vendor * count
	local low = state.price and vendor > 0 and vendor >= net
	card.why:SetText(state.said or (cheap and WORDS.least) or (poor and state.price and WORDS.poor) or (busy and WORDS.busy) or (moving and WORDS.moving)
		or (low and WORDS.vendor:format(UI.Money(vendor, true, 10, card.why))) or "")
	UI.Ink(card.why, ((busy or moving) and not state.said) and C.dim or (low and not (state.said or cheap or poor)) and C.alert or C.bad)

	card.kick:Say("On the house now", #ladder == 0 and "nobody is selling it" or "click one to price under it")
	local top = 1
	for _, rung in ipairs(ladder) do top = math.max(top, rung.quantity) end
	for i = 1, L.ladder do
		local r, rung = card.rungs[i], ladder[i]
		r:SetShown(rung ~= nil)
		r.rung = rung
		if rung then
			r.bar:SetWidth(math.max(4, (width - 4) * rung.quantity / top))
			r.count:SetText(rung.quantity .. " \195\151" .. (rung.mine and "  |cff96beffyours|r" or ""))
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

-- Space posts while this page is up (out of a fight: the game refuses keys changed in one, and a fight takes it back).
local keys = CreateFrame("Frame")
local function Keys()
	if InCombatLockdown() or not card then return end
	local on = T.db.spacePosts == true and page:IsVisible()
	if on == keys.on then return end
	keys.on = on
	ClearOverrideBindings(keys)
	if on then SetOverrideBindingClick(keys, false, KEY.key, KEY.button) end
end
ns.SellKeys = Keys

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
	list = P.List(scroll, { height = L.row, spark = false, click = function(row)
		state.up = nil
		Pick(row.id)
	end })

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
	listing:SetPoint("TOPLEFT", 0, -56)
	listing:SetPoint("RIGHT")
	listing:Say("Your listing")
	Field(card, "Each", -78)
	card.price = CreateFrame("EditBox", nil, card)
	card.price:SetSize(L.price, 22)
	card.price:SetPoint("TOPLEFT", L.field, -78)
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
	Field(card, "How many", -106)
	card.count = Shop.Stepper(card, { width = L.count, height = 22, max = "All", onChange = function(n)
		state.count = n
		ns.Window.Stale()
	end })
	card.count:SetPoint("TOPLEFT", L.field, -106)
	card.posts = Shop.Text(card, UI.TextFont(10), C.dim)
	card.posts:SetPoint("TOPLEFT", L.field + L.count + 10, -112)
	card.posts:SetPoint("RIGHT")
	card.posts:SetJustifyH("LEFT")
	card.posts:SetWordWrap(false)
	card.strip = CreateFrame("Frame", nil, card)
	card.strip:SetPoint("TOPLEFT", L.field, -136)
	card.strip:SetPoint("RIGHT")
	card.strip:SetHeight(L.rail + 16)
	card.strip.segs = {}
	card.strip.lit = card.strip:CreateTexture(nil, "OVERLAY")
	card.strip.lit:SetHeight(1)
	card.strip.lit:SetColorTexture(1, 1, 1, 1)
	UI.Paint(card.strip.lit, C.hot, 0.9)
	Field(card, "For", -164)
	card.duration = UI.Segments(card, { AUCTION_DURATION_ONE, AUCTION_DURATION_TWO, AUCTION_DURATION_THREE }, function(i)
		state.duration = i
		ns.Window.Stale()
	end, { height = 22 })
	card.duration:SetPoint("TOPLEFT", L.field, -164)

	local y = -196
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
	card.net, card.netWord = Sum("You get", true)
	card.post = UI.Button(card, "Post", 160, function() Post() end)
	card.post:SetHeight(26)
	card.post:SetPoint("TOPLEFT", 0, y - 4)
	card.post:SetPoint("RIGHT")
	-- The key that posts too, said at the button's end.
	card.post.key = Shop.Text(card.post, UI.NameFont(9), C.dim)
	card.post.key:SetPoint("RIGHT", -10, 0)
	card.post.key:SetText(Shop.Upper(KEY.word))
	-- (What Space clicks: a button of ours with a name, as a key can only click one by its name.)
	local press = CreateFrame("Button", KEY.button, card)
	press:SetSize(1, 1)
	press:SetPoint("TOPLEFT")
	press:EnableMouse(false)
	press:SetScript("OnClick", function()
		if card.usable or state.sure then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			Post()
		end
	end)
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
		-- A row of the house's: clicked, your price a copper under it (or at it, where it's yours).
		local r = CreateFrame("Button", nil, card)
		r:SetHeight(L.rung)
		r:SetPoint("TOPLEFT", 0, y - 62 - (i - 1) * L.rung)
		r:SetPoint("RIGHT")
		r.bar = r:CreateTexture(nil, "BACKGROUND")
		r.bar:SetPoint("TOPLEFT", 0, -4)
		r.bar:SetPoint("BOTTOMLEFT", 0, 4)
		r.bar:SetColorTexture(1, 1, 1, 1)
		Theme.Tint(r.bar, Theme.Accent)
		r.bar:SetAlpha(0.22)
		r.hot = r:CreateTexture(nil, "BACKGROUND", nil, -1)
		r.hot:SetAllPoints()
		r.hot:SetColorTexture(1, 1, 1, 0.05)
		r.hot:Hide()
		r.count = Shop.Text(r, UI.NameFont(11), C.text)
		r.count:SetPoint("LEFT", 6, 0)
		r.money = Shop.Text(r, UI.NameFont(11), C.text)
		r.money:SetPoint("RIGHT", -6, 0)
		r:SetScript("OnEnter", function(self) self.hot:Show() end)
		r:SetScript("OnLeave", function(self) self.hot:Hide() end)
		r:SetScript("OnClick", function(self)
			local rung = self.rung
			if not rung then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			card.price:ClearFocus()
			state.price = Fit(rung.mine and rung.unit or math.max(1, rung.unit - 1))
			state.typed, state.said = true, nil
			card.price:SetText(Typed(state.price))
			ns.Window.Stale()
		end)
		card.rungs[i] = r
	end
	card:Hide()
	page:HookScript("OnShow", Keys)
	page:HookScript("OnHide", Keys)
end

local function Draw(frame, width, height)
	Read()
	-- All of the item picked is up: the next in the list (it slid into its place), and the list says what went up.
	local run = state.run
	if state.pick and not Picked() then
		if run and run.item == state.pick then
			local up = 0
			for _, n in ipairs(run.done) do up = up + n end
			state.up = up > 0 and { item = state.pick, n = up } or nil
		end
		local next = goods[math.min(state.at or 1, #goods)]
		state.pick = nil
		if next then Pick(next.item) end
	end
	if not state.pick and goods[1] then Pick(goods[1].item) end
	local up = state.up
	page.kick:Say("In your bags", up and ("all %d %s up"):format(up.n, (P.Name(up.item))) or "worth first", up and C.good or nil)
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
	Keys()
end

local function Count()
	return 0
end

ns.AddPage({ key = "sell", label = "Sell", order = 2, Build = Build, Draw = Draw, Count = Count })
-- (Exposed for inspection.)
ns.SellPage = { state = state, Parts = function() return list, card end, Post = Post }

local events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "AUCTION_HOUSE_AUCTION_CREATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
	"AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_POST_ERROR", "AUCTION_HOUSE_SHOW_ERROR",
	"AUCTION_MULTISELL_FAILURE", "AUCTION_HOUSE_CLOSED", "ITEM_LOCK_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	events:RegisterEvent(event)
end
-- The game's words with its line breaks as spaces.
local function Words(text) return type(text) == "string" and text:gsub("|n", " "):gsub("%s+", " ") or "" end
events:SetScript("OnEvent", Shy.Clocked("auction: sell", function(_, event, arg)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (Just before the lockdown: Space jumps again for the fight.)
		if keys.on then
			keys.on = false
			ClearOverrideBindings(keys)
		end
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		return Keys()
	elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
		state.said = nil
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
		if event == "AUCTION_HOUSE_CLOSED" then wipe(sellable) end
	end
	if ns.Window.Page() == "sell" then ns.Window.Stale() end
end))
