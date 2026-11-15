-- Farm: ShyFarm's farm finder at the auction house, priced by this house. Three views, picked along the top:
--   Best gold an hour   every farm you could farm, ranked by gold an hour with the trip by the flights you know taken out;
--   For an item         the farms for the item last picked on Buy or Sell (or a favorite clicked), by how many an hour;
--   Your favorites      what you farm again and again, and what your own farming of each came to.
-- A farm's row: its rank, the creature and its levels, where it is and how long the way, its camp, what brings most of
-- its worth (each drop's card on hover, with this house's price), its gold an hour with a meter of it against the best,
-- and Farm this (ShyFarm farms it and ShyQuest leads to that camp). The best is lit in gold. At the right of the views:
-- your level, the flights and your pace the ranking went by. Without ShyFarm the tab says what it needs.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Theme = Shy.Theme
local C = UI.colors
local Shop = Shy.Shop
local Slot = Shy.Slot

local L = { row = 54, drops = 3, tile = 16, dropGap = 70, meter = 110, right = 120, go = 96, bar = 26 }
local VIEWS = { "best", "item", "favorites" }
local WORDS = {
	views = { "Best gold an hour", "For an item", "Your favorites" },
	need = "The farm finder is ShyFarm's: turn it on to see the best farms here.",
	quest = "The farm finder needs ShyQuest, which knows where everything stands.",
	working = "Weighing every farm you could farm...",
	none = "Nothing you could farm at your level drops it.",
	pick = "Pick an item on Buy or Sell, and the farms for it are here.",
	noFavorites = "No favorites yet: star an item in the finder, and it is kept here.",
	context = "Level %d  \194\183  the flights you know  \194\183  your pace, %d s a kill",
	tripped = "an hour, the trip counted", allDrops = "%s an hour, all drops", items = "%s an hour",
	away = "%d min away", camp = "a camp of %d", farmThis = "Farm this", wayWorking = "working out the way...",
	notFarmed = "not farmed yet", farmed = "%d looted in %d sessions  \194\183  at best %d an hour",
	market = "Market %s each", forIt = "Farms for %s",
}

local page, views, context, scroll, rows, missing, lead
local view = "best"
local want                 -- the item For an item shows, when a favorite was clicked

local function Farm()
	local farm = Shy.addons.Farm
	return farm and farm.Farms and farm or nil
end

-- The item For an item shows: a favorite clicked, else the one last picked on Buy or Sell.
local function Wanted() return want or ns.lastPick end

