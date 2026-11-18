-- The piece as a Shy.HUD box: shown while a session goes on (and in layout mode, at a made-up session), its menus,
-- hovers and clicks, the question of a price answered, and what it says when you have all you wanted or stop.
-- ShyDock gives it the top left's corner, how to play under it; T:Piece() is its size for the screen ShyDock plans
-- and the setup draws. What it farms (Session.lua's S.Farmed: everything, a creature, an item) is found with
-- ShyQuest's finder (Card.Find) and led to as one place on your route (ShyQuest's FarmAt), its ground the farm's key.

local ADDON, ns = ...
local T, S, P, A, Card = ns.T, ns.Session, ns.Prices, ns.Auction, ns.Card
local UI, HUD = Shy.UI, Shy.HUD
local C = UI.colors
local K = Card.K

local box, card, ticker
local lastValue, lastCoin   -- what the session was worth at the last paint (a rise lights the figures)
local sources = {}          -- [item] = { at, list }: where it comes from, ShyQuest's answer, kept a while
local SOURCES_FOR = 10      -- seconds such an answer is kept

local function Session() return S.Current() end
local function Sampling() return HUD.IsUnlocked() and Session() == nil end
-- (Closed by its ×, it is away for the rest of that session, which goes on counting, starting or pausing by
-- itself; only you bring it back.)
-- Not in a raid: the raid's frames have the top left's corner then, and you aren't farming.
local function Shown()
	local s = Session()
	return (T.db.on and s ~= nil and not IsInRaid()) or Sampling()
end

