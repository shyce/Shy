-- Sell: what's in your bags that the auction house takes, as a queue that holds still for the visit, and the listing
-- of the item picked.
-- The price is picked for you. It's a copper under the cheapest listing, unless that's under your floor: a share of
-- the market (the setting), never less than a vendor pays. Then it's the market. Nobody selling it: the market. The
-- cheapest over twice the market: twice the market. The card says which and why, and draws them on one line: the
-- vendor, the floor, each listing, the market and your price. What you type, or a listing you click, wins.
-- The card waits for the auction house's listings before it prices anything, so the price is set once.
-- The list is the queue. Space (or Post) posts the next post of the item picked; once all of it is up, the next one
-- is picked. Skip moves on. Picked by the queue, an item a vendor pays more for (or with no price) is skipped by itself,
-- and its row says why. What went up keeps its row for the visit, so nothing below it moves.
-- How many goes up in as many posts as the game needs: one post takes what the game says it can from your biggest
-- stack (all of it, or that stack alone), so the rest goes up a press at a time, your biggest stacks first. The posts
-- are drawn as a strip, what is up filled in. What went up is read from your bags, so the strip is right whatever the
-- auction house took.
-- Post waits for the auction house's answer before the next can go. A post goes only from your press (the game allows it no
-- other way): while the auction house is busy Post rests and says so, ready again as soon as the auction house is (or after a few
-- seconds, should it not say). A search asked while it is busy is sent once it is ready. This auction house leaves a single
-- item (not a commodity) priced under a silver unanswered, and answers nothing more until you log in again: such a
-- post isn't sent, and the card says why. The auction house's warning is answered here (Post anyway) and its errors said
-- under Post: the game's own sell frames, hidden, can't answer for ours.
-- Your bags are read only when they change, and an item the auction house took once stays on the list for the visit.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors
local Theme = Shy.Theme
local Shop = Shy.Shop
local P = ns.Parts

-- rung: a listing's row; rungs: the most listings shown. skip: Skip's width. ceiling: the most you post at, in markets.
local L = { list = 300, row = 34, rung = 20, rungs = 12, field = 70, price = 110, count = 150, rail = 6, gap = 2,
	segs = 24, digits = 18, skip = 72, ceiling = 2, line = 14, swatch = 9 }
-- Where each line of the card stands, from its top.
local Y = { facts = -48, values = -61, rail = -84, each = -104, reason = -130, many = -148, strip = -174, ["for"] = -200,
	sums = -228, post = -260, why = -292, kick = -320, rungs = -340 }
local DURATION = { 1, 2, 3 }                      -- the game's three: 2, 8 and 24 hours here (AUCTION_DURATION_*)
local WAIT = 10                                   -- seconds a post waits for the auction house's answer
local BUSY = 3                                    -- seconds Post rests for a busy auction house that doesn't say it is ready
local SETTLE = 5                                  -- seconds the card waits for the listings before pricing without them
local LEAST = 100                                 -- the least a single item's buyout may be here (a silver)
local KEY = { key = "SPACE", button = "ShyAuctionPostKey", word = "Space" }
local WORDS = { busy = "The auction house is busy. One moment.", reading = "Reading the item. One moment.",
	posting = "Posting\226\128\166", anyway = "Post anyway",
	unanswered = "The auction house didn't answer that post. It won't answer again until you log out and back in.",
	least = "This auction house ignores a single item under 1 silver, then stops answering until you log in again. Price it at 1 silver or more.",
	poor = "Not enough gold for the deposit.", moving = "Put down the stack you're moving first.", vendor = "A vendor pays more for these: %s.",
	checking = "Checking the auction house\226\128\166",
	undercut = "A copper under the cheapest.", under = "Just under the cheapest.",
	floor = "They're %d%% under market. You'll post at market.",
	high = "The cheapest is over twice the market. You'll post at twice the market.",
	nobody = "Nobody's selling it. You'll post at market.",
	alone = "Only yours are up. You'll match your price.",
	none = "No price yet. Type one.",
	typed = "Your price.",
	-- What a skipped row says.
	skipped = { vendor = "vendor pays more", none = "no price yet", least = "under 1 silver", you = "skipped" } }
local STATUS = Enum.ItemCommodityStatus

local page, scroll, list, card
-- pick: the item picked; at: its place in the list; auto: picked by the queue (it may skip it); count: how many still
-- to post (nil: all you have); run: the posts made of the item picked ({ item, done = { n a press }, last = how many
-- you had }); up: the last item all posted ({ item, n }); asked, askedAt: the item whose listings this visit asked
-- for, and when; heard: item -> when its listings came; posted: item -> how many went up this visit; skipped: item ->
-- why; posting: when a post was sent; kept: that post, should the auction house ask to be sure; sure: the auction house
-- asked (Post anyway); busy: since when the auction house has been busy; said: words under Post.
local state = { pick = nil, price = nil, typed = false, count = nil, duration = 3, heard = {}, posted = {}, skipped = {} }
local goods = {}
local plan = {}
-- What needs doing again: bags read, the list laid. drawn: the size it was laid at.
local dirty = { bags = true, list = true }
local drawn = {}