local function Where(f)
	local map = f.camp and f.camp.map
	local info = map and C_Map.GetMapInfo(map)
	local parts = { info and info.name or "" }
	if f.going == "working" then
		parts[#parts + 1] = "|cffe1eeff" .. WORDS.wayWorking .. "|r"
	elseif f.trip then
		parts[#parts + 1] = "|cffe1eeff" .. WORDS.away:format(math.max(1, math.floor(f.trip / 60 + 0.5))) .. "|r"
	end
	if f.camp and f.camp.supply then parts[#parts + 1] = WORDS.camp:format(f.camp.supply) end
	return table.concat(parts, "  \194\183  ")
end

-- A drop: its picture in a slot and how often it comes; its card (with this house's price) on hover.
local function Drop(row, d)
	local piece = CreateFrame("Frame", nil, row)
	piece:SetSize(L.tile, L.tile)
	piece:SetPoint("TOPLEFT", 30 + (d - 1) * L.dropGap, -35)
	piece.icon = piece:CreateTexture(nil, "ARTWORK")
	piece.icon:SetAllPoints()
	piece.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	piece.slot = Slot.New(piece, { to = piece.icon, icon = piece.icon, size = Slot.SIZES.tiny, hover = false })
	piece.text = Shop.Text(row, UI.TextFont(10), C.dim)
	piece.text:SetPoint("LEFT", piece, "RIGHT", 5, 0)
	piece:EnableMouse(true)
	piece:SetScript("OnEnter", function(self)
		if not self.item then return end
		UI.GameTipAt(self, self.icon)
		GameTooltip:SetItemByID(self.item)
		GameTooltip:Show()
	end)
	piece:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return piece
end

local function Go(b)
	local row = b:GetParent()
	local farm, quest = Farm(), Shy.addons.Quest
	if not (farm and row.item) then return end
	farm:Farm(row.item, row.goal)
	local f = row.farm
	if f and quest and quest.FarmAt and f.camp then quest:FarmAt(row.item, f.camp.map, f.camp.x, f.camp.y, f.name) end
end

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, scroll.content)
	row:SetHeight(L.row)
	ns.Parts.Wash(row)
	-- The best: a wash of gold from the left.
	row.gold = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.gold:SetAllPoints()
	row.gold:SetColorTexture(1, 1, 1, 1)
	row.rule = Shop.Rule(row)
	row.rule:SetPoint("BOTTOMLEFT")
	row.rule:SetPoint("BOTTOMRIGHT")
	row.rank = Shop.Text(row, UI.TitleFont(16), C.dim)
	row.rank:SetPoint("LEFT", 4, 0)
	row.rank:SetWidth(20)
	row.rank:SetJustifyH("CENTER")
	-- A favorite's picture (a farm's row has none).
	row.pic = CreateFrame("Frame", nil, row)
	row.pic:SetSize(36, 36)
	row.pic:SetPoint("LEFT", 30, 0)
	row.icon = row.pic:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.slot = Slot.New(row.pic, { icon = row.icon, size = 36, hover = false })
	row.name = Shop.Text(row, UI.NameFont(13), C.text)
	row.name:SetPoint("TOPLEFT", 30, -8)
	row.level = Shop.Text(row, UI.TextFont(10), C.dim)
	row.level:SetPoint("LEFT", row.name, "RIGHT", 6, -1)
	row.where = Shop.Text(row, UI.TextFont(10), C.dim)
	row.where:SetPoint("TOPLEFT", 30, -24)
	row.drops = {}
	for d = 1, L.drops do row.drops[d] = Drop(row, d) end
	row.money = Shop.Text(row, UI.NameFont(15), C.text)
	row.money:SetJustifyH("RIGHT")
	row.money:SetPoint("TOPRIGHT", -L.right, -8)
	row.note = Shop.Text(row, UI.TextFont(10), C.dim)
	row.note:SetJustifyH("RIGHT")
	row.note:SetPoint("TOPRIGHT", -L.right, -26)
	-- The meter: gold an hour against the best.
	row.track = row:CreateTexture(nil, "ARTWORK")
	row.track:SetSize(L.meter, 5)
	row.track:SetPoint("TOPRIGHT", -L.right, -41)
	UI.Paint(row.track, C.bg, 1)
	row.fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.fill:SetHeight(5)
	row.fill:SetPoint("TOPLEFT", row.track)
	row.fill:SetColorTexture(1, 1, 1, 1)
	row.go = UI.Button(row, WORDS.farmThis, L.go, Go)
	row.go:SetHeight(24)
	row.go:SetPoint("RIGHT", -10, 0)
	row:SetScript("OnEnter", function(self) self.hot:Show() end)
	row:SetScript("OnLeave", function(self) self.hot:Hide() end)
	row:SetScript("OnClick", function(self)
		-- A favorite: its farms.
		if view ~= "favorites" or not self.item then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		want, view = self.item, "item"
		views:Select(2)
	end)
	rows[i] = row
	return row
end

local function Meter(row, share, best)
	row.track:Show()
	row.fill:SetShown(share > 0)
	row.fill:SetWidth(math.max(1, L.meter * math.min(1, share)))
	if best then
		row.fill:SetGradient("HORIZONTAL", CreateColor(0.63, 0.43, 0.08, 1), CreateColor(C.alert[1], C.alert[2], C.alert[3], 1))
	else
		local r, g, b = Theme.AccentSolid()
		row.fill:SetGradient("HORIZONTAL", CreateColor(r * 0.45, g * 0.45, b * 0.45, 1), CreateColor(r, g, b, 1))
	end
end

-- Lit as the best (the first of a ranking) or not.
local function Lit(row, best, i)
	row.rank:SetText(i or "")
	UI.Ink(row.rank, best and C.alert or C.dim)
	row.gold:SetShown(best)
	if best then
		local a = C.alert
		row.gold:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 0.12), CreateColor(a[1], a[2], a[3], 0))
	end
	row.go:SetPrimary(best)
