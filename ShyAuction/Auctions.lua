-- Auctions: three figures (what you have on the auction house, how many are undercut, what sold today), then your listings: each
-- price and whether it is the cheapest or undercut (by what your last scan or search saw), time left as a bar, Cancel.
-- An auction can't be reposted in place: one cancelled (its deposit lost) or run out comes back by mail, and is posted
-- again from Sell once you have it, so an undercut row says which to do. Sold ones say the gold is in your mail.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors
local Shop = Shy.Shop
local P = ns.Parts

local L = { row = 38, figure = 52, soon = 4 * 3600 }

local page, figures, scroll, list
local mine = {}

-- Your listings, with what the book says of each: { id, item, quantity, unit, sold, left, cheapest, under }.
local function Read()
	wipe(mine)
	for _, a in ipairs(C_AuctionHouse.GetOwnedAuctions() or {}) do
		local item = a.itemKey and a.itemKey.itemID
		if item and not issecretvalue(item) and a.buyoutAmount and not issecretvalue(a.buyoutAmount) then
			-- The auction house gives a listing's price each; a sale's, the whole of it.
			local quantity = math.max(1, a.quantity or 1)
			local sold = a.status == Enum.AuctionStatus.Sold
			local unit = sold and math.floor(a.buyoutAmount / quantity + 0.5) or a.buyoutAmount
			local price = ns.Book.Price(item)
			local entry = { id = a.auctionID, item = item, quantity = quantity, unit = unit, sold = sold,
				left = a.timeLeftSeconds, buyout = sold and a.buyoutAmount or a.buyoutAmount * quantity }
			if not entry.sold and price and price.unit and price.unit < unit then entry.under = price.unit end
			mine[#mine + 1] = entry
		end
	end
	-- Undercut first, then the rest by time left, sold last.
	table.sort(mine, function(a, b)
		if a.sold ~= b.sold then return b.sold end
		if (a.under ~= nil) ~= (b.under ~= nil) then return a.under ~= nil end
		return (a.left or 0) < (b.left or 0)
	end)
end

local function Figure(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(L.figure)
	UI.Skin(f, C.bg, C.border)
	f.word = Shop.Text(f, UI.NameFont(9), C.dim)
	f.word:SetPoint("TOPLEFT", 10, -8)
	f.value = Shop.Text(f, UI.NameFont(16), C.text)
	f.value:SetPoint("BOTTOMLEFT", 10, 8)
	f.aside = Shop.Text(f, UI.TextFont(10), C.dim)
	f.aside:SetPoint("LEFT", f.value, "RIGHT", 6, -1)
	return f
end

local function Build(frame)
	page = frame
	figures = {}
	for i = 1, 3 do figures[i] = Figure(page) end
	figures[1].word:SetText("LISTED")
	figures[2].word:SetText("UNDERCUT")
	figures[3].word:SetText("SOLD")
	scroll = UI.ScrollArea(page, 600, 300, { quiet = true, smooth = true })
	scroll:SetPoint("TOPLEFT", 12, -(L.figure + 14))
	scroll:SetPoint("BOTTOMRIGHT", -12, 6)
	list = P.List(scroll, { height = L.row, spark = false })
	page:SetScript("OnShow", function() ns.Owned() end)
end

-- A row's own pieces: time left as a bar, Cancel.
local function Dress(row)
	if row.cancel then return end
	row.bar = CreateFrame("Frame", nil, row)
	row.bar:SetSize(70, 4)
	row.bar:SetPoint("RIGHT", -96, -6)
	row.bar.well = row.bar:CreateTexture(nil, "BACKGROUND")
	row.bar.well:SetAllPoints()
	row.bar.well:SetColorTexture(0, 0, 0, 0.55)
	row.bar.fill = row.bar:CreateTexture(nil, "ARTWORK")
	row.bar.fill:SetPoint("TOPLEFT")
	row.bar.fill:SetPoint("BOTTOMLEFT")
	row.bar.fill:SetColorTexture(1, 1, 1, 1)
	row.left = Shop.Text(row, UI.TextFont(10), C.dim)
	row.left:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", 0, 3)
	row.cancel = Shop.Button(row, nil, function(b)
		local id = b:GetParent().auctionID
		if id then
			ns.Note("CancelAuction", id)
			C_AuctionHouse.CancelAuction(id)
		end
	end)
	row.cancel:Say("Cancel")
	row.cancel:SetPoint("RIGHT", -8, 0)
	row.money:ClearAllPoints()
	row.money:SetPoint("TOPLEFT", row, "TOPLEFT", 300, -7)
	row.word:ClearAllPoints()
	row.word:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 300, 7)
	row.word:SetJustifyH("LEFT")
	row.money:SetJustifyH("LEFT")
	row.name:ClearAllPoints()
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
	row.name:SetWidth(250)
end

local function Draw(frame, width, height)
	Read()
	local onHouse, listings, under, sold, soldGold = 0, 0, 0, 0, 0
	for _, a in ipairs(mine) do
		if a.sold then
			sold, soldGold = sold + 1, soldGold + a.buyout
		else
			onHouse, listings = onHouse + a.buyout, listings + 1
			if a.under then under = under + 1 end
		end
	end
	local each = math.floor((width - 24 - 20) / 3)
	for i, f in ipairs(figures) do
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", 12 + (i - 1) * (each + 10), -4)
		f:SetWidth(each)
	end
	figures[1].value:SetText(UI.Money(onHouse, true, 16, figures[1].value))
	figures[1].aside:SetText(("%d listings"):format(listings))
	figures[2].value:SetText(tostring(under))
	figures[2].aside:SetText(under > 0 and "cancel and post again, or let them run out" or "you're the cheapest")
	UI.SetBorder(figures[2], under > 0 and C.bad or C.border)
	figures[3].value:SetText(sold > 0 and UI.Money(soldGold, true, 16, figures[3].value) or "0")
	figures[3].aside:SetText(sold > 0 and "the gold is in your mail" or "")
	UI.SetBorder(figures[3], sold > 0 and C.alert or C.border)

	scroll.content:SetWidth(width - 24 - 14)
	list:Lay(#mine, function(row, i)
		local a = mine[i]
		Dress(row)
		row.auctionID = a.id
		row:Item(a.item, a.quantity)
		row:Say(("%d in the listing · %s in all"):format(a.quantity, UI.Money(a.buyout, true, 10, row.sub)))
		row.money:SetText(("%s each"):format(UI.Money(a.unit, true, 12, row.money)))
		if a.sold then
			row.word:SetText("sold, the gold is in your mail")
			UI.Ink(row.word, C.alert)
		elseif a.under then
			local soon = a.left and a.left < L.soon
			row.word:SetText(("%s is lower: %s"):format(UI.Money(a.under, true, 10, row.word), soon and "let it run out" or "cancel, post again"))
			UI.Ink(row.word, C.bad)
		else
			row.word:SetText("the cheapest")
			UI.Ink(row.word, C.good)
		end
		row.cancel:SetShown(not a.sold)
		row.bar:SetShown(not a.sold and a.left ~= nil)
		row.left:SetShown(not a.sold and a.left ~= nil)
		if a.left and not a.sold then
			local hours = a.left / 3600
			row.left:SetText(hours >= 1 and ("%d h left"):format(math.floor(hours)) or ("%d min left"):format(math.ceil(a.left / 60)))
			row.bar.fill:SetWidth(math.max(1, 70 * math.min(1, a.left / (24 * 3600))))
			Shy.Theme.Tint(row.bar.fill, Shy.Theme.Accent)
		end
		row:Pick(false)
	end, height - 72)
	scroll:Update()
end

local function Count()
	local sold = 0
	for _, a in ipairs(mine) do
		if a.sold then sold = sold + 1 end
	end
	return sold, sold > 0
end

ns.AddPage({ key = "auctions", label = "Auctions", order = 3, Build = Build, Draw = Draw, Count = Count })
-- (Exposed for inspection.)
ns.AuctionsPage = { Parts = function() return list, figures end }

local events = CreateFrame("Frame")
for _, event in ipairs({ "OWNED_AUCTIONS_UPDATED", "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_SHOW" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", Shy.Clocked("auction: your auctions", function(_, event)
	if event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_CANCELED" or event == "AUCTION_HOUSE_AUCTION_CREATED" then
		ns.Owned()
	else
		Read()
		ns.Window.Stale()
	end
end))
