-- Your auctions, in a window of their own beside the bags window: docked to its side and moving with it, or wherever
-- it is dragged (dragged back near either side, it docks there again; Shy.HUD's `dock`). It shows the auctions of the
-- character the bags window shows, as last seen at an auctioneer, and answers what you look at them for:
--   along its top, three figures: the gold sold and on its way to your mail, what your listings come to on the house,
--   and how many are undercut (with the auction house's prices, ShyAuction's: yours only, as its prices are your
--   market's);
--   then each under the family's group heads, in the order you act on them: sold, undercut (cancel and post again:
--   an auction can't be reposted in place), on the house (how long each has left, a meter of it), and back in your
--   mail (run out). A row: the item in its quality's color and count, its price each and all of it, and its time or
--   what it sold for; an undercut one the cheapest now. Its card on hover, standing off the row's top right
--   corner, clear of the row.
--   Its foot: when they were seen, and at an auctioneer, your auctions at the auction house (ShyAuction's page).
-- The bags' auctions door and menu open and close it; closing the bags closes it.
--   AuctionWindow.Toggle()   AuctionWindow.IsShown()   AuctionWindow.Refresh()

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors
local Store, Takeover, Window, Views = ns.Store, ns.Takeover, ns.Window, ns.Views

local AuctionWindow = {}
ns.AuctionWindow = AuctionWindow

local L = {
	w = 372, edge = 8, top = 35,           -- the window's width, its margin, the list's top under the head
	figures = 48, figGap = 10,             -- the three figures' band: a word, the figure, a line under it
	row = 36, slot = 26, most = 9,         -- a row, its picture, the most rows before the list scrolls
	head = 26, between = 4,                -- a group's head, and the room after a group
	foot = 17, meter = 64, day = 86400,    -- the foot; a time-left meter, and what fills it (a day)
	side = 104,                            -- a row's right column: its time over the meter
}
local GROUPS = {
	{ key = "sold", name = "Sold", say = "On its way to your mail" },
	{ key = "under", name = "Undercut", say = "Cancel and post again" },
	{ key = "up", name = "On the house" },
	{ key = "back", name = "Back in your mail", say = "Ran out" },
}
local WORDS = {
	title = "Auctions", theirs = "%s auctions", soldHead = "SOLD", upHead = "ON THE HOUSE", underHead = "UNDERCUT",
	coming = "on its way to your mail", nothingSold = "nothing yet", listings = "%d listings", listing = "1 listing",
	cancel = "cancel and post again", cheapest = "you're the cheapest", noPrices = "no prices yet",
	inMail = "on its way to you", toCancel = "to cancel, post again", allCheapest = "you're the cheapest",
	each = "%s each  \194\183  %s in all", back = "in your mailbox",
	soldAgo = "sold %s", yours = "yours %s  \194\183  cheapest %s", seen = "seen %s", live = "at the auction house now",
	notSeen = "Not seen yet. Visit an auctioneer on %s once.", none = "No auctions.",
	open = "Open at the auction house", visit = "update at an auctioneer",
}

local box, win
local P = {}
local wanted = false
local folds = {}        -- group -> folded, for the session
local building = false

local function Coins(copper, size, at)
	return UI.Money(math.floor((copper or 0) + 0.5), true, size, at)
end

-- What the window shows: the character the bags window shows, while it is up and asked for.
local function Showing()
	if not (wanted and Takeover.IsOn() and Takeover.Visible()) then return nil end
	return Window.Looked()
end

function AuctionWindow.IsShown()
	return box ~= nil and box:IsShown()
end

-- An auction as the window reads it: price each and all of it (the house gives a listing's price each and a sale's
-- whole), and the auction house's cheapest where it is below yours.
local function Read(c, isMe)
	local now = ns.Now()
	local auction = Shy.addons.Auction
	local groups = { sold = {}, under = {}, up = {}, back = {} }
	local sold, up, under = 0, 0, 0
	for _, a in ipairs(c.auctions or {}) do
		local id = Store.ItemID(a.item)
		local n = math.max(1, a.n or 1)
		local price = a.buyout or a.bid or 0
		local r = { a = a, id = id, n = n }
		if a.sold then
			r.all, r.each = price, price / n
			sold = sold + price
			table.insert(groups.sold, r)
		else
			r.each, r.all = price, price * n
			if a.exp and a.exp <= now then
				table.insert(groups.back, r)
			else
				up = up + r.all
				local book = isMe and auction and id and auction:Price(id)
				if book and book.unit and book.unit < r.each then
					r.cheapest = book.unit
					under = under + 1
					table.insert(groups.under, r)
				else
					table.insert(groups.up, r)
				end
			end
		end
	end
	-- Sold newest first; on the house by the time left, the soonest first.
	table.sort(groups.sold, function(x, y) return (x.a.soldAt or 0) > (y.a.soldAt or 0) end)
	for _, key in ipairs({ "under", "up" }) do
		table.sort(groups[key], function(x, y) return (x.a.exp or math.huge) < (y.a.exp or math.huge) end)
	end
	return groups, { sold = sold, up = up, under = under, listed = #groups.up + #groups.under, priced = auction ~= nil and isMe }
end

-- Building

local function Figure(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(L.figures)
	-- Three lines, each the cell's width: the word, the figure, what it means.
	f.label = Window.Rounded(f, 9, C.dim)
	f.label:SetPoint("TOPLEFT", 0, -3)
	f.label:SetPoint("RIGHT", f, "RIGHT", -2, 0)
	f.label:SetJustifyH("LEFT")
	f.label:SetWordWrap(false)
	f.value = Window.Rounded(f, 15)
	f.value:SetPoint("TOPLEFT", 0, -14)
	f.value:SetPoint("RIGHT", f, "RIGHT", -2, 0)
	f.value:SetJustifyH("LEFT")
	f.value:SetWordWrap(false)
	f.sub = Window.Rounded(f, 10, C.dim)
	f.sub:SetPoint("TOPLEFT", 0, -33)
	f.sub:SetPoint("RIGHT", f, "RIGHT", -2, 0)
	f.sub:SetJustifyH("LEFT")
	f.sub:SetWordWrap(false)
	f.rule = f:CreateTexture(nil, "ARTWORK")
	f.rule:SetWidth(1)
	f.rule:SetPoint("TOPLEFT", -L.figGap / 2, -4)
	f.rule:SetPoint("BOTTOMLEFT", -L.figGap / 2, 4)
	UI.Paint(f.rule, C.border, 0.7)
	return f
end

local function Row(i)
	local row = P.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, P.list.content)
	row:SetHeight(L.row)
	row.hot = row:CreateTexture(nil, "BACKGROUND")
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.hot, 0.08)
	row.hot:Hide()
	row.pic = CreateFrame("Frame", nil, row)
	row.pic:SetSize(L.slot, L.slot)
	row.pic:SetPoint("LEFT", 2, 0)
	row.icon = row.pic:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.slot = Shy.Slot.New(row.pic, { icon = row.icon, size = L.slot, hover = false })
	row.count = row.pic:CreateFontString(nil, "OVERLAY")
	row.slot:Count(row.count)
	-- At the right: how long it has left (or when it sold) over a meter of the day; nothing else stands there.
	row.right = Window.Rounded(row, 10.5, C.dim)
	row.right:SetPoint("TOPRIGHT", -4, -6)
	row.right:SetJustifyH("RIGHT")
	row.track = row:CreateTexture(nil, "ARTWORK")
	row.track:SetSize(L.meter, 3)
	row.track:SetPoint("BOTTOMRIGHT", -4, 9)
	UI.Paint(row.track, C.bg, 1)
	row.fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.fill:SetHeight(3)
	row.fill:SetPoint("LEFT", row.track, "LEFT")
	row.fill:SetColorTexture(1, 1, 1, 1)
	-- At the left: the name, and under it the price, once.
	row.name = Window.Rounded(row, 12)
	row.name:SetPoint("TOPLEFT", L.slot + 10, -5)
	row.name:SetPoint("RIGHT", row, "RIGHT", -(L.side + 10), 0)
	row.name:SetWordWrap(false)
	row.name:SetJustifyH("LEFT")
	row.sub = Window.Rounded(row, 10, C.dim)
	row.sub:SetPoint("BOTTOMLEFT", L.slot + 10, 6)
	row.sub:SetPoint("RIGHT", row, "RIGHT", -(L.side + 10), 0)
	row.sub:SetWordWrap(false)
	row.sub:SetJustifyH("LEFT")
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if not self.id then return end
		UI.GameTipAt(self)   -- off the row's top right corner: its name stays in sight
		GameTooltip:SetItemByID(self.id)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	P.rows[i] = row
	return row
end

local function Head(i)
	local h = P.heads[i]
	if h then return h end
	h = UI.GroupHead(P.list.content, { height = L.head, rail = 13, gutter = 26, right = 4, foldSize = 18, line = true,
		tip = function(self) return self.name, self.say end,
		click = function(self, button)
			if button ~= "LeftButton" or not self.key then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			folds[self.key] = not folds[self.key] or nil
			AuctionWindow.Refresh()
		end })
	P.heads[i] = h
	return h
end

local function FillRow(row, r, key)
	row.id = r.id
	local _, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(r.id or 0)
	local q, _, _, name = Store.Fact(r.id or 0)
	quality = quality or q
	row.icon:SetTexture(icon or C_Item.GetItemIconByID(r.id or 0) or 134400)
	row.slot:Quality(quality)
	row.count:SetText(r.n > 1 and r.n or "")
	row.name:SetText(name or C_Item.GetItemNameByID(r.id or 0) or "")
	local color = quality and ColorManager.GetColorDataForItemQuality(quality)
	if color then row.name:SetTextColor(color.r, color.g, color.b) else UI.Ink(row.name, C.text) end
	local a = r.a
	local live = key == "up" or key == "under"
	row.track:SetShown(live)
	row.fill:SetShown(live)
	-- The price, once: each and all of it (one alone: its price); undercut, yours against the cheapest now.
	local each, all = Coins(r.each, 10, row.sub), Coins(r.all, 10, row.sub)
	local price = r.n > 1 and WORDS.each:format(each, all) or each
	if key == "under" then
		row.sub:SetText(WORDS.yours:format(each, Coins(r.cheapest, 10, row.sub)))
		UI.Ink(row.sub, C.bad)
	else
		row.sub:SetText(price)
		UI.Ink(row.sub, key == "sold" and C.alert or C.dim)
	end
	if key == "sold" then
		row.right:SetText(a.soldAt and WORDS.soldAgo:format(ns.Ago(a.soldAt)) or WORDS.inMail)
		UI.Ink(row.right, C.alert)
	elseif key == "back" then
		row.right:SetText(WORDS.back)
		UI.Ink(row.right, C.dim)
	else
		local left = a.exp and (a.exp - ns.Now()) or 0
		local words, soon = Views.Left(a.exp or ns.Now())
		local tone = key == "under" and C.bad or ((soon and left < 3 * 3600) and C.alert or C.good)
		row.right:SetText(words)
		UI.Ink(row.right, key == "under" and C.bad or C.dim)
		row.fill:SetWidth(math.max(1, L.meter * math.max(0, math.min(1, left / L.day))))
		UI.Paint(row.fill, tone, 0.9)
	end
	row:SetAlpha(key == "back" and 0.7 or 1)
end

local function Figures(sums, isMe)
	local w = L.w - 2 * L.edge
	local each = math.floor((w - 2 * L.figGap) / 3)
	for i, f in ipairs(P.figures) do
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", L.edge + (i - 1) * (each + L.figGap), -L.top)
		f:SetWidth(each)
		f.rule:SetShown(i > 1)
	end
	local sold, up, under = P.figures[1], P.figures[2], P.figures[3]
	sold.label:SetText(WORDS.soldHead)
	sold.value:SetText(sums.sold > 0 and Coins(sums.sold, 15, sold.value) or "0")
	UI.Ink(sold.value, sums.sold > 0 and C.alert or C.dim)
	sold.sub:SetText(sums.sold > 0 and WORDS.inMail or WORDS.nothingSold)
	up.label:SetText(WORDS.upHead)
	up.value:SetText(Coins(sums.up, 15, up.value))
	UI.Ink(up.value, C.text)
	up.sub:SetText(sums.listed == 1 and WORDS.listing or WORDS.listings:format(sums.listed))
	under.label:SetText(WORDS.underHead)
	under.value:SetText(sums.priced and tostring(sums.under) or "\226\128\147")
	UI.Ink(under.value, sums.under > 0 and C.bad or (sums.priced and C.good or C.dim))
	under.sub:SetText(not sums.priced and WORDS.noPrices or (sums.under > 0 and WORDS.toCancel or WORDS.allCheapest))
end

local function Lay()
	local c, guid, isMe = Showing()
	if not c then return end
	local name = Store.Name(c)
	P.head.title:SetText(isMe and WORDS.title or WORDS.theirs:format(name .. (name:sub(-1) == "s" and "'" or "'s")))
	local groups, sums = Read(c, isMe)
	Figures(sums, isMe)
	local listTop = L.top + L.figures + 6
	-- The groups, each under its head.
	local y, rowAt, headAt = 0, 0, 0
	local width = L.w - 2 * L.edge
	for _, g in ipairs(GROUPS) do
		local list = groups[g.key]
		if #list > 0 then
			headAt = headAt + 1
			local h = Head(headAt)
			h.key, h.name, h.say = g.key, g.name, g.say
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", P.list.content, "TOPLEFT", 0, -y)
			h:SetWidth(width - 6)
			h:Set(g.name)
			local tone = (g.key == "sold" and C.alert) or (g.key == "under" and C.bad) or C.dim
			h:SetBadges({ { text = #list, color = tone } })
			h:SetAccent((g.key == "sold" and C.alert) or (g.key == "under" and C.bad) or nil)
			local open = not folds[g.key]
			h:SetOpen(open)
			h:Show()
			y = y + L.head
			if open then
				local top = y
				local nodes = {}
				for _, r in ipairs(list) do
					rowAt = rowAt + 1
					local row = Row(rowAt)
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", P.list.content, "TOPLEFT", 22, -y)
					row:SetWidth(width - 6 - 22)
					FillRow(row, r, g.key)
					row:Show()
					nodes[#nodes + 1] = y - top + L.head + L.row / 2
					y = y + L.row
				end
				h:Hang(y - top, nodes)
			else
				h:Hang()
			end
			y = y + L.between
		end
	end
	for i = headAt + 1, #P.heads do P.heads[i]:Hide() end
	for i = rowAt + 1, #P.rows do P.rows[i]:Hide() end
	P.none:SetShown(headAt == 0)
	P.none:SetText(c.auctions and WORDS.none or WORDS.notSeen:format(name))
	local tall = math.max(L.row * 2, math.min(y, L.most * L.row))
	P.list.content:SetSize(width, math.max(1, y))
	P.list:ClearAllPoints()
	P.list:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", L.edge, -listTop)
	P.list:SetSize(width, tall)
	P.list:Update()
	P.none:ClearAllPoints()
	P.none:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", L.edge + 4, -(listTop + 8))
	-- The foot.
	local at = Shy.addons.Auction
	local open = isMe and ns.Auctions.IsOpen() and at and at.Show
	P.foot:ClearAllPoints()
	P.foot:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", L.edge, -(listTop + tall + 6))
	P.foot:SetSize(width, L.foot)
	P.seen:SetText(isMe and ns.Auctions.IsOpen() and WORDS.live or (c.auctions and c.auctions.at and WORDS.seen:format(ns.Ago(c.auctions.at)) or ""))
	P.go:SetShown(open and true or false)
	P.hint:SetShown(not open and isMe and c.auctions ~= nil)
	local W, H = L.w, listTop + tall + 6 + L.foot + L.edge
	-- Its content on its body (UI.Body), the window that much bigger than it.
	UI.BodyFit(win, W, H)
	Shy.HUD.Resize(box, win:GetWidth(), win:GetHeight())
end

-- The look keeps another clearance round the body (UI.Body): laid out again, the window that much bigger.
Shy:On("SHY_BODY", function(f)
	if f == win then AuctionWindow.Refresh() end
end)

function AuctionWindow.Refresh()
	if not win or building then return end
	building = true
	Shy.HUD.Update(box)
	local ok, err = true, nil
	if box:IsShown() then ok, err = pcall(Lay) end
	building = false
	if not ok then geterrorhandler()(err) end
end

-- Open or close the auctions of the character the bags window shows.
function AuctionWindow.Toggle()
	wanted = not AuctionWindow.IsShown()
	AuctionWindow.Refresh()
	Window.Refresh()
end

local function Close()
	wanted = false
	AuctionWindow.Refresh()
	Window.Refresh()
end

local function Build()
	box = Shy.HUD.Create({
		id = "shybags.auctions",
		title = "ShyBags auctions",
		width = L.w,
		height = 240,
		point = { "TOP", "CENTER", 0, 200 },
		shown = function() return Showing() ~= nil end,
		window = true,
		hang = true,
		dock = { to = "shybags", side = "RIGHT", label = "Beside the bags" },
	})
	win = CreateFrame("Frame", "ShyBagsAuctions", box)
	win:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	win:SetSize(L.w, 240)
	win:SetToplevel(true)
	win:EnableMouse(true)
	P.head = UI.Head(win, { size = "window", title = WORDS.title, close = Close, panel = { glazed = true } })
	Shy.HUD.DragHandle(box, win)
	P.figures = { Figure(win), Figure(win), Figure(win) }
	P.list = UI.ScrollArea(win, L.w - 2 * L.edge, 200, { quiet = true, smooth = true })
	P.rows, P.heads = {}, {}
	P.none = Window.Rounded(win, 11, C.dim)
	P.none:SetWidth(L.w - 2 * L.edge - 8)
	P.none:SetWordWrap(true)
	P.foot = Window.Plate(win)
	P.seen = Window.Rounded(P.foot, 10.5, C.dim)
	P.seen:SetPoint("LEFT", P.foot, "LEFT", 6, 0)
	P.hint = Window.Rounded(P.foot, 10.5, C.dim)
	P.hint:SetPoint("RIGHT", P.foot, "RIGHT", -6, 0)
	P.hint:SetText(WORDS.visit)
	-- At an auctioneer: your auctions at the auction house.
	P.go = CreateFrame("Button", nil, P.foot)
	P.go:SetHeight(L.foot)
	P.go:SetPoint("RIGHT", P.foot, "RIGHT", -2, 0)
	P.go.text = Window.Rounded(P.go, 10.5, C.head)
	P.go.text:SetPoint("RIGHT", -4, 0)
	P.go.text:SetText(WORDS.open .. " \226\128\186")
	P.go:SetWidth(P.go.text:GetStringWidth() + 8)
	P.go:SetScript("OnEnter", function(self) UI.Ink(self.text, C.text) end)
	P.go:SetScript("OnLeave", function(self) UI.Ink(self.text, C.head) end)
	P.go:SetScript("OnClick", function()
		local at = Shy.addons.Auction
		if at and at.Show then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			at:Show("auctions")
		end
	end)
	P.go:Hide()
end

function AuctionWindow.Init()
	if not (Window.Looked and Shy.HUD.Find("shybags")) then return end   -- the bags window failed to build
	local ok, err = pcall(Build)
	if not ok then
		win = nil
		T:Print("the auctions window failed to load. See your error log.")
		geterrorhandler()(err)
		return
	end
	Takeover.OnChange(function(visible)
		-- Closing the bags puts the auctions away with them.
		if not visible then wanted = false end
		AuctionWindow.Refresh()
	end)
	Shy:On("SHY_BAGS_SCANNED", function(_, source)
		if source == "auctions" or source == "forgotten" then AuctionWindow.Refresh() end
	end)
	-- The auction house's prices changed, or it opened or closed: undercuts and the foot again.
	Shy:On("SHY_AUCTION", function() AuctionWindow.Refresh() end)
	AuctionWindow.Refresh()
end
