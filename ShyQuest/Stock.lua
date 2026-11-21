-- A vendor with none left of what a quest needs. Some things are sold a few at a time (a Bronze Tube: a
-- supplier keeps one or two, and other players buy them), and a quest waits on one.
--   The window: a row with none left, or no row at all (a list may grey what it has run out of, or drop it),
--     is the vendor having none, kept for the account for OUT_FOR; a row in stock ends that. Never for good:
--     a wrong "for a while" costs one more visit, a wrong "never" would be silent. A filtered list says
--     nothing of gear, which is all a filter hides.
--   The route: someone who is out is no place to buy it (GoalPlaces asks Stock.Out).
--   The choices: the card leads with what to do instead. A click on the row opens them (they are on its
--     right-click menu too), and its hover says what each comes to:
--       Auction house     the nearest auctioneer leads, with what ShyAuction's book says it goes for; its
--                         window opens on the item. Not offered to someone who doesn't use the auction
--                         house (the guide's setting), nor with no auctioneer on this continent.
--       Come back later   nothing more is said; the vendor is a place for it again after OUT_FOR. Following a
--                         guide, the quest's steps are set aside meanwhile (the rest of each step goes on) and
--                         the step that buys it is open again when you next pass the vendor after that.
--       Skip              the quest is set aside (R.Skip), and following a guide its steps with it.
--     Kept for the character (ns.char.stock: item -> { npc, at, quest, how, guide, index }), so a choice lasts
--     through a reload; whatever was chosen, having the item ends it.
-- Stock.Aside(quest): the step of the guide a quest was set aside at, for Guide.lua (Dropped).

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G, I = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide, ns.Index
local UI = Shy.UI

local Stock = {}
ns.Stock = Stock

T.defaults.sold = {}         -- [npc] = { [item] = time() their window last had none of it }
T.keep.sold = true           -- read from the game: per account, not per profile

Stock.OUT_FOR = 15 * 60      -- seconds a vendor who is out of something is left alone, as one out of potions is
local NEAR = 300             -- yards: this near the vendor again, what was put off for later is back

local function ItemName(id)
	return C_Item.GetItemNameByID(id) or D.Name("items", id) or "it"
end

-- Is this vendor no place for the item: their window had none of it not long ago.
function Stock.Out(npc, item)
	local seen = T.db and T.db.sold[npc]
	local at = seen and seen[item]
	return at ~= nil and time() - at < Stock.OUT_FOR
end

local function Records()
	if not ns.char then return nil end
	ns.char.stock = type(ns.char.stock) == "table" and ns.char.stock or {}
	return ns.char.stock
end

-- The step of the guide a quest was set aside at ("Come back later", "Skip"), or nil.
function Stock.Aside(quest)
	local records = ns.char and ns.char.stock
	if type(records) ~= "table" then return nil end
	for _, record in pairs(records) do
		if record.quest == quest and record.guide and (record.how == "later" or record.how == "skip") then return record.index or 0 end
	end
	return nil
end

-- The nearest friendly auctioneer on this continent: { npc, map, x, y, yards }, or nil.
local function Auctioneer()
	local best
	for _, id in ipairs(D.Town("auction")) do
		local npc = D.Npc(id)
		if npc and L.Friendly(npc) then
			local map, x, y, yards, dungeon = W.Nearest(npc.places)
			if map and yards and not dungeon and (not best or yards < best.yards) then
				best = { npc = npc, map = map, x = x, y = y, yards = yards }
			end
		end
	end
	return best
end

local function UsesAuctions()
	return not (T.db.guide and T.db.guide.selfFound)
end

-- The step of the guide being followed that works on a quest (the first of them): its guide's name and its
-- index, or nil off a guide or where the guide has none.
local function GuideStep(quest)
	local guide = ns.Following() and G.current
	if not guide then return nil end
	local asks = G.Asks(guide)
	local index = (asks.complete[quest] or {})[1] or (asks.collect[quest] or {})[1]
	if not index then return nil end
	return guide.name, index
end

-- Ends what was noted for an item. back: its quest is wanted after all (a wait that is up, a skip taken back),
-- so the guide's step that buys it is open again.
local function End(item, back)
	local records = Records()
	local record = records and records[item]
	if not record then return end
	records[item] = nil
	if record.how == "skip" and R.Aside(record.quest) then R.Include({ actions = { { id = record.quest } } }) end
	if back and record.index and G.current and G.current.name == record.guide then G.Reopen(record.index) end
	ns.Refresh()
end

-- What was chosen for an item: "auction", "later" or "skip".
local function Choose(item, how)
	local records = Records()
	local record = records and records[item]
	if not record then return end
	record.how = how
	record.guide, record.index = nil, nil
	if how == "later" or how == "skip" then
		-- (Following a guide, the quest's steps stand aside with it: Stock.Aside.)
		record.guide, record.index = GuideStep(record.quest)
	end
	if how == "skip" then
		R.Skip({ actions = { { id = record.quest } } })
		-- (Off the guide, setting the quest aside is all there is to it.)
		if not record.guide then records[item] = nil end
	end
	ns.Refresh()
end

-- Lets go of what is over: the item had or no longer wanted, a wait that is up, a skip taken back.
local function Tidy()
	local records = Records()
	if not records then return end
	local over = {}
	for item, record in pairs(records) do
		if record.how == "skip" then
			-- (Taken back: picked onto the route again, or included from its mark. Or the quest is gone.)
			if not L.Has(record.quest) then
				over[item] = false
			elseif not R.Aside(record.quest) then
				over[item] = true
			end
		elseif not T:Wanted(item) then
			over[item] = false
		elseif record.how == "later" and record.guide then
			-- Following a guide: back when you next pass the vendor, once they may have some again; let go with
			-- the guide it was put off in.
			local npc = D.Npc(record.npc)
			local _, _, _, yards = W.Nearest(npc and npc.places or {})
			if not G.current or G.current.name ~= record.guide then
				over[item] = false
			elseif not Stock.Out(record.npc, item) and yards ~= nil and yards <= NEAR then
				over[item] = true
			end
		elseif record.how ~= "auction" and not Stock.Out(record.npc, item) then
			over[item] = false
		end
	end
	for item, back in pairs(over) do End(item, back) end
end

-- The record the card speaks of: the one asked about first, else a trip to the auction house.
local function Pending()
	local records = Records()
	if not records then return nil end
	local ask, trip
	for item, record in pairs(records) do
		if record.how == nil and (not ask or record.at < records[ask].at) then ask = item end
		if record.how == "auction" and (not trip or record.at < records[trip].at) then trip = item end
	end
	local item = ask or trip
	return item, item and records[item]
end

local function QuestTitle(quest)
	local entry = L.entries[quest]
	return entry and entry.title or D.Name("quests", quest) or "your quest"
end

-- The choices for an item, in the order offered: { key, menu (the menu's words), act (the hover's), click }.
local function Choices(item, record, among)
	local list = {}
	local function Add(key, menu, act, how)
		if not among or among[key] then
			list[#list + 1] = { key = key, menu = menu, act = act, click = function() Choose(item, how) end }
		end
	end
	if UsesAuctions() and Auctioneer() then Add("auction", "Buy it at the auction house", "Auction house", "auction") end
	Add("later", "Come back later", "Come back later", "later")
	Add("skip", "Skip this quest", "Skip quest", "skip")
	return list
end

local function Menu(choices)
	return function(root)
		for _, choice in ipairs(choices) do root:CreateButton(choice.menu, choice.click) end
	end
end

-- What the price book says one goes for, as words, or nil (ShyAuction's, where it is on and has seen one).
local function Price(item)
	local auction = Shy.addons.Auction
	local price = auction and auction.Price and auction:Price(item)
	local copper = price and (price.market or price.unit)
	return copper and copper > 0 and ("About %s each"):format(UI.Money(copper, false, 11)) or nil
end

-- The choice itself, leading the card: nowhere to walk to.
local function Asking(item, record)
	local name, who = ItemName(item), D.Name("npcs", record.npc) or "The vendor"
	local choices = Choices(item, record)
	local words = #choices == 3 and "Auction house, come back later, or skip" or "Come back later, or skip"
	local at = #choices == 3 and Auctioneer() or nil
	return {
		title = ("%s: none left"):format(name),
		lines = { ("%s has none"):format(who), words },
		caption = "NONE LEFT  \194\183  YOUR CALL",
		first = true,
		hover = function()
			local rows = {}
			for _, choice in ipairs(choices) do
				local right
				if choice.key == "auction" then
					right = Price(item) or (at and W.Yards and W.Yards(at.yards)) or nil
				elseif choice.key == "later" then
					right = "In a while"
				else
					right = QuestTitle(record.quest)
				end
				rows[#rows + 1] = { glyph = choice.key == "auction" and "coin" or choice.key == "later" and "clock" or "note", text = choice.act,
					right = right, rightColor = UI.colors.dim }
			end
			return { { title = "What you can do", rows = rows } }
		end,
		tip = function(tip)
			tip:AddLine(("%s has no %s left."):format(who, name), 1, 1, 1, true)
		end,
		-- (A click on the row opens the choices where the pointer is.)
		click = function() UI.ContextMenu(UIParent, Menu(choices)) end,
		hint = "Choose",
		menuHint = words,
		menu = Menu(choices),
	}
end

-- The trip to the auction house, or nil where there is none to go to.
local function Trip(item, record)
	local at = Auctioneer()
	if not at or not UsesAuctions() then return nil end
	local name, quest = ItemName(item), QuestTitle(record.quest)
	local choices = Choices(item, record, { later = true, skip = true })
	local lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name }
	local price = Price(item)
	if price then lines[#lines + 1] = price end
	return {
		title = ("Auction house: %s"):format(name),
		lines = lines,
		caption = ("FOR %s  \194\183  BUY AT AUCTION"):format(quest:upper()),
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "buy",
		first = true,
		hover = function()
			return { { title = "To buy", rows = { { icon = C_Item.GetItemIconByID(item), glyph = "coin", text = name, right = Price(item),
				rightColor = UI.colors.dim } } } }
		end,
		tip = function(tip)
			tip:AddLine(name, 1, 1, 1)
		end,
		menuHint = "Later, or skip",
		menu = Menu(choices),
	}
end

local function Errand()
	Tidy()
	local item, record = Pending()
	if not item then return nil end
	if record.how == "auction" then
		local trip = Trip(item, record)
		if trip then return trip end
		-- (No auctioneer to go to after all: asked again.)
		record.how = nil
	end
	return Asking(item, record)
end

R.AddErrand("stock", Errand)

-- A vendor's window: what it shows of the things quests in the log are waiting on from them.
local function Talker()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	local kind, id = guid:match("^(%a+)%-.-%-.-%-.-%-.-%-(%d+)")
	return kind == "Creature" and tonumber(id) or nil
end

local function Read()
	local npc, count = Talker(), GetMerchantNumItems()
	if not npc or not ns.char then return end
	local left = {}      -- item -> how many are left (-1: as many as you like), for every row
	for index = 1, count do
		local id = GetMerchantItemID(index)
		local info = id and C_MerchantFrame.GetItemInfo(index)
		if info then left[id] = info.numAvailable or -1 end
	end
	local filtered = GetMerchantFilter() ~= LE_LOOT_FILTER_ALL
	local records, changed = Records(), false
	for _, tie in ipairs(I.Npc(npc) or {}) do
		local item = tie.kind == "sells" and not tie.done and tie.item and tie.item.id
		if item then
			local have = left[item]
			local seen = T.db.sold[npc]
			if have ~= nil and have ~= 0 then
				-- In stock: bought here after all.
				if seen and seen[item] ~= nil then
					seen[item] = nil
					if next(seen) == nil then T.db.sold[npc] = nil end
					changed = true
				end
				if records[item] and records[item].how ~= "skip" then
					End(item, records[item].how == "later")
					changed = true
				end
			elseif count > 0 and not (have == nil and filtered and C_Item.IsEquippableItem(item)) then
				-- None left, or no row for it. (Not gear missing from a filtered list: the filter hid it.)
				local was = Stock.Out(npc, item)
				seen = seen or {}
				T.db.sold[npc] = seen
				seen[item] = time()
				local record = records[item]
				if not record or record.how == "later" then
					if record then End(item) end
					records[item] = { npc = npc, at = time(), quest = tie.id }
					T:Print(("%s has no %s left. Your card says what you can do instead."):format(D.Name("npcs", npc) or "This vendor", ItemName(item)))
					changed = true
				end
				changed = changed or not was
			end
		end
	end
	if changed then ns.Refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:SetScript("OnEvent", Shy.Clocked("quest: vendor stock", Read))

-- At the auction house, its window opens on what the trip is for (ShyAuction's, where it is on).
Shy:On("SHY_AUCTION", function(why)
	if why ~= "shown" then return end
	local records = Records()
	local auction = Shy.addons.Auction
	if not (records and auction and auction.Find) then return end
	for item, record in pairs(records) do
		if record.how == "auction" and T:Wanted(item) then
			auction:Find(item)
			return
		end
	end
end)