-- Items the auction house took this visit. The game may say no for a moment (an item not loaded, a stack you are
-- moving), so one taken stays taken. Forgotten as the auction house closes.
local sellable = {}

-- The list holds still for the visit: each item's place (worth first, as the auction house opened or a whole scan
-- ended; what comes into your bags after, after them). item -> { rank, unit, vendor }; forgotten as the auction house
-- closes or a whole scan ends.
local held, ranks = {}, 0
local function Forget()
	wipe(held)
	ranks = 0
	dirty.bags = true
end

-- Posted from first: a stack you aren't moving, the biggest.
local function BySize(a, b)
	if a.locked ~= b.locked then return not a.locked end
	if a.count ~= b.count then return a.count > b.count end
	return a.n < b.n
end

local function ByRank(a, b) return held[a.item].rank < held[b.item].rank end

-- What the auction house takes from your bags, an entry an item: { item, count, stacks (biggest first: { location, count }),
-- location (the biggest stack's), worth, unit, vendor }; and what went up this visit, gone from your bags: { item,
-- gone = true }. Where your stacks stand in your bags changes nothing.
local function Read()
	dirty.bags, dirty.list = false, true
	wipe(goods)
	local by, n = {}, 0
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and not info.isBound and not issecretvalue(info.itemID) then
				local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
				local ok = sellable[info.itemID]
				if not ok and not info.isLocked then
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
	-- What went up since the last press: what left your bags while it was sent (the auction house took it), counted to it.
	local run = state.run
	if run then
		local have = by[run.item] and by[run.item].count or 0
		if have < run.last and #run.done > 0 and run.sent and GetTime() - run.sent < WAIT + BUSY then
			local gone = run.last - have
			run.done[#run.done] = run.done[#run.done] + gone
			state.posted[run.item] = (state.posted[run.item] or 0) + gone
			if state.count then state.count = state.count - gone end
			if state.count and state.count <= 0 then state.count = nil end
		end
		run.last = have
	end
	local new = {}
	for _, g in ipairs(goods) do
		table.sort(g.stacks, BySize)
		g.location = g.stacks[1].location
		local h = held[g.item]
		if not h then
			local price = ns.Book.Price(g.item)
			h = { unit = price and price.market }
			held[g.item] = h
			new[#new + 1] = g
		end
		-- (The vendor's price is kept once the game has it: an item not yet loaded says none at first.)
		if not h.vendor then
			local _, _, _, _, _, _, _, _, _, _, sell = C_Item.GetItemInfo(g.item)
			if sell then h.vendor = sell else C_Item.RequestLoadItemDataByID(g.item) end
		end
		g.unit, g.vendor = h.unit, h.vendor or 0
		g.worth = (g.unit or 0) * g.count
	end
	-- Newcomers take their places after the rest, worth first among themselves.
	table.sort(new, function(a, b)
		if (a.unit ~= nil) ~= (b.unit ~= nil) then return a.unit ~= nil end
		if a.worth ~= b.worth then return a.worth > b.worth end
		return a.item < b.item
	end)
	for _, g in ipairs(new) do
		ranks = ranks + 1
		held[g.item].rank = ranks
	end
	-- What went up stays in its place.
	for item in pairs(state.posted) do
		if not by[item] and held[item] and held[item].rank then
			goods[#goods + 1] = { item = item, count = 0, stacks = {}, gone = true, vendor = held[item].vendor or 0 }
		end
	end
	table.sort(goods, ByRank)
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

-- The item picked, still in your bags, and its place.
local function Picked()
	for i, g in ipairs(goods) do
		if g.item == state.pick and not g.gone then return g, i end
	end
end

-- The next in the queue from a place on: in your bags, not skipped, not the one picked.
local function Next(from)
	for i = math.max(1, from or 1), #goods do
		local g = goods[i]
		if not g.gone and not state.skipped[g.item] and g.item ~= state.pick then return g end
	end
end

-- What is listed of an item, cheapest first: the first few ({ quantity, unit, mine }), how many listings, how many items.
local function Listed(item)
	local out, total = {}, 0
	local n = C_AuctionHouse.GetNumCommoditySearchResults(item) or 0
	if n > 0 then
		for i = 1, n do
			local r = C_AuctionHouse.GetCommoditySearchResultInfo(item, i)
			if r and not issecretvalue(r.unitPrice) and not issecretvalue(r.quantity) then
				total = total + (r.quantity or 0)
				if #out < L.rungs then out[#out + 1] = { quantity = r.quantity, unit = r.unitPrice, mine = (r.numOwnerItems or 0) > 0 } end
			end
		end
		return out, n, total
	end
	-- (An item listing's buyout is the price each, however many it holds.)
	local key = C_AuctionHouse.MakeItemKey(item)
	n = C_AuctionHouse.GetNumItemSearchResults(key) or 0
	for i = 1, n do
		local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
		if r and r.buyoutAmount and not issecretvalue(r.buyoutAmount) and not issecretvalue(r.quantity) and (r.quantity or 0) > 0 then
			total = total + r.quantity
			if #out < L.rungs then out[#out + 1] = { quantity = r.quantity, unit = r.buyoutAmount, mine = r.containsOwnerItem } end
		end
	end
	return out, n, total
end

local function Ready() return C_AuctionHouse.IsThrottledMessageSystemReady() end

-- A price the auction house takes: whole silver at an auction house that takes no copper.
local function Fit(copper)
	if not copper or C_AuctionHouse.SupportsCopperValues() then return copper end
	return math.max(COPPER_PER_SILVER, math.floor(copper / COPPER_PER_SILVER) * COPPER_PER_SILVER)
end

-- How far a price is off the market, in a few words: "40% under", "12% over", or none near it.
local function Off(unit, market)
	if not (unit and market and market > 0) then return "", C.dim end
	local off = (unit - market) / market
	if math.abs(off) < 0.04 then return "", C.dim end
	if off < 0 then return ("%d%% under"):format(math.floor(-off * 100 + 0.5)), C.good end
	return ("%d%% over"):format(math.floor(off * 100 + 0.5)), C.bad
end

-- The listings of the item picked are in (or waited on long enough).
local function Heard(item)
	return state.heard[item] ~= nil or (state.asked == item and state.askedAt ~= nil and GetTime() - state.askedAt >= SETTLE)
end

-- The price for the item picked, and why: { price, why, tone, skip (why the queue passes it), cheapest, floor,
-- vendor (the least that beats a vendor, after the cut) }. trusted: the market is from more than one day (or from
-- other players' scans), so it may stand against what is listed now.
local decision = {}
local function Decide(g, ladder, market, cut, commodity, trusted)
	local d = decision
	d.price, d.why, d.tone, d.skip, d.cheapest, d.floor, d.vendor, d.mine = nil, nil, C.dim, nil, nil, nil, nil, nil
	for _, rung in ipairs(ladder) do
		if rung.mine then d.mine = d.mine or rung.unit elseif not d.cheapest then d.cheapest = rung.unit end
	end
	local vendor = g.vendor > 0 and math.ceil(g.vendor / (1 - cut)) or 0
	d.vendor = vendor > 0 and vendor or nil
	if trusted and market and market > 0 then
		d.floor = math.max(math.floor(market * (T.db.floor or 70) / 100), vendor)
	elseif vendor > 0 then
		d.floor = vendor
	end
	local copper = C_AuctionHouse.SupportsCopperValues()
	if state.typed then
		d.price, d.why = Fit(state.price), WORDS.typed
	elseif d.cheapest then
		local under = Fit(math.max(1, d.cheapest - 1))
		if d.floor and under < d.floor then
			if trusted and market and market > 0 and Fit(market) >= vendor then
				d.price, d.tone = Fit(market), C.alert
				d.why = WORDS.floor:format(math.floor((1 - d.cheapest / market) * 100 + 0.5))
			else
				d.price, d.why, d.tone = under, copper and WORDS.undercut or WORDS.under, C.good
			end
		elseif trusted and market and market > 0 and under > market * L.ceiling then
			d.price, d.why, d.tone = Fit(market * L.ceiling), WORDS.high, C.alert
		else
			d.price, d.why, d.tone = under, copper and WORDS.undercut or WORDS.under, C.good
		end
	elseif d.mine then
		d.price, d.why = Fit(d.mine), WORDS.alone
	elseif market and market > 0 then
		d.price, d.why = Fit(market), WORDS.nobody
	else
		d.why, d.skip = WORDS.none, WORDS.skipped.none
	end
	if d.price then
		if vendor > 0 and d.price < vendor then
			d.skip = WORDS.skipped.vendor
		elseif not commodity and d.price < LEAST then
			d.skip = WORDS.skipped.least
		end
	end
	return d
end

-- The auction house busy, and not yet waited on long enough: Post rests, and looks again once the auction house is ready.
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

-- What is listed of the item picked, sent once the auction house can take it: asked by the key of the very item in your bags,
-- as the game's own sell window does. Asked again each pick and each visit, as the auction house forgets it when it closes.
local function Ask()
	local g = Picked()
	local key = g and C_Item.DoesItemExist(g.location) and C_AuctionHouse.GetItemKeyFromItem(g.location)
	state.asked, state.askedAt = state.pick, GetTime()
	C_Timer.After(SETTLE, ns.Window.Stale)   -- priced without them, should none come
	ns.Search(key or C_AuctionHouse.MakeItemKey(state.pick))
end

-- auto: picked by the queue, which may pass it by. Picked by you, it isn't skipped.
local function Pick(item, auto)
	state.pick, state.typed, state.price, state.count, state.run, state.auto = item, false, nil, nil, nil, auto == true
	ns.lastPick = item   -- (the Farm tab's For an item)
	state.sure, state.kept, state.said = nil, nil, nil
	if not auto then state.skipped[item] = nil end
	dirty.list = true
	Ask()
	ns.Window.Stale()
end

-- Moves on from the item picked without posting it. The last of the queue stays picked, yours to post or leave:
-- passed by the queue, its row still says why.
local function Skip(why)
	if not state.pick then return end
	local _, at = Picked()
	local nxt = Next((at or state.at or 0) + 1)
	if not (nxt or why) then return end
	state.skipped[state.pick] = why or WORDS.skipped.you
	dirty.list = true
	if nxt then return Pick(nxt.item, true) end
	state.auto = false
	ns.Window.Stale()
end

-- An item right-clicked in your bags: Sell, with it picked (whatever was picked before).
function ns.SellItem(location)
	if not (location and location:IsValid() and C_Item.DoesItemExist(location)) then return end
	local item = C_Item.GetItemID(location)
	if not item or issecretvalue(item) then return end
	state.up = nil
	dirty.bags = true
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
		-- The auction house asked to be sure: the same post, confirmed.
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
	-- Kept first: the auction house may ask to be sure before the call returns.
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

-- The prices on one line: under your floor shaded, each listing a dot, the market a notch, your price a pin, the
-- vendor a tick.
local function DrawRail(width, d, market, ladder)
	local rail = card.rail
	local lo, hi = math.huge, 0
	local function Take(v) if v and v > 0 then lo, hi = math.min(lo, v), math.max(hi, v) end end
	Take(d.vendor)
	Take(d.floor)
	Take(market)
	Take(d.price)
	for _, rung in ipairs(ladder) do Take(rung.unit) end
	-- (A vendor alone makes no line worth reading.)
	if hi <= 0 or not (market or d.price or ladder[1]) then return rail:Hide() end
	rail:Show()
	lo, hi = lo * 0.85, hi * 1.08
	if hi - lo < 1 then hi = lo + 1 end
	local function X(v) return math.floor((v - lo) / (hi - lo) * width + 0.5) end
	local function At(mark, v)
		mark:SetShown(v ~= nil and v > 0)
		if v and v > 0 then
			mark:ClearAllPoints()
			mark:SetPoint("CENTER", rail, "LEFT", X(v), 0)
		end
	end
	rail.shade:SetShown(d.floor ~= nil)
	if d.floor then rail.shade:SetWidth(math.max(1, X(d.floor))) end
	for i = 1, L.rungs do
		local dot, rung = rail.dots[i], ladder[i]
		At(dot, rung and rung.unit)
		if rung then UI.Paint(dot, rung.mine and C.hot or C.dim, 1) end
	end
	At(rail.vendor, d.vendor)
	At(rail.market, market)
	At(rail.pin, d.price)
end

local function DrawCard(width, height)
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

	local exists = C_Item.DoesItemExist(g.location)
	local commodity = exists and C_AuctionHouse.GetItemCommodityStatus(g.location) == STATUS.Commodity
	local cut = ns.Book.Cut()
	local book = ns.Book.Price(g.item)
	local market = book and book.market
	local vendorEach = g.vendor > 0 and ("vendor %s"):format(UI.Money(g.vendor, true, 10, card.market)) or nil
	card.market:SetText(book and (vendorEach and ("%s  \194\183  %s"):format(ns.Book.Basis(book), vendorEach) or ns.Book.Basis(book))
		or (vendorEach and ("No market price yet  \194\183  %s"):format(vendorEach) or "No market price yet"))

	-- The price waits for the listings, then is set once.
	local heard = Heard(g.item)
	local ladder, listings, items
	if heard then ladder, listings, items = Listed(g.item) else ladder, listings, items = {}, 0, 0 end
	local trusted = book ~= nil and (book.shared or (book.days or 0) >= 2)
	local d = Decide(g, ladder, heard and market or nil, cut, commodity or not exists, trusted)
	if not heard then d.price, d.why, d.tone, d.skip = nil, WORDS.checking, C.dim, nil end
	if not state.typed then state.price = d.price end
	-- Picked by the queue, and nothing to post it at: passed by.
	if heard and state.auto and d.skip and not state.typed then return Skip(d.skip) end
	if not state.typed and not card.price:HasFocus() then
		local want = Typed(state.price)
		if card.price:GetText() ~= want then card.price:SetText(want) end
	end

	-- The three prices that decide it, and the line they stand on.
	local f = card.facts
	local column = math.floor(width / 3)
	if card.column ~= column then
		card.column = column
		for i, fact in ipairs(f) do
			fact.swatch:ClearAllPoints()
			fact.swatch:SetPoint("LEFT", card, "TOPLEFT", (i - 1) * column + 2, Y.facts - 6)
			fact.value:ClearAllPoints()
			fact.value:SetPoint("TOPLEFT", card, "TOPLEFT", (i - 1) * column, Y.values)
		end
	end
	f[1].value:SetText(heard and market and UI.Money(market, true, 13, f[1].value) or "")
	f[2].value:SetText(heard and (d.cheapest and UI.Money(d.cheapest, true, 13, f[2].value) or "nobody") or "")
	local off, tone = Off(d.cheapest, market)
	f[2].note:SetText(heard and off or "")
	UI.Ink(f[2].note, tone)
	f[3].value:SetText(state.price and UI.Money(Fit(state.price), true, 13, f[3].value) or "")
	off, tone = Off(Fit(state.price), market)
	f[3].note:SetText(off)
	UI.Ink(f[3].note, tone)
	if heard then DrawRail(width, d, market, ladder) else card.rail:Hide() end

	local versus, versusTone = P.Versus(Fit(state.price), market)
	card.hint:SetText(versus)
	UI.Ink(card.hint, versusTone)
	card.reason:SetText(d.why or "")
	UI.Ink(card.reason, d.tone or C.dim)

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
	card.strip:SetShown(up > 0 or #todo > 1)
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
	local total = (Fit(state.price) or 0) * count
	local net = math.floor(total * (1 - cut))
	card.deposit:SetText(UI.Money(deposit, true, 10, card.deposit))
	card.cutWord:SetText(("The auction house keeps %d%%"):format(cut * 100))
	card.cut:SetText(UI.Money(math.floor(total * cut), true, 10, card.cut))
	card.netWord:SetText(count < g.count and ("You get for %d"):format(count) or "You get")
	card.net:SetText(state.price and UI.Money(net, true, 13, card.net) or "")
	-- A post sent waits for the auction house's answer (or a while, should none come).
	if state.posting and GetTime() - state.posting > WAIT then
		-- No answer: the auction house holds that post, and answers nothing more until you log in again.
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
	card.usable = heard and state.price ~= nil and not poor and not state.posting and not busy and not cheap and not moving
	card.post:SetUsable(card.usable, (not heard and WORDS.checking) or (not state.price and "Type a price first.") or (poor and WORDS.poor) or (moving and WORDS.moving) or nil)
	card.post.key:SetShown(T.db.spacePosts == true and not state.posting)
	card.skip:SetUsable(not state.posting and Next((at or 0) + 1) ~= nil)
	-- What a vendor pays, should it be more than the auction house would.
	local vendor = g.vendor * count
	local low = state.price and vendor > 0 and vendor >= net
	card.why:SetText(state.said or (cheap and WORDS.least) or (poor and state.price and WORDS.poor) or (busy and WORDS.busy) or (moving and WORDS.moving)
		or (low and WORDS.vendor:format(UI.Money(vendor, true, 10, card.why))) or "")
	UI.Ink(card.why, ((busy or moving) and not state.said) and C.dim or (low and not (state.said or cheap or poor)) and C.alert or C.bad)

	card.kick:Say("On the auction house now", not heard and "" or listings == 0 and "nobody is selling it"
		or ("%d %s  \194\183  %d %s"):format(listings, listings == 1 and "listing" or "listings", items, items == 1 and "item" or "items"))
	card.kick.tail:SetText(heard and #ladder > 0 and "click one to price under it" or "")
	-- As many listings as there's room for.
	local room = math.max(1, math.min(L.rungs, math.floor((height + Y.rungs) / L.rung)))
	local top = 1
	for i = 1, math.min(room, #ladder) do top = math.max(top, ladder[i].quantity) end
	for i = 1, L.rungs do
		local r, rung = card.rungs[i], i <= room and ladder[i] or nil
		r:SetShown(rung ~= nil)
		r.rung = rung
		if rung then
			r.bar:SetWidth(math.max(4, (width - 4) * rung.quantity / top))
			r.count:SetText(rung.quantity .. " \195\151" .. (rung.mine and "  |cff96beffyours|r" or ""))
			r.money:SetText(UI.Money(rung.unit, true, 11, r.money))
			local word, wordTone = Off(rung.unit, market)
			r.off:SetText(word)
			UI.Ink(r.off, wordTone)
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

-- The three prices over the line, each with the mark it has on the line.
local function Facts()
	card.facts = {}
	local words = { "Market", "Lowest now", "You post" }
	for i = 1, 3 do
		local f = {}
		f.swatch = card:CreateTexture(nil, "ARTWORK")
		f.swatch:SetColorTexture(1, 1, 1, 1)
		f.label = Shop.Text(card, UI.NameFont(9), C.dim)
		f.label:SetText(Shop.Upper(words[i]))
		f.note = Shop.Text(card, UI.NameFont(9), C.dim)
		f.note:SetPoint("LEFT", f.label, "RIGHT", 5, 0)
		f.value = Shop.Text(card, UI.NameFont(13), C.text)
		f.label:SetPoint("LEFT", f.swatch, "RIGHT", 5, 0)
		card.facts[i] = f
	end
	local swatches = card.facts
	swatches[1].swatch:SetSize(2, L.swatch)
	UI.Paint(swatches[1].swatch, C.text, 1)
	swatches[2].swatch:SetSize(5, 5)
	UI.Paint(swatches[2].swatch, C.dim, 1)
	swatches[3].swatch:SetSize(3, L.swatch)
	UI.Paint(swatches[3].swatch, Theme.Accent, 1)
end

local function Rail()
	local rail = CreateFrame("Frame", nil, card)
	rail:SetPoint("TOPLEFT", 0, Y.rail)
	rail:SetPoint("RIGHT")
	rail:SetHeight(L.line)
	local function Mark(w, h, layer)
		local t = rail:CreateTexture(nil, layer or "ARTWORK")
		t:SetColorTexture(1, 1, 1, 1)
		t:SetSize(w, h)
		return t
	end
	rail.base = Mark(1, 2, "BORDER")
	rail.base:SetPoint("LEFT")
	rail.base:SetPoint("RIGHT")
	UI.Paint(rail.base, C.border, 0.9)
	rail.shade = Mark(1, L.rail, "BACKGROUND")
	rail.shade:SetPoint("LEFT")
	UI.Paint(rail.shade, C.bad, 0.22)
	rail.dots = {}
	for i = 1, L.rungs do rail.dots[i] = Mark(5, 5) end
	rail.vendor = Mark(1, 8)
	UI.Paint(rail.vendor, C.dim, 0.8)
	rail.market = Mark(2, 12, "OVERLAY")
	UI.Paint(rail.market, C.text, 1)
	rail.pin = Mark(3, L.line, "OVERLAY")
	UI.Paint(rail.pin, Theme.Accent, 1)
	rail:Hide()
	card.rail = rail
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
	list = P.List(scroll, { height = L.row, spark = false, click = function(row)
		local g = goods[row.index]
		if not g or g.gone then return end
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
	card.have = Shop.Text(card, UI.TextFont(10), C.dim)
	card.have:SetPoint("TOPRIGHT", 0, -4)
	card.have:SetJustifyH("RIGHT")
	card.name = Shop.Text(card, UI.TitleFont(16), C.text)
	card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -1)
	card.name:SetPoint("RIGHT", card.have, "LEFT", -8, 0)
	card.name:SetJustifyH("LEFT")
	card.name:SetWordWrap(false)
	card.market = Shop.Text(card, UI.TextFont(10), C.dim)
	card.market:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -5)

	Facts()
	Rail()

	Field(card, "Each", Y.each)
	card.price = CreateFrame("EditBox", nil, card)
	card.price:SetSize(L.price, 22)
	card.price:SetPoint("TOPLEFT", L.field, Y.each)
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
			state.price, state.typed, state.said, state.auto = copper, true, nil, false   -- (a new price: old words go)
			ns.Window.Stale()
		end
	end)
	card.hint = Shop.Text(card, UI.TextFont(10), C.dim)
	card.hint:SetPoint("LEFT", card.price, "RIGHT", 8, 0)
	-- Why the price is what it is.
	card.reason = Shop.Text(card, UI.TextFont(10), C.dim)
	card.reason:SetPoint("TOPLEFT", 0, Y.reason)
	card.reason:SetPoint("RIGHT")
	card.reason:SetJustifyH("LEFT")
	card.reason:SetWordWrap(false)

	Field(card, "How many", Y.many)
	card.count = Shop.Stepper(card, { width = L.count, height = 22, max = "All", onChange = function(n)
		state.count = n
		ns.Window.Stale()
	end })
	card.count:SetPoint("TOPLEFT", L.field, Y.many)
	card.posts = Shop.Text(card, UI.TextFont(10), C.dim)
	card.posts:SetPoint("TOPLEFT", L.field + L.count + 10, Y.many - 6)
	card.posts:SetPoint("RIGHT")
	card.posts:SetJustifyH("LEFT")
	card.posts:SetWordWrap(false)
	card.strip = CreateFrame("Frame", nil, card)
	card.strip:SetPoint("TOPLEFT", L.field, Y.strip)
	card.strip:SetPoint("RIGHT")
	card.strip:SetHeight(L.rail + 16)
	card.strip.segs = {}
	card.strip.lit = card.strip:CreateTexture(nil, "OVERLAY")
	card.strip.lit:SetHeight(1)
	card.strip.lit:SetColorTexture(1, 1, 1, 1)
	UI.Paint(card.strip.lit, C.hot, 0.9)
	Field(card, "For", Y["for"])
	card.duration = UI.Segments(card, { AUCTION_DURATION_ONE, AUCTION_DURATION_TWO, AUCTION_DURATION_THREE }, function(i)
		state.duration = i
		ns.Window.Stale()
	end, { height = 22 })
	card.duration:SetPoint("TOPLEFT", L.field, Y["for"])

	-- The money: the deposit and the cut on the left, what you get on the right.
	local depositWord = Shop.Text(card, UI.TextFont(10), C.dim)
	depositWord:SetPoint("TOPLEFT", 0, Y.sums)
	depositWord:SetText("Deposit, back when it sells")
	card.deposit = Shop.Text(card, UI.NameFont(10), C.text)
	card.deposit:SetPoint("LEFT", depositWord, "RIGHT", 6, 0)
	card.cutWord = Shop.Text(card, UI.TextFont(10), C.dim)
	card.cutWord:SetPoint("TOPLEFT", 0, Y.sums - L.line)
	card.cut = Shop.Text(card, UI.NameFont(10), C.text)
	card.cut:SetPoint("LEFT", card.cutWord, "RIGHT", 6, 0)
	card.netWord = Shop.Text(card, UI.TextFont(10), C.dim)
	card.netWord:SetPoint("TOPRIGHT", 0, Y.sums)
	card.netWord:SetJustifyH("RIGHT")
	card.net = Shop.Text(card, UI.NameFont(13), C.text)
	card.net:SetPoint("TOPRIGHT", card.netWord, "BOTTOMRIGHT", 0, -2)
	card.net:SetJustifyH("RIGHT")

	card.skip = UI.Button(card, "Skip", L.skip, function() Skip() end)
	card.skip:SetHeight(26)
	card.skip:SetPoint("TOPRIGHT", 0, Y.post)
	card.post = UI.Button(card, "Post", 160, function() Post() end)
	card.post:SetHeight(26)
	card.post:SetPoint("TOPLEFT", 0, Y.post)
	card.post:SetPoint("RIGHT", card.skip, "LEFT", -6, 0)
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
	-- Under Post: what holds it back, the auction house's warning or error. Its two lines are kept, said or not.
	card.why = Shop.Text(card, UI.TextFont(10), C.bad)
	card.why:SetPoint("TOPLEFT", 0, Y.why)
	card.why:SetPoint("RIGHT")
	card.why:SetJustifyH("LEFT")
	card.why:SetWordWrap(true)
	card.why:SetMaxLines(2)

	card.kick = Shop.Kicker(card)
	card.kick:SetPoint("TOPLEFT", 0, Y.kick)
	card.kick:SetPoint("RIGHT")
	card.kick.tail = Shop.Text(card.kick, UI.NameFont(10), C.dim)
	card.kick.tail:SetPoint("TOPRIGHT")
	card.kick.tail:SetJustifyH("RIGHT")
	card.rungs = {}
	for i = 1, L.rungs do
		-- A row of the auction house's: clicked, your price a copper under it (or at it, where it's yours).
		local r = CreateFrame("Button", nil, card)
		r:SetHeight(L.rung)
		r:SetPoint("TOPLEFT", 0, Y.rungs - (i - 1) * L.rung)
		r:SetPoint("RIGHT")
		r.bar = r:CreateTexture(nil, "BACKGROUND")
		r.bar:SetPoint("TOPLEFT", 0, -3)
		r.bar:SetPoint("BOTTOMLEFT", 0, 3)
		r.bar:SetColorTexture(1, 1, 1, 1)
		Theme.Tint(r.bar, Theme.Accent)
		r.bar:SetAlpha(0.22)
		r.hot = r:CreateTexture(nil, "BACKGROUND", nil, -1)
		r.hot:SetAllPoints()
		r.hot:SetColorTexture(1, 1, 1, 0.05)
		r.hot:Hide()
		r.count = Shop.Text(r, UI.NameFont(11), C.text)
		r.count:SetPoint("LEFT", 6, 0)
		r.off = Shop.Text(r, UI.NameFont(10), C.dim)
		r.off:SetPoint("RIGHT", -6, 0)
		r.off:SetJustifyH("RIGHT")
		r.money = Shop.Text(r, UI.NameFont(11), C.text)
		r.money:SetPoint("RIGHT", -76, 0)
		r.money:SetJustifyH("RIGHT")
		r:SetScript("OnEnter", function(self) self.hot:Show() end)
		r:SetScript("OnLeave", function(self) self.hot:Hide() end)
		r:SetScript("OnClick", function(self)
			local rung = self.rung
			if not rung then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			card.price:ClearFocus()
			state.price = Fit(rung.mine and rung.unit or math.max(1, rung.unit - 1))
			state.typed, state.said, state.auto = true, nil, false
			card.price:SetText(Typed(state.price))
			ns.Window.Stale()
		end)
		card.rungs[i] = r
	end
	card:Hide()
	page:HookScript("OnShow", Keys)
	page:HookScript("OnHide", Keys)
end

-- A row of the list: the market each (the card's own), and where the item stands in the queue.
local function Fill(row, i)
	local g = goods[i]
	row:Item(g.item, g.count)
	row:SetAlpha(g.gone and 0.55 or 1)
	local book = ns.Book.Price(g.item)
	local unit = book and book.market
	if g.count > 1 and unit then
		row:Say(("%s for all %d"):format(UI.Money(unit * g.count, true, 10, row.sub), g.count))
	elseif g.vendor > 0 then
		row:Say(("vendor %s"):format(UI.Money(g.vendor, true, 10, row.sub)))
	else
		row:Say("")
	end
	local posted, skipped = state.posted[g.item], state.skipped[g.item]
	if g.gone then
		row:Price(unit, ("all %d up"):format(posted or 0), C.good)
	elseif skipped then
		row:Price(unit, skipped, C.dim)
	elseif posted then
		row:Price(unit, ("%d up"):format(posted), C.good)
	elseif unit then
		local times = g.vendor > 0 and unit / g.vendor or nil
		row:Price(unit, times and times >= 1.5 and ("%.1f× the vendor"):format(times) or "near the vendor's price", times and times >= 1.5 and C.good or C.dim)
	else
		row:Price(nil, "no market price yet", C.dim)
	end
	row:Pick(state.pick == g.item)
end

local function Draw(frame, width, height)
	if dirty.bags then Read() end
	-- All of the item picked is up (or gone): the next in the queue, and the list says what went up.
	local run = state.run
	if state.pick and not Picked() then
		if run and run.item == state.pick then
			local up = 0
			for _, n in ipairs(run.done) do up = up + n end
			state.up = up > 0 and { item = state.pick, n = up } or nil
		end
		local nxt = Next(state.at or 1)
		state.pick = nil
		if nxt then Pick(nxt.item, true) end
	end
	if not state.pick then
		local first = Next(1)
		if first then
			Pick(first.item, true)
		else
			-- Everything skipped: the first still in your bags, yours to post.
			for _, g in ipairs(goods) do
				if not g.gone then
					Pick(g.item)
					break
				end
			end
		end
	end
	if state.pick and state.asked ~= state.pick then Ask() end
	local up, left = 0, 0
	for _, g in ipairs(goods) do
		if state.posted[g.item] then up = up + 1 end
		if not g.gone and not state.skipped[g.item] then left = left + 1 end
	end
	local done = state.up
	page.kick:Say("In your bags", done and ("all %d %s up"):format(done.n, (P.Name(done.item)))
		or up > 0 and ("%d up  \194\183  %d to go"):format(up, left) or "worth first", (done or up > 0) and C.good or nil)
	if dirty.list or drawn.w ~= width or drawn.h ~= height then
		dirty.list, drawn.w, drawn.h = false, width, height
		scroll.content:SetWidth(L.list - 14)
		list:Lay(#goods, Fill, height - 32)
		scroll:Update()
	end
	DrawCard(width - L.list - 10 - 14 - 12, height - 10)
	Keys()
end

local function Count()
	return 0
end

ns.AddPage({ key = "sell", label = "Sell", order = 2, Build = Build, Draw = Draw, Count = Count })
-- (Exposed for inspection.)
ns.SellPage = { state = state, Parts = function() return list, card end, Post = Post, Skip = Skip }
-- A whole scan read the prices afresh: the list is ranked by them again. A price seen: the rows show it.
Shy:On("SHY_AUCTION", function(why)
	if why == "scan" then Forget() end
	if why == "scan" or why == "price" then dirty.list = true end
end)

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
	elseif event == "BAG_UPDATE_DELAYED" or event == "ITEM_LOCK_CHANGED" then
		dirty.bags = true
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
		if type(arg) == "number" and not issecretvalue(arg) then state.heard[arg] = GetTime() end
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
		local item = type(arg) == "table" and arg.itemID
		if item and not issecretvalue(item) then state.heard[item] = GetTime() end
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
		if event == "AUCTION_HOUSE_CLOSED" then
			wipe(sellable)
			wipe(state.heard)
			wipe(state.posted)
			wipe(state.skipped)
			Forget()
			state.asked, state.askedAt = nil, nil
		end
	end
	if ns.Window.Page() == "sell" then ns.Window.Stale() end
end))