end

local function DrawFarm(row, i, f, farm, item, top)
	row.farm, row.goal = f, nil
	Lit(row, i == 1, i)
	row.pic:Hide()
	row.name:SetPoint("TOPLEFT", 30, -8)
	row.where:SetPoint("TOPLEFT", 30, -24)
	row.name:SetText(f.name or "")
	row.level:SetText(f.low and (f.high and f.high ~= f.low and ("level %d\226\128\147%d"):format(f.low, f.high) or ("level %d"):format(f.low)) or "")
	row.where:SetText(Where(f))
	local _, best = farm:KillWorth(f.npc)
	row.item = item or (best and best[1] and best[1].item)
	for d = 1, L.drops do
		local drop, piece = best and best[d], row.drops[d]
		piece:SetShown(drop ~= nil)
		piece.text:SetShown(drop ~= nil)
		piece.item = drop and drop.item
		if drop then
			piece.icon:SetTexture(C_Item.GetItemIconByID(drop.item) or 134400)
			piece.slot:Quality(C_Item.GetItemQualityByID(drop.item))
			piece.text:SetText(drop.per >= 0.1 and ("%.1f a kill"):format(drop.per) or ("%d%%"):format(math.max(1, math.floor(drop.per * 100 + 0.5))))
		end
	end
	if item and f.items then
		row.money:SetText(WORDS.items:format(math.floor(f.items + 0.5)))
		row.note:SetText(WORDS.allDrops:format(UI.Money(math.floor(f.net + 0.5), true, 10, row.note)))
		Meter(row, top and top > 0 and f.items / top or 0, i == 1)
	else
		row.money:SetText(UI.Money(math.floor(f.net + 0.5), true, 15, row.money))
		row.note:SetText(WORDS.tripped)
		Meter(row, top and top > 0 and f.net / top or 0, i == 1)
	end
	row:Pick(false)
end

local function DrawFavorite(row, fav)
	row.farm, row.item, row.goal = nil, fav.item, fav.goal
	Lit(row, false, nil)
	local name, quality, icon = ns.Parts.Name(fav.item)
	row.pic:Show()
	row.icon:SetTexture(icon or 134400)
	row.slot:Quality(quality)
	row.name:SetPoint("TOPLEFT", 74, -10)
	row.where:SetPoint("TOPLEFT", 74, -28)
	row.name:SetText(name or fav.name or "")
	local color = quality and ITEM_QUALITY_COLORS[quality]
	if color then row.name:SetTextColor(color.r, color.g, color.b) else UI.Ink(row.name, C.text) end
	row.level:SetText(fav.goal and ("to %d"):format(fav.goal) or "")
	local st = fav.stats or {}
	row.where:SetText((st.sessions or 0) > 0 and WORDS.farmed:format(st.looted or 0, st.sessions, math.floor((st.best or 0) + 0.5))
		or WORDS.notFarmed)
	for d = 1, L.drops do
		row.drops[d]:Hide()
		row.drops[d].text:Hide()
	end
	local price = ns.Book.Price(fav.item)
	if st.gold then
		row.money:SetText(UI.Money(math.floor(st.gold + 0.5), true, 15, row.money))
		row.note:SetText(WORDS.items:format(math.floor((st.rate or 0) + 0.5)))
	else
		row.money:SetText(price and price.market and UI.Money(price.market, true, 15, row.money) or "")
		row.note:SetText(price and price.market and "each, at this house" or "")
	end
	row.track:Hide()
	row.fill:Hide()
	row:Pick(false)
