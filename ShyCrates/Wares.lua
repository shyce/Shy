-- The crates' foot, laid as the auction house's scan bar is: its mark and words at the left, what to get in the middle
-- (each thing's slot, how many and its price, in the crates' order, what you bought ticked off where it stands), and
-- one button at the right end that goes through it all, a click at a time:
--   "buy" (the auction house's Crates page): Buy next asks the price of the next thing, all your crates take of it;
--          Pay pays it. Greyed while the price is asked and while it is bought. A chip asks for its own thing.
--   "fill" (the crates window): Fill next, the game's own button, fills the next crate ready (else opens the next);
--          greyed, counting the cast down, while one fills.
--   local foot = ns.Wares.New(band, L, kind)   L: the scan bar's measures (pad, market, button, buttonHeight)
--   foot:Draw(width, upcoming)                  upcoming: the list's row to fill next (List's Upcoming), for "fill"
--   foot:Tick()                                 a cast's tenth: the countdown alone

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors
local Shop = Shy.Shop
local Slot = Shy.Slot
local Plan = ns.Plan

local Wares = {}
ns.Wares = Wares
local Meta = {}
Meta.__index = Meta

local K = { chip = 150, gap = 8, emblem = 26, more = 50 }
local DOT = "  \194\183  "
local KEYS = { "type", "item", "target-bag", "target-slot" }

local function Name(item)
	local name = C_Item.GetItemNameByID(item)
	if not name then C_Item.RequestLoadItemDataByID(item) end
	return name or ""
end

local function Money(copper, at)
	return UI.Money(math.floor(copper + 0.5), true, nil, at)
end

local function Auction()
	local auction = Shy.addons.Auction
	return auction and auction.IsOpen and auction:IsOpen() and auction or nil
end

-- A first press asks the price of count of item; a second, with that price on the button, pays it.
local function Buy(item, count)
	local auction = Auction()
	if not auction then return end
	local quoted, many, total, paying = auction:Quoted()
	if quoted == item and many == count then
		if total and not paying then auction:Pay() end
		return
	end
	auction:Quote(item, count)
end

local function Chip(foot)
	local chip = CreateFrame("Button", nil, foot.band)
	chip:SetSize(K.chip, Slot.SIZES.medium)
	chip.icon = chip:CreateTexture(nil, "ARTWORK")
	chip.icon:SetSize(Slot.SIZES.medium, Slot.SIZES.medium)
	chip.icon:SetPoint("LEFT")
	chip.slot = Slot.New(chip, { to = chip.icon, icon = chip.icon, size = Slot.SIZES.medium })
	chip.light = chip:CreateTexture(nil, "ARTWORK", nil, 5)
	chip.slot:Light(chip.light)
	Shy.Theme.Tint(chip.light, Shy.Theme.Accent)
	chip.name = Shop.Text(chip, UI.NameFont(11), C.text)
	chip.name:SetPoint("TOPLEFT", chip.icon, "TOPRIGHT", 7, -1)
	chip.name:SetPoint("RIGHT")
	chip.money = Shop.Text(chip, UI.NameFont(11), C.text)
	chip.money:SetPoint("BOTTOMLEFT", chip.icon, "BOTTOMRIGHT", 7, 1)
	chip:SetScript("OnEnter", function(self)
		UI.GameTipAt(self):SetItemByID(self.item)
		GameTooltip:Show()
	end)
	chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	chip:SetScript("OnClick", function(self)
		if not (Auction() and self.count > 0) then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Buy(self.item, self.count)
	end)
	return chip
end