-- Where an item comes from, nearest first (ShyQuest's data), or nil without it.
local function Sources(item)
	local quest = Shy.addons.Quest
	if not (quest and quest.ItemSources) then return nil end
	local kept = sources[item]
	if kept and GetTime() - kept.at < SOURCES_FOR then return kept.list end
	local list = quest:ItemSources(item)
	sources[item] = { at = GetTime(), list = list }
	return list
end

-- Where to farm: the heart of the best camp you can farm (ShyQuest's FarmSpot: its spawns, how often they drop it,
-- the walk there over the ground, your level; no vendors, guards, or elites while a plain one drops it), for as many
-- as you still want; a creature's own camps when you farm one. It weighs every camp and asks the ground for the walk
-- to the cheapest, so it is worked out when what you farm or how many are left changes, when asked to lead (fresh),
-- and otherwise at most every SPOT_FOR seconds. nil without ShyQuest, with nothing picked, or nowhere to go.
local spots, SPOT_FOR = {}, 15
local FarmSpot = Shy.Clocked("farm: where to farm it", function(quest, item, left, npc) return quest:FarmSpot(item, left, npc) end)

-- Where to farm when none of it is on your continent (FarmSpot weighs only there): a creature's thickest camp, an
-- item's nearest place it drops or is gathered. The way there, a boat or a flight, is ShyWay's to lead.
local function Elsewhere(quest, target)
	if target.npc and quest.CampsOf then
		local camp = quest:CampsOf(target.npc)[1]
		if camp then return { map = camp.map, x = camp.x, y = camp.y, name = target.name, id = target.npc } end
	elseif target.item and quest.ItemSources then
		for _, source in ipairs(quest:ItemSources(target.item) or {}) do
			if source.kind ~= "vendor" and source.map then
				return { map = source.map, x = source.x, y = source.y, name = source.name, id = source.id }
			end
		end
	end
	return nil
end
local function Spot(target, fresh)
	local quest = Shy.addons.Quest
	if not (quest and quest.FarmSpot and target and target.key) then return nil end
	local s = Session()
	local want = s and s.want
	local item = target.item
	local left = item and want and want.item == item and want.goal and math.max(1, want.goal - C_Item.GetItemCount(item, false)) or nil
	local kept = spots[target.key]
	if kept and not fresh and kept.left == left and kept.item == item and GetTime() - kept.at < SPOT_FOR then return kept.spot end
	local spot = FarmSpot(quest, item, left, target.npc) or Elsewhere(quest, target)
	spots[target.key] = { at = GetTime(), spot = spot, left = left, item = item }
	return spot
end

-- Room left in your bags: { free, total } of the bags anything goes in (ShyBags' count, else the game's; a
-- profession's bag holds only its own kind, so it is left out), or nil where it can't be told.
local function Room()
	local bags = Shy.addons.Bags
	if bags and bags.Room then
		local free, total = bags:Room()
		if free then return { free = free, total = total } end
	end
	if not (C_Container and C_Container.GetContainerNumFreeSlots) then return nil end
	local free, total = 0, 0
	for bag = 0, NUM_BAG_SLOTS do
		local open, family = C_Container.GetContainerNumFreeSlots(bag)
		if (family == nil or family == 0) and not issecretvalue(open) then
			free = free + (open or 0)
			total = total + (C_Container.GetContainerNumSlots(bag) or 0)
		end
	end
	return { free = free, total = total }
end

local function View()
	local s = Session()
	if not s then return Card.SAMPLE end
	local view = Card.View(s)
	view.room = Room()
	if view.target.kind ~= "any" then
		local spot = Spot(view.target)
		if view.want and spot and not view.want.odds and not view.want.from then view.want.from = spot.name end
		view.tools.go = spot ~= nil
	end
	return view
end

-- The rows the box is planned at, at the most: the setting's.
local function Most() return T.db.rows end

-- Planned as tall as what it holds (no fewer than K.LEAST rows, no more than Most): it grows down as loot comes.
local function Plan(view)
	if not box then return end
	view = view or View()
	local rows = math.max(K.LEAST, math.min(#view.rows, Most()))
	HUD.Made(box, K.WIDTH, Card.Height(view, rows))
end

local function Paint()
	if not card then return end
	HUD.Update(box)
	if not box:IsShown() then return end
	local view = View()
	Plan(view)
	card:Fill(view)
	-- The worth went up: the figures light, and the row it came in.
	local s = Session()
	if s then
		local value = view.value
		if lastValue and value > lastValue then card:Light(s.coin ~= lastCoin and "coin" or ns.lastLoot) end
		lastValue, lastCoin = value, s.coin
	else
		lastValue, lastCoin = nil, nil
	end
end
Paint = Shy.Clocked("farm: the window drawn", Paint)
Card.Paint = Paint

local Answered   -- the band's Start or Not now (below)

-- Finding what to farm (ShyQuest's finder, on its farm side): whether it can, and opening it as a picker that farms
-- what you pick and shuts.
function Card.CanFind()
	local quest = Shy.addons.Quest
	return quest ~= nil and quest.FindFarm ~= nil
end

function Card.Find()
	if not Card.CanFind() then return false end
	Shy.addons.Quest:FindFarm({ close = true })
	return true
end

-- Prices

-- The question of a price, answered: check the auction house (now, or when you next open it, and the way there),
-- type your own, or go by the vendor's.
function Card.Answer(key)
	if key == "start" or key == "later" then return Answered(key) end
	local s = Session()
	local item = s and s.want and s.want.item
	if not item then return end
	if key == "auction" then
		if A.IsOpen() then
			A.Check({ item })
			return
		end
		A.Remind(item)
		local quest = Shy.addons.Quest
		local place = quest and quest.Nearest and quest:Nearest("auction")
		if place and quest:Go(place.map, place.x, place.y, place.name) then
			T:Print("the way to the nearest auctioneer is on your map. Its price is checked as you open the auction house.")
		else
			T:Print("its price is checked as you next open the auction house.")
		end
		Paint()
	elseif key == "own" then
		card.typing = item
		Paint()
		card.ask.input.box:SetFocus()
	elseif key == "vendor" then
		P.Use(item, "vendor")
	end
end

-- Money as chat can take it: "4g 23s 10c", no coins' pictures.
local function Coins(copper)
	copper = math.floor(copper + 0.5)
	local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

-- A finished session as a line for chat: "Farmed Westfall for 31 min: 4g 23s (8g 14s an hour), 38 kills. Best:
-- 17 Stringy Wolf Meat."
local function ShareLine(a)
	local where = a.map and C_Map.GetMapInfo(a.map)
	local minutes = math.max(1, math.floor(a.seconds / 60 + 0.5))
	local hour = a.seconds >= 60 and (" (" .. Coins(a.value * 3600 / a.seconds) .. " an hour)") or ""
	local count = a.kind == "fishing" and a.catches and a.catches > 0 and (", " .. a.catches .. " fish")
		or a.kills and a.kills > 0 and (", " .. a.kills .. " kills") or ""
	local best = a.best and C_Item.GetItemNameByID(a.best.item)
	return ("%s %s for %d min: %s%s%s.%s"):format(a.kind == "fishing" and "Fished" or "Farmed", where and where.name or "",
		minutes, Coins(a.value), hour, count, best and (" Best: %d %s."):format(a.best.n, best) or "")
end
Card.ShareLine = ShareLine

local function ShareMenu(root, a)
	UI.TellMenu(root, "Share it in", function() return ShareLine(a) end)
end

-- When it asks: start (or go on) now, or not now (it asks again once you have left and come back).
Answered = function(key)
	local s = Session()
	if not s then return end
	if key == "start" then
		S.Go()
	else
		s.ask = nil
		ns.Changed("later")
	end
end

-- Going places (ShyQuest)

-- Leads to where you farm: the camp is the active waypoint, first on your route, the arrow pointing at it; its ground
-- the farm's (an item's droppers, or the creature's own).
local function GoToSource(target, quiet)
	if not (target and target.key) then return false end
	local spot = Spot(target, true)
	local quest = Shy.addons.Quest
	local name = target.item and C_Item.GetItemNameByID(target.item) or target.name
	local title = name and spot and spot.name and spot.name ~= name and (name .. ", " .. spot.name) or name or (spot and spot.name)
	-- (Led as where you farm it: its ground lit in the finder's color, the stop kept while you are there.)
	if spot and quest.FarmAt and quest:FarmAt(target.item, spot.map, spot.x, spot.y, spot.name, target.npc) then return true end
	if spot and quest:Go(spot.map, spot.x, spot.y, title) then return true end
	if not quiet then T:Print("no place is known where you could farm it.") end
	return false
end
Card.GoToSource = GoToSource
Card.Lead = function() return GoToSource(S.Farmed(), true) end

-- The toolbar: start, pause or go on; go where you farm; keep the item as a favorite; reset (the session saved).
function Card.Tool(key)
	local s = Session()
	if not s then return end
	local item = s.want and s.want.item
	if key == "main" then
		-- (Waiting at rest: Start sets its clock going. Running: Pause.)
		if s.state == "running" and not S.Running(s) and not S.Used(s) then
			S.Clock()
		elseif s.state == "running" then
			S.Pause(true)
		else
			S.Go()
		end
	elseif key == "find" then
		Card.Find()
	elseif key == "go" then
		GoToSource(S.Farmed())
	elseif key == "favorite" and item then
		ns.Stats.Favorite(item)
	elseif key == "stop" then
		S.Stop()
	end
end

function Card.Typed(text)
	local item = card.typing
	if not item then return end
	local copper = P.Parse(text)
	if not copper then
		if strtrim(text or "") ~= "" then T:Print("that's no price. Type it like 1g 20s, 35s or 80c.") end
		return
	end
	card.typing = nil
	P.SetOwn(item, copper)
end

-- An item's prices as a menu: the one it goes by ticked, each with what it says.
local function PriceMenu(root, item)
	local using = P.Using(item)
	local ah, at = P.Auction(item)
	local own, sell = P.Own(item), P.Vendor(item)
	if T.db.auction and P.Sellable(item) then
		local entry = root:CreateRadio("Auction price", function() return using == "auction" end, function() P.Use(item, "auction") end)
		entry:SetDetail(ah and P.Text(ah) or "not known")
		if ah then entry:SetSub(P.Age(at)) end
	end
	local vendor = root:CreateRadio("Vendor price", function() return using == "vendor" end, function() P.Use(item, "vendor") end)
	vendor:SetDetail(sell and P.Text(sell) or "none")
	if own then
		local mine = root:CreateRadio("Your price", function() return using == "own" end, function() P.Use(item, "own") end)
		mine:SetDetail(P.Text(own))
	end
	root:CreateRadio("As the setting says", function() return using == nil end, function() P.Use(item, nil) end)
	root:CreateDivider()
	root:CreateButton("Type a price", function()
		local s = Session()
		if not (s and s.want and s.want.item == item) then S.Want(item, s and s.want and s.want.goal) end
		card.typing = item
		Paint()
		card.ask.input.box:SetFocus()
	end)
end

-- Menus

-- "1 in 8", "35%", "1.4 a kill": how often a kill gives something.
local function Per(per)
	if per >= 1 then return ("%.1f a kill"):format(per) end
	if per >= 0.1 then return ("%d%%"):format(math.floor(per * 100 + 0.5)) end
	return ("1 in %d"):format(math.floor(1 / per + 0.5))
end

-- What you farm, and how: a creature's drops to count one of (or all of them alike), another of your loot, how many,
-- its price, a favorite, the way there, something else from the finder.
local function WantMenu(root, s)
	local want, mob = s.want, s.mob
	local sub = root:CreateButton("Farm")
	local target = S.Farmed(s)
	sub:SetSub(target.kind == "any" and "Everything you loot" or (want and C_Item.GetItemNameByID(want.item)) or target.name or "")
	sub:SetIcon(UI.MenuGlyph("point"))
	if mob then
		-- (A creature: all it drops alike, or one of them counted on its own.)
		sub:CreateTitle(target.name or "This creature")
		sub:CreateRadio("Everything it drops", function() return s.want == nil end, function() S.Want(nil) end)
		for _, drop in ipairs(ns.Worth.Best(mob.npc, 8)) do
			local entry = sub:CreateRadio(C_Item.GetItemNameByID(drop.item) or ("Item " .. drop.item),
				function() return s.want and s.want.item == drop.item end, function() S.Want(drop.item, s.want and s.want.goal) end)
			entry:SetDetail(Per(drop.per))
		end
		sub:CreateDivider()
	end
	local list = {}
	for item in pairs(s.items) do
		if P.Sellable(item) or (C_Item.GetItemQualityByID(item) or 0) > 0 then list[#list + 1] = item end
	end
	table.sort(list, function(a, b) return (s.items[a] or 0) > (s.items[b] or 0) end)
	if not mob then
		sub:CreateRadio("Record everything", function() return s.want == nil end, function() T:FarmAnything() end)
	end
	for i, item in ipairs(list) do
		if i > 12 then break end
		sub:CreateRadio(C_Item.GetItemNameByID(item) or ("Item " .. item), function() return s.want and s.want.item == item end,
			function() S.Want(item, s.want and s.want.goal) end)
	end
	if mob then
		sub:CreateButton("Record everything instead", function() T:FarmAnything() end)
	end
	if Card.CanFind() then
		sub:CreateDivider()
		sub:CreateButton("Find something to farm", function() Card.Find() end):SetIcon(UI.MenuGlyph("route"))
	end
	if want then
		local goal = root:CreateButton("How many")
		goal:SetSub(want.goal and (want.goal .. " in your bags") or "As many as you can")
		goal:SetIcon(UI.MenuGlyph("done"))
		goal:CreateRadio("As many as you can", function() return want.goal == nil end, function() S.Want(want.item, nil) end)
		for _, n in ipairs({ 5, 10, 20, 40, 60, 100 }) do
			goal:CreateRadio(tostring(n), function() return want.goal == n end, function() S.Want(want.item, n) end)
		end
		local price = root:CreateButton("Its price")
		local worth, from = P.Value(want.item)
		price:SetSub(worth and (P.Text(worth) .. ", " .. P.FROM[from]) or "Not known")
		price:SetIcon(UI.MenuGlyph("sum"))
		PriceMenu(price, want.item)
		root:CreateCheckbox("Favorite", function() return ns.Stats.IsFavorite(want.item) end,
			function() ns.Stats.Favorite(want.item) end)
	end
	if target.kind ~= "any" and Spot(target) then
		root:CreateButton("Take me there", function() GoToSource(target) end):SetIcon(UI.MenuGlyph("route"))
	end
end

-- Past sessions, newest first: where, how long, what it made and an hour.
local function HistoryMenu(root)
	local history = S.History()
	local sub = root:CreateButton("Past sessions")
	sub:SetSub(#history == 0 and "None yet" or (#history .. " kept"))
	sub:SetIcon(UI.MenuGlyph("clock"))
	if #history == 0 then
		sub:CreateTitle("None yet")
		return
	end
	for _, kept in ipairs(history) do
		local where = kept.map and C_Map.GetMapInfo(kept.map)
		local hour = kept.seconds >= 60 and (kept.value * 3600 / kept.seconds) or nil
		local entry = sub:CreateButton(("%s, %s"):format(where and where.name or "Somewhere", Card.Clock(kept.seconds)))
		entry:SetDetail(P.Text(kept.value))
		entry:SetSub((kept.kind == "fishing" and "Fishing" or "Grinding") .. (hour and (", " .. P.Text(hour) .. " an hour") or "")
			.. ", " .. date("%b %d", kept.began))
		-- (Each one shared in a chat of your choice.)
		ShareMenu(entry, { seconds = kept.seconds, value = kept.value, kills = kept.kills, catches = kept.catches,
			kind = kept.kind, map = kept.map, best = S.Best(kept.items or {}) })
	end
	sub:CreateDivider()
	sub:CreateButton("Forget them", function() wipe(ns.char.history) end)
end

function Card.Menu(root)
	local s = Session()
	if s then
		root:CreateTitle(S.Kind(s) == "fishing" and "Fishing" or "Grinding")
		WantMenu(root, s)
		local quest = Shy.addons.Quest
		if T.db.auction and quest and quest.Nearest then
			root:CreateButton("Nearest auction house", function()
				local place = quest:Nearest("auction")
				if not (place and quest:Go(place.map, place.x, place.y, place.name)) then T:Print("no auction house is known near you.") end
			end):SetIcon(UI.MenuGlyph("route"))
		end
	else
		root:CreateTitle("Farming")
		root:CreateButton("Start a session", function() S.Begin() end):SetIcon(UI.MenuGlyph("first"))
		if Card.CanFind() then
			root:CreateButton("Find something to farm", function() Card.Find() end):SetIcon(UI.MenuGlyph("route"))
		end
	end
	HistoryMenu(root)
	root:CreateDivider()
	root:CreateButton("Options", function() T:OpenOptions() end):SetIcon(UI.MenuGlyph("options"))
end

-- Hovers and clicks

-- A loot row's hover: what one is worth by each price, which it goes by, and its odds from what you have looted.
function Card.RowTip(row)
	local data = row.data
	if not data or not data.item then return end
	local item = data.item
	local rows = {}
	local worth, from = P.Value(item)
	local ah, at = P.Auction(item)
	local own, sell = P.Own(item), P.Vendor(item)
	if T.db.auction and P.Sellable(item) then
		rows[#rows + 1] = { glyph = "coin", text = "Auction" .. (at and (", " .. P.Age(at)) or ""), right = ah and P.Text(ah) or "not known",
			color = from == "auction" and C.text or C.dim, rightColor = from == "auction" and C.hot or C.dim }
	end
	rows[#rows + 1] = { glyph = "bag", text = "Vendor", right = sell and P.Text(sell) or "none",
		color = from == "vendor" and C.text or C.dim, rightColor = from == "vendor" and C.hot or C.dim }
	if own then
		rows[#rows + 1] = { glyph = "star", text = "Yours", right = P.Text(own), color = from == "own" and C.text or C.dim,
			rightColor = from == "own" and C.hot or C.dim }
	end
	local sections = { { title = "One is worth", rows = rows } }
	local drops = S.Drops(item)
	if #drops > 0 then
		local yours = {}
		for i, each in ipairs(drops) do
			if i > 3 then break end
			yours[#yours + 1] = { glyph = "kill", text = each.name or "A creature", right = ("%d from %d"):format(each.drops, each.corpses) }
		end
		sections[2] = { title = "You looted", rows = yours }
	end
	UI.Tip(row, data.name or "", worth and ("%d came to %s."):format(data.n or 0, P.Text((worth or 0) * (data.n or 0))) or nil,
		{ sections = sections, hints = { { "left", "Keep count of this" }, { "right", "Its price" } }, at = UI.Beside(card, row) })
end

function Card.RowClick(row, button)
	local data = row.data
	local item = data and data.item
	if not item then
		if button == "RightButton" and box then UI.ContextMenu(row, Card.Menu) end
		return
	end
	if button == "LeftButton" and IsModifiedClick("CHATLINK") then
		local link = select(2, C_Item.GetItemInfo(item))
		if link then ChatFrameUtil.InsertLink(link) end
	elseif button == "RightButton" then
		UI.ContextMenu(row, function(root)
			root:CreateTitle(data.name or "")
			PriceMenu(root, item)
			root:CreateDivider()
			root:CreateButton("Keep count of this", function() S.Want(item) end):SetIcon(UI.MenuGlyph("point"))
		end)
	else
		S.Want(item, Session() and Session().want and Session().want.item == item and Session().want.goal or nil)
	end
end

-- What you farm, hovered: an item, where it comes from (ShyQuest) and how it is valued; a creature, what a kill
-- brings and its drops; anything you loot, that you can pick one.
function Card.WantTip(frame)
	local s = Session()
	if not s then return end
	local target = S.Farmed(s)
	local want = s.want
	if not want and target.kind == "mob" then
		local rows = {}
		for _, drop in ipairs(ns.Worth.Best(target.npc, 5)) do
			rows[#rows + 1] = { icon = C_Item.GetItemIconByID(drop.item), text = C_Item.GetItemNameByID(drop.item) or ("Item " .. drop.item),
				right = Per(drop.per), rightColor = C.dim }
		end
		local worth = ns.Worth.Worth(target.npc)
		UI.Tip(frame, target.name or "", worth and ("Each kill is worth about %s."):format(P.Text(worth)) or nil,
			{ sections = #rows > 0 and { { title = "Best drops", rows = rows } } or nil,
			hints = { { "left", "Keep count of one drop, or farm something else" } }, at = UI.Beside(card, frame) })
		return
	end
	if not want then
		UI.Tip(frame, "Anything you loot", "Pick an item to keep count of, or a creature to farm. Everything you loot still counts.",
			{ hints = { { "left", Card.CanFind() and "Find something to farm" or "Keep count of something you looted" } }, at = UI.Beside(card, frame) })
		return
	end
	local item = want.item
	local rows = {}
	for i, source in ipairs(Sources(item) or {}) do
		if i > 4 then break end
		rows[#rows + 1] = { glyph = source.kind == "vendor" and "coin" or source.kind == "object" and "loot" or "kill",
			text = source.name, right = source.chance and (source.chance .. "%") or "", rightColor = C.dim }
	end
	local sections = {}
	if #rows > 0 then sections[1] = { title = "Comes from", rows = rows } end
	local worth, from = P.Value(item)
	UI.Tip(frame, C_Item.GetItemNameByID(item) or "", worth and ("One is worth %s, by its %s price."):format(P.Text(worth), P.FROM[from]) or nil,
		{ sections = sections, hints = { { "left", "How many, its price, farm another" } }, at = UI.Beside(card, frame) })
end

function Card.WantClick(frame, button)
	local s = Session()
	if not s then return end
	local want = s.want
	if want and IsModifiedClick("CHATLINK") then
		local link = select(2, C_Item.GetItemInfo(want.item))
		if link then ChatFrameUtil.InsertLink(link) end
	elseif not want and not s.mob and button ~= "RightButton" and Card.CanFind() then
		-- (Anything you loot: a click finds something to farm, as its Find does.)
		Card.Find()
	else
		UI.ContextMenu(frame, function(root) WantMenu(root, s) end)
	end
end

function Card.CardTip(frame)
	local s = Session()
	if not s then return end
	local seconds = S.Seconds(s)
	local words = ("%s of farming"):format(Card.Clock(seconds))
	if not S.Used(s) then
		words = "Nothing yet. The clock starts when you loot something."
	elseif s.state == "ready" then
		words = "Not started yet: nothing counts until you start."
	elseif s.state == "paused" then
		words = words .. ", paused."
	elseif not S.Running(s) then
		words = words .. ", the clock stopped while you rested."
	end
	-- (Where you farm, which the window itself leaves to your map.)
	local where = s.map and C_Map.GetMapInfo(s.map)
	UI.Tip(frame, where and ("Farming in " .. where.name) or "Farming", words, { hints = K.HINTS })
end

-- What it says

-- You hold as many as you wanted: the head says so a moment, with a sound, and the tab is gold.
function Card.Reached(item, goal)
	if T.db.sound then PlaySound(SOUNDKIT.READY_CHECK) end
	local N = Shy.Notices
	local name = C_Item.GetItemNameByID(item) or "What you farmed"
	if N and N.Voice then
		N.Voice("shyfarm-goal", { priority = 5, hold = 6, icon = C_Item.GetItemIconByID(item), title = name,
			under = ("You have %d"):format(goal) })
	else
		T:Print(("you have %d %s."):format(goal, name))
	end
end

-- What is farmed, for a notice: its name and picture (an item's, else ShyFarm's own).
local function Named(s)
	local target = S.Farmed(s)
	local item = target.item
	return item and C_Item.GetItemNameByID(item) or target.name, item and C_Item.GetItemIconByID(item) or T.smallIcon
end

-- Asking to start (or go on): the band in the window, a sound, and a notice a click on which starts it. Said once
-- until answered; ns.Changed paints it.
local function Ask(s)
	if s.ask then return end
	s.ask = true
	if T.db.sound then PlaySound(SOUNDKIT.READY_CHECK) end
	local N = Shy.Notices
	local name, icon = Named(s)
	if N and N.Post then
		N.Post("shyfarm-ask", { order = 39, icon = icon, color = C.alert,
			text = s.state == "paused" and "Paused" or "Start", title = name or "Farming",
			note = s.state == "paused" and "That loot didn't count." or "You're where it drops.",
			says = "Click to start counting.", click = function() S.Go() end, hold = 60 })
	end
	ns.Changed("ask")
end

-- Farming started by itself (you got there, or came back): a chime, the head says so a moment, the window shows its
-- band and the figures lit.
function Card.Started(item, how)
	local N = Shy.Notices
	local s = Session()
	local name, icon = Named(s)
	if item then name, icon = C_Item.GetItemNameByID(item) or name, C_Item.GetItemIconByID(item) or icon end
	name = name or "it"
	if s then s.there = time() end
	if T.db.sound then PlaySound(SOUNDKIT.UI_WORLDQUEST_START) end
	local under = how == "back" and "You're back: counting again" or "You're there: counting now"
	if N and N.Voice then
		N.Voice("shyfarm-started", { priority = 5, hold = 5, icon = icon, title = "Farming " .. name, under = under })
	else
		T:Print(("farming %s. %s."):format(name, under))
	end
	ns.Changed("there")
	if card then card:Light() end
end

-- Looted what you farm while it didn't count.
function Card.Nudge()
	local s = Session()
	if s then Ask(s) end
end

-- Where you farm is the ground the maps light for it (ShyQuest's FarmGround: the spawns of what you'd farm an item
-- from, or the creature's own). Stepping onto it starts the session, or goes on after you left it or reloaded;
-- stepping off pauses it, and it goes on as you come back. A pause by hand stays. ShyQuest is the one judge of it
-- (its farm stop says "Farm it here" on the same ground): it says so as it builds your route (bus SHY_FARM_GROUND,
-- with the farm's key), and as the game tells of a stop, a fight, a loot or a zone it is asked straight (Where). In
-- within IN yards of a spawn, out past OUT: its own.
local IN, OUT = 40, 60
local function OnGround(s, on)
	if on and (s.state == "ready" or (s.state == "paused" and (s.why == "left" or s.why == "reload"))) then
		local resumed = s.state == "paused"
		S.Go()
		s.there = time()
		Card.Started(s.want and s.want.item, resumed and "back" or "there")
	elseif on == false and s.state == "running" and S.Used(s) then
		S.Pause(true, "left")
		if T.db.sound then PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT) end
		local N = Shy.Notices
		if N and N.Voice then
			local _, icon = Named(s)
			N.Voice("shyfarm-started", { priority = 5, hold = 4, icon = icon, title = "Paused", under = "You left where it drops" })
		end
	end
end
local Where = Shy.Clocked("farm: where you are", function()
	local s = Session()
	local quest = Shy.addons.Quest
	local key = s and S.Farmed(s).key
	if not (key and quest and quest.FarmGroundYards) then return end
	local yards = quest:FarmGroundYards(key)
	if not yards then return end
	if yards <= IN then OnGround(s, true) elseif yards > OUT then OnGround(s, false) end
end)
Shy:On("SHY_FARM_GROUND", Shy.Clocked("farm: its ground stepped on or off", function(key, on)
	local s = Session()
	if s and key ~= nil and S.Farmed(s).key == key then OnGround(s, on) end
end))
function Card.Where()
	local ok, err = pcall(Where)
	if not ok then geterrorhandler()(err) end
end

-- "4g", "35s", "80c": the notice's few letters.
local function Gold(copper)
	if copper >= COPPER_PER_GOLD then return math.floor(copper / COPPER_PER_GOLD) .. "g" end
	if copper >= COPPER_PER_SILVER then return math.floor(copper / COPPER_PER_SILVER) .. "s" end
	return math.floor(copper) .. "c"
end

-- A session ended: what it made, as a notice that stands a while.
-- A session reset: what it came to, as a notice for a moment (nothing in the window: its room is the loot's). Its
-- right-click shares it, or shows your past sessions.
function Card.Summary(kept)
	local N = Shy.Notices
	local hour = kept.seconds >= 60 and (kept.value * 3600 / kept.seconds) or nil
	local note = ("%s, %s an hour"):format(Card.Clock(kept.seconds), hour and P.Text(hour) or "\226\128\148")
	if not (N and N.Post) then
		T:Print(("saved: %s in %s."):format(P.Text(kept.value), note))
		return
	end
	local shared = { seconds = kept.seconds, value = kept.value, kills = kept.kills, catches = kept.catches, kind = kept.kind,
		map = kept.map, best = S.Best(kept.items or {}) }
	N.Post("shyfarm", { order = 40, icon = T.smallIcon, color = C.alert, text = Gold(kept.value),
		title = "Saved: " .. P.Text(kept.value), note = note, hold = 12,
		says = "Right-click to share it.",
		menu = function(root)
			ShareMenu(root, shared)
			HistoryMenu(root)
		end })
end

-- The piece for a planned screen (ShyDock's Parts.lua): its width and its height at the setting's rows, with what you
-- farm showing; nil while it is off. Bus SHY_FARM_PIECE when that changes.
function T:Piece()
	if not T.db.on then return nil end
	local view = { want = true }
	return { id = "shyfarm", width = K.WIDTH, height = Card.Height(view, T.db.rows), scale = box and box:GetScale() or 1,
		passing = true }
end

-- Shows the piece where it stands now (the hub's Open, /shyfarm show): with none going on, a session waits for you.
function Card.Reveal()
	S.Wait()
	Paint()
end

-- Its ×: the farm ends for good, kept with your past ones, and nothing counts until you choose to farm again. Asked
-- first; one only waiting (nothing counted, nothing picked) just goes with the window.
local function End()
	S.Stop()
	S.Drop()
end
function Card.Close()
	local s = Session()
	if not s then return end
	if not S.Used(s) and not s.want and not s.mob then
		S.Drop()
		return
	end
	UI.Confirm(box, "End this farm? It's kept with your past ones, and nothing counts until you farm again.", "End farm", End)
end

-- A look a second while the window shows a running clock, and none at all otherwise.
local Beat = Shy.Clocked("farm: the clock", function()
	if box:IsShown() and card.view and Session() and S.Running() then
		card.clock:SetText(Card.Clock(S.Seconds()))
		card.view.seconds = S.Seconds()
	end
end)
local where   -- the events that say you may have come to or left where you farm (Where)
function Card.Wake()
	local s = Session()
	-- (Where you are is looked at only as the game says something happened: you stopped, a fight began, a zone.)
	local watch = s ~= nil and (s.want ~= nil or s.mob ~= nil)
	if where and watch ~= where.on then
		where.on = watch
		for _, event in ipairs(where.EVENTS) do
			if watch then where:RegisterEvent(event) else where:UnregisterEvent(event) end
		end
		if watch then Card.Where() end
	end
	local need = s ~= nil and s.state == "running" and box ~= nil and box:IsShown()
	if need and not ticker then
		ticker = C_Timer.NewTicker(1, Beat) or true
	elseif not need and ticker then
		if type(ticker) == "table" and ticker.Cancel then ticker:Cancel() end
		ticker = nil
	end
end

function Card.Start()
	box = HUD.Create({
		id = "shyfarm",
		title = "ShyFarm session",
		width = K.WIDTH,
		height = Card.Height(Card.SAMPLE, T.db.rows),
		-- The top left's corner, where how to play stands (ShyDock puts that under it while a session shows).
		point = { "TOPLEFT", "TOPLEFT", 16, -16 },
		shown = Shown,
		-- Its options' "On screen while you farm".
		switch = {
			get = function() return T.db.on ~= false end,
			set = function(on)
				T.db.on = on
				ns.Apply()
				if ns.RefreshOptions then ns.RefreshOptions() end
			end,
			hint = "Your loot and gold an hour while you farm",
		},
		hang = true,
		-- (Sized from a corner it is laid out again as it is, the rows that fit shown.)
		grip = { flow = function() if card and card.view then card:Fill(card.view) end end,
			min = { K.MIN_W, Card.Height(Card.SAMPLE, K.LEAST) } },
	})
	card = ns.CreateCard(box, box)
	HUD.Manage(box, card, Card.Menu)
	-- Joining or leaving a raid shows or hides it.
	local roster = CreateFrame("Frame")
	roster:RegisterEvent("GROUP_ROSTER_UPDATE")
	roster:SetScript("OnEvent", function() HUD.Update(box) end)
	local immersion = Shy.Immersion
	if immersion and immersion.Watch then immersion.Watch("farm", box) end

	-- The clock: a look a second while the piece shows a session whose clock runs; nothing at rest.

	table.insert(ns.appliers, Paint)
	-- The farming ended: where you farmed leaves your route.
	Shy:On("SHY_FARM", function(why)
		if why ~= "stop" then return end
		local quest = Shy.addons.Quest
		if quest and quest.EndFarm then quest:EndFarm() end
	end)
	-- (Nothing asks any more once it runs or ends: the notice goes.)
	table.insert(ns.appliers, function()
		local s = Session()
		if not (s and s.ask) and Shy.Notices and Shy.Notices.Clear then Shy.Notices.Clear("shyfarm-ask") end
	end)
	-- Where you are, asked only as the game tells of a stop, a fight, a loot or a zone; the clock only while it runs.
	where = CreateFrame("Frame")
	where.EVENTS = { "PLAYER_STOPPED_MOVING", "PLAYER_REGEN_DISABLED", "LOOT_READY", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
		"ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }
	where.on = false
	where:SetScript("OnEvent", function() Card.Where() end)
	box:HookScript("OnShow", function() Card.Wake() end)
	box:HookScript("OnHide", function() Card.Wake() end)
	table.insert(ns.appliers, Card.Wake)
	Card.Wake()
	Shy:On("SHY_HUD_LAYOUT", Paint)
	Shy:On("SHY_THEME", Paint)
	-- Room in your bags said again as it changes (selling, using, moving things), only its words, only while the piece
	-- shows: ShyBags says so, and the game does.
	local Bagged = Shy.Clocked("farm: room in your bags", function()
		if not (card and card.view and Session() and box:IsShown()) then return end
		card.view.room = Room()
		card:FillRoom(card.view.room)
	end)
	Shy:On("SHY_BAGS_ROOM", Bagged)
	local bagged = CreateFrame("Frame")
	bagged:RegisterEvent("BAG_UPDATE_DELAYED")
	bagged:SetScript("OnEvent", Bagged)
	Paint()
end

function Card.Parts() return box, card end

-- The piece's size changed (a setting, the farmed item showing or not): whoever plans the screen plans again.
local said
table.insert(ns.appliers, function()
	local piece = T:Piece()
	local now = piece and piece.height or false
	if said ~= nil and said ~= now then Shy:Fire("SHY_FARM_PIECE") end
	said = now
end)