end

local function Build(frame)
	page = frame
	rows = {}
	views = UI.Segments(page, WORDS.views, function(i)
		local was = view
		view = VIEWS[i] or "best"
		if view ~= "item" then want = nil end
		if was ~= view then scroll:SetScroll(0) end
		ns.Window.Stale()
	end, { height = 24 })
	views:SetPoint("TOPLEFT", 12, -4)
	views:Select(1)
	context = Shop.Text(page, UI.TextFont(10), C.dim)
	context:SetPoint("RIGHT", page, "TOPRIGHT", -12, -16)
	context:SetJustifyH("RIGHT")
	-- For an item: the item, its market here, above its farms.
	lead = Shop.Kicker(page)
	lead:SetPoint("TOPLEFT", 12, -36)
	lead:SetPoint("RIGHT", -12, 0)
	scroll = UI.ScrollArea(page, 600, 300, { quiet = true, smooth = true })
	scroll:SetPoint("TOPLEFT", 12, -34)
	scroll:SetPoint("BOTTOMRIGHT", -12, 6)
	missing = Shop.Text(page, UI.TextFont(12), C.dim)
	missing:SetPoint("CENTER")
end

local function Say(text)
	missing:SetText(text or "")
	missing:SetShown(text ~= nil)
end

local function Draw(frame, width, height)
	local farm = Farm()
	views:SetShown(farm ~= nil)
	context:SetShown(farm ~= nil)
	lead:Hide()
	if not farm then
		scroll:Hide()
		return Say(WORDS.need)
	end
	local pace = farm.Pace and farm:Pace()
	context:SetText(pace and WORDS.context:format(UnitLevel("player"), math.floor(pace + 0.5)) or "")
	local list, state, ranked = farm:Farms()
	local item = view == "item" and Wanted() or nil
	local entries, favorites
	if view == "favorites" then
		favorites = farm:Favorites() or {}
		entries = #favorites
		Say(entries == 0 and WORDS.noFavorites or nil)
	elseif view == "item" and not item then
		entries = 0
		Say(WORDS.pick)
	else
		-- Ranked for what this view shows (weighed again, over a few frames, when it isn't).
		if state ~= "working" and state ~= "missing" and (state == nil or ranked ~= item) then
			farm:RankFarms(item)
			list, state, ranked = farm:Farms()
		end
		if ranked ~= item then list = nil end
		entries = list and #list or 0
		Say((state == "missing" and WORDS.quest) or (entries == 0 and (state == "working" and WORDS.working or WORDS.none)) or nil)
	end
	local top = 34
	if item then
		local name = ns.Parts.Name(item)
		local price = ns.Book.Price(item)
		lead:Say(WORDS.forIt:format(name or ""), price and price.market and WORDS.market:format(UI.Money(price.market, true, 10, lead.aside)) or nil)
		lead:Show()
		top = 58
	end
	scroll:SetPoint("TOPLEFT", 12, -top)
	scroll:SetShown(entries > 0)
	scroll.content:SetWidth(width - 24 - 14)
	scroll.content:SetHeight(math.max(1, entries * L.row))
	local best = list and list[1] and (item and list[1].items or list[1].net)
	for i = 1, math.max(entries, #rows) do
		local row = rows[i]
		if i <= entries then
			row = Row(i)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -(i - 1) * L.row)
			row:SetPoint("RIGHT")
			if favorites then DrawFavorite(row, favorites[i]) else DrawFarm(row, i, list[i], farm, item, best) end
			row:Show()
		elseif row then
			row:Hide()
		end
	end
	scroll:Update()
end

ns.AddPage({ key = "farm", label = "Farm", order = 4, Build = Build, Draw = Draw })
-- (Exposed for inspection.)
ns.FarmPage = { Parts = function() return views, rows, context, lead, missing end }

Shy:On("SHY_FARM", function(why)
	if (why == "farms" or why == "favorite") and ns.Window.Page() == "farm" then ns.Window.Stale() end
end)