-- The game's own button, in the make of the family's gold one (the crates window's Fill next).
local function SecureButton(foot, band, L)
	local b = CreateFrame("Button", nil, band, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetSize(L.button, L.buttonHeight)
	b:SetPoint("RIGHT", -L.pad, 0)
	b.text = Shop.Text(b, UI.NameFont(12), C.text)
	b.text:SetPoint("CENTER")
	UI.KeyPress(b, { tone = C.alert, words = b.text, sink = { b.text } })
	b:HookScript("PostClick", function(_, _, down)
		if down then return ns.Cast.Pressed(foot.upcoming and foot.upcoming.crate) end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end)
	return b
end

function Wares.New(band, L, kind)
	local foot = setmetatable({ band = band, L = L, kind = kind, chips = {} }, Meta)
	foot.emblem = band:CreateTexture(nil, "ARTWORK")
	foot.emblem:SetSize(K.emblem, K.emblem)
	foot.emblem:SetPoint("LEFT", L.pad, 0)
	Shy.Theme.Icon(foot.emblem, T.mark, K.emblem)
	foot.title = Shop.Text(band, UI.TitleFont(14), C.head)
	foot.title:SetPoint("BOTTOMLEFT", foot.emblem, "RIGHT", 8, 0)
	foot.title:SetText("Shopping list")
	foot.sub = Shop.Text(band, UI.TextFont(10), C.dim)
	foot.sub:SetPoint("TOPLEFT", foot.title, "BOTTOMLEFT", 0, -2)
	foot.more = Shop.Text(band, UI.TextFont(10), C.dim)
	if kind == "buy" then
		foot.button = UI.Button(band, "Buy next", L.button, function() foot:Press() end)
		foot.button:SetHeight(L.buttonHeight)
		foot.button:SetPoint("RIGHT", -L.pad, 0)
	elseif kind == "fill" then
		foot.button = SecureButton(foot, band, L)
	end
	return foot
end

-- Buy next: the thing a quote stands for, else the first not bought yet.
function Meta:Next(wares)
	local auction = Auction()
	local quoted = auction and auction:Quoted()
	local first
	for i, w in ipairs(wares) do
		if w.item == quoted and not w.done then return w, i end
		if not first and not w.done then first = i end
	end
	if first then return wares[first], first end
end

function Meta:Press()
	local next = self:Next(Plan.Shopping())
	if next then Buy(next.item, next.count) end
end

-- The chips, from a little before the one up next, as many as the middle holds, in columns of one width.
function Meta:DrawChips(width, wares, lit)
	local L, band = self.L, self.band
	local right = self.button and (L.pad + L.button + 12) or L.pad
	local room = width - 4 - L.market - right
	local fits = math.max(1, math.floor((room + K.gap) / (K.chip + K.gap)))
	if fits < #wares then fits = math.max(1, math.floor((room - K.more + K.gap) / (K.chip + K.gap))) end
	local from = math.max(1, math.min((lit or 1) - 1, #wares - fits + 1))
	local shown = 0
	for i = from, math.min(#wares, from + fits - 1) do
		shown = shown + 1
		local chip = self.chips[shown] or Chip(self)
		self.chips[shown] = chip
		local w = wares[i]
		chip.item, chip.count = w.item, w.count
		chip.icon:SetTexture(C_Item.GetItemIconByID(w.item) or 134400)
		chip.slot:Quality(C_Item.GetItemQualityByID(w.item))
		chip.slot:Dim(w.done)
		chip.name:SetText(("%d %s"):format(w.done and w.bought or w.count, Name(w.item)))
		UI.Ink(chip.name, w.done and C.dim or C.text)
		if w.done then
			chip.money:SetText("Bought")
			UI.Ink(chip.money, C.good)
		else
			chip.money:SetText(w.cost and Money(w.cost, chip.money) or "no price")
			UI.Ink(chip.money, w.cost and C.text or C.dim)
		end
		chip.light:SetShown(i == lit)
		chip:ClearAllPoints()
		chip:SetPoint("LEFT", band, "LEFT", L.market + (shown - 1) * (K.chip + K.gap), 0)
		chip:Show()
	end
	for i = shown + 1, #self.chips do self.chips[i]:Hide() end
	local rest = #wares - shown
	self.more:SetShown(rest > 0)
	if rest > 0 then
		self.more:ClearAllPoints()
		self.more:SetPoint("LEFT", band, "LEFT", L.market + shown * (K.chip + K.gap), 0)
		self.more:SetText(("+%d more"):format(rest))
	end
end

-- Buy next, in its state: the price asked, the price to pay, the thing being bought, or all of it bought.
function Meta:DrawBuy(wares, next)
	local b = self.button
	b:SetShown(#wares > 0)
	if #wares == 0 then return end
	local auction = Auction()
	local quoted, many, total, paying
	if auction then quoted, many, total, paying = auction:Quoted() end
	if not auction then
		b:SetLabel("Buy next")
		b:SetUsable(false, "Only at the auction house.")
	elseif not next then
		b:SetLabel("All bought")
		b:SetUsable(false)
	elseif quoted == next.item and many == next.count then
		b:SetLabel(paying and "Buying..." or total and ("Pay " .. Money(total)) or "Getting price...")
		b:SetUsable(total ~= nil and not paying)
	else
		b:SetLabel("Buy next")
		b:SetUsable(true)
	end
	b:SetPrimary(true)
end

-- Fill next, the game's own: the next crate's action, or greyed and counting down while one fills.
function Meta:DrawFill(upcoming)
	local b = self.button
	if InCombatLockdown() then return end
	local crate, left = ns.Cast.Now()
	local words, attrs
	if crate then
		words = ("%s %.1f"):format(Plan.Is(crate) == "unread" and "Opening" or "Filling", left)
	elseif upcoming then
		words, attrs = upcoming.pick and "Fill next" or "Open next", upcoming.next
	else
		words = "Nothing to fill"
	end
	b.text:SetText(words)
	if b.attrs ~= attrs then
		b.attrs = attrs
		for _, key in ipairs(KEYS) do b:SetAttribute(key, attrs and attrs[key] or nil) end
	end
	b:SetAlpha(attrs and 1 or 0.4)
end

function Meta:Draw(width, upcoming)
	self.width, self.upcoming = width, upcoming
	local wares, total, left = Plan.Shopping()
	local done = #wares - left
	local words
	if #wares == 0 then
		words = Plan.Held().labels[1] and "You have everything" or "No crates to fill"
	elseif done > 0 then
		words = (left == 0 and "All bought" or ("%d of %d bought"):format(done, #wares))
			.. (left > 0 and total and (DOT .. Money(total, self.sub) .. " to go") or "")
	else
		words = (#wares == 1 and "1 item" or ("%d items"):format(#wares)) .. (total and (DOT .. Money(total, self.sub)) or "")
	end
	self.sub:SetText(words)
	local next, at = self:Next(wares)
	self:DrawChips(width, wares, self.kind == "buy" and Auction() and at or nil)
	if self.kind == "buy" then self:DrawBuy(wares, next)
	elseif self.kind == "fill" then self:DrawFill(upcoming) end
end

function Meta:Tick()
	if self.kind == "fill" then self:DrawFill(self.upcoming) end
end
