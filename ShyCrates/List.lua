-- The crates you hold, a row a label (or a crate still to open): its bundles, the gold to finish every crate of it in a
-- column of its own, and, where you fill them, Fill or Open: the game's own secure button, so a click is the game's.
-- Those stand only in a secure window (Window.lua), which steps aside in a fight; nothing about them is touched then.
-- On the auction house's Crates page it has no buttons: what you buy there comes by mail.
--   local list = ns.List.New(parent, fills)    fills: rows with Fill and Open
--   list:Draw(width, height)                   lays it for that room

local ADDON, ns = ...
local UI = Shy.UI
local C = UI.colors
local Theme = Shy.Theme
local Shop = Shy.Shop
local Slot = Shy.Slot
local Plan = ns.Plan

-- row: a crate's; money: its column of gold; act: its button's.
-- The columns, the same on every row: the crate, its name (name), its bundles from one place, the status (status: the
-- headline over the detail), and Fill (act).
local L = { row = 44, pad = 8, gap = 6, name = 176, status = 76, act = 58, actHeight = 22, between = 12 }
local DOT = " \194\183 "

local List = {}
ns.List = List
local Meta = {}
Meta.__index = Meta

local function Auction()
	local auction = Shy.addons.Auction
	return auction and auction.IsOpen and auction:IsOpen() and auction or nil
end

local function Name(item)
	local name = C_Item.GetItemNameByID(item)
	if not name then C_Item.RequestLoadItemDataByID(item) end
	return name or ""
end

-- A label's own words: what comes after the crate's name ("Apprentice Herbs").
local function Label(crate)
	local name = Name(crate)
	return name:match("^[^:]+:%s*(.+)$") or name
end

local function Money(copper, at)
	return UI.Money(math.floor(copper + 0.5), true, nil, at)
end

-- A secure button's attributes: kept while they say the same, so the button isn't set afresh each draw.
local function Attrs(holder, kind, bag, slot, onBag, onSlot)
	local key = ("%s %d %d %s %s"):format(kind, bag, slot, tostring(onBag), tostring(onSlot))
	if holder.attrsKey ~= key then
		holder.attrsKey = key
		holder.attrs = { type = "item", item = ("%d %d"):format(bag, slot), ["target-bag"] = onBag, ["target-slot"] = onSlot }
	end
	return holder.attrs
end

-- An item's slot with a count on it and its tooltip under the mouse.
local function Ware(parent, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.slot = Slot.New(b, { to = b.icon, icon = b.icon, size = size })
	b.count = Shop.Text(b, UI.NameFont(9), C.text)
	b.slot:Count(b.count)
	b:SetScript("OnEnter", function(self)
		UI.GameTipAt(self):SetItemByID(self.item)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	function b:Item(item, count)
		self.item = item
		self.icon:SetTexture(C_Item.GetItemIconByID(item) or 134400)
		self.slot:Quality(C_Item.GetItemQualityByID(item))
		self.count:SetText(count or "")
	end
	return b
end

-- A bundle in a row's strip: lit when you hold enough for a crate, marked when it's the one picked.
local function Bundle(row)
	local b = Ware(row, Slot.SIZES.small)
	b.light = b:CreateTexture(nil, "ARTWORK", nil, 5)
	b.slot:Light(b.light)
	Theme.Tint(b.light, Theme.Accent)
	b.bar = b:CreateTexture(nil, "OVERLAY")
	b.bar:SetHeight(2)
	b.bar:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -3)
	b.bar:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -2, -3)
	b.bar:SetColorTexture(1, 1, 1, 1)
	Theme.Tint(b.bar, Theme.Accent)
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Plan.SetPick(row.crate, self.item)
	end)
	function b:Set(bundle, picked)
		self:Item(bundle.item, bundle.need)
		self.slot:Dim(not bundle.ready)
		UI.Ink(self.count, bundle.ready and C.good or C.text)
		self.light:SetShown(picked)
		self.bar:SetShown(picked)
	end
	return b
end

local function Row(list, fills)
	local row = CreateFrame("Button", nil, list.content)
	row:SetHeight(L.row)
	row.rule = Shop.Rule(row)
	row.rule:SetPoint("BOTTOMLEFT")
	row.rule:SetPoint("BOTTOMRIGHT")
	row.hot = row:CreateTexture(nil, "BACKGROUND")
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.hot, 0.06)
	row.hot:Hide()
	local size = Slot.SIZES.medium
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(size, size)
	row.icon:SetPoint("LEFT", L.pad, 0)
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, size = size, hover = false })
	row.count = Shop.Text(row, UI.NameFont(10), C.text)
	row.slot:Count(row.count)
	-- The columns from the right: the button where you fill them, then the gold (its figures to one edge, a word under).
	if fills then
		-- The game's own button, in the make of the family's gold one: a click uses the crate, aimed at the stack.
		local act = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
		act:RegisterForClicks("AnyUp", "AnyDown")
		act:SetSize(L.act, L.actHeight)
		act:SetPoint("RIGHT", -L.pad, 0)
		act.text = Shop.Text(act, UI.NameFont(11), C.text)
		act.text:SetPoint("CENTER")
		UI.KeyPress(act, { tone = C.alert, words = act.text, sink = { act.text } })
		act:HookScript("PostClick", function(_, _, down)
			if down then return ns.Cast.Pressed(row.crate) end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end)
		act:Hide()
		row.act = act
	end
	row.fills = fills
	local edge = fills and -(L.pad + L.act + L.between) or -L.pad
	row.edge = edge
	row.money = Shop.Text(row, UI.NameFont(12), C.text)
	row.money:SetJustifyH("RIGHT")
	row.money:SetWidth(L.status)
	row.word = Shop.Text(row, UI.NameFont(10), C.dim)
	row.word:SetJustifyH("RIGHT")
	row.word:SetPoint("BOTTOMRIGHT", edge, 7)
	row.word:SetWidth(L.status)
	row.name = Shop.Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
	row.name:SetWidth(L.name)
	row.sub = Shop.Text(row, UI.TextFont(10), C.dim)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
	row.sub:SetWidth(L.name)
	row.strip = L.pad + Slot.SIZES.medium + 8 + L.name + L.between   -- where the bundles start, from the left
	row.bundles = {}
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if not self.bag then return end
		UI.GameTipAt(self, self.icon):SetBagItem(self.bag, self.slotIndex)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	return row
end

-- A row's button: shown with its words, or not at all; attrs: what the game does on a click (nil: nothing, dimmed).
-- Set again only when they change, and never in a fight.
local KEYS = { "type", "item", "target-bag", "target-slot" }
local function RowAct(row, words, attrs)
	local act = row.act
	if not act or InCombatLockdown() then return end
	act:SetShown(words ~= nil)
	if not words then return end
	act.text:SetText(words)
	if act.attrs ~= attrs then
		act.attrs = attrs
		for _, key in ipairs(KEYS) do act:SetAttribute(key, attrs and attrs[key] or nil) end
	end
	act:SetAlpha(attrs and 1 or 0.4)
end

-- The crate being filled (or opened): its button greyed, counting the cast down.
local function Countdown(left) return ("%.1f"):format(left) end
local function Act(row, words, attrs)
	row.next = words and attrs or nil
	local crate, left = ns.Cast.Now()
	if words and crate == row.crate then return RowAct(row, Countdown(left), nil) end
	RowAct(row, words, attrs)
end

-- The status column: a headline alone on the row's middle line (level with Fill), or over its detail.
local function Column(row, head, color, detail)
	local lines = detail and 2 or 1
	if row.lines ~= lines then
		row.lines = lines
		row.money:ClearAllPoints()
		if lines == 2 then row.money:SetPoint("TOPRIGHT", row.edge, -7) else row.money:SetPoint("RIGHT", row.edge, 0) end
	end
	row.money:SetText(head or "")
	UI.Ink(row.money, color or C.text)
	row.word:SetText(detail or "")
end

local function FillUnread(row, at)
	row.crate, row.bag, row.slotIndex, row.pick = at.item, at.bag, at.slot, nil
	row.icon:SetTexture(C_Item.GetItemIconByID(at.item) or 134400)
	row.slot:Quality(C_Item.GetItemQualityByID(at.item))
	row.count:SetText(at.count > 1 and at.count or "")
	row.name:SetText(Name(at.item))
	row.sub:SetText("Open it to see what it needs")
	for _, b in ipairs(row.bundles) do b:Hide() end
	Column(row, nil, nil, nil)
	Act(row, "Open", Attrs(row, "read", at.bag, at.slot))
end

-- Under the name: the bundle used (lit in the strip), and where else you have some of it.
local function Says(pick)
	local said = ("%d %s a crate"):format(pick.need, Name(pick.item))
	if pick.mailed > 0 then said = said .. DOT .. ("%d in the mail"):format(pick.mailed) end
	if pick.banked > 0 then said = said .. DOT .. ("%d in the bank"):format(pick.banked) end
	return said
end

-- The status says what Fill can't: the gold for what is still short, over how many. Where nothing is short, the
-- Fill button says it all; on the auction house's page, which has none, Ready (or Bought: on its way by mail).
local function Status(row, pick, count)
	if pick.short > 0 then
		local head = pick.finish and Money(pick.finish, row.money) or "No price"
		return Column(row, head, pick.finish and C.text or C.dim, ("need %d"):format(pick.short))
	end
	if row.fills then return Column(row, nil) end
	Column(row, pick.fills >= count and "Ready" or "Bought", C.good)
end

local function FillLabel(row, at)
	local crate = at.crate
	row.crate, row.bag, row.slotIndex = crate, at.bag, at.slot
	row.icon:SetTexture(C_Item.GetItemIconByID(crate) or 134400)
	row.slot:Quality(C_Item.GetItemQualityByID(crate))
	row.count:SetText(at.count > 1 and at.count or "")
	row.name:SetText(Label(crate))
	local bundles = Plan.Of(crate)
	local pick = Plan.Pick(crate)
	row.pick = pick
	-- The strip from one place on every row, the plan's order left to right: the first bundle under the first.
	local step = Slot.SIZES.small + L.gap
	for i, bundle in ipairs(bundles) do
		local b = row.bundles[i] or Bundle(row)
		row.bundles[i] = b
		b:ClearAllPoints()
		b:SetPoint("LEFT", row, "LEFT", row.strip + (i - 1) * step, 0)
		b:Set(bundle, bundle == pick)
		b:Show()
	end
	for i = #bundles + 1, #row.bundles do row.bundles[i]:Hide() end
	row.sub:SetText(Says(pick))
	Status(row, pick, at.count)

	if not pick.ready then return Act(row, nil) end
	local bag, slot = Plan.Stack(pick.item)
	Act(row, "Fill", bag and Attrs(row, "fill", at.bag, at.slot, bag, slot) or nil)
end

function List.New(parent, fills)
	local list = setmetatable({ parent = parent, rows = {}, entries = {}, width = 600, height = 300, fills = fills }, Meta)
	list.scroll = UI.ScrollArea(parent, 300, 300, { quiet = true, smooth = true })
	list.scroll:SetPoint("TOPLEFT")
	list.content = list.scroll.content
	list.empty = Shop.Text(parent, UI.TextFont(12), C.dim)
	list.empty:SetPoint("CENTER", list.scroll, "CENTER", 0, 0)
	list.empty:SetText("No Waylaid Crates in your bags.")
	return list
end

function Meta:Draw(width, height)
	-- (Rows with the game's buttons are laid out of a fight only: their window is away in one.)
	if self.fills and InCombatLockdown() then return end
	self.width, self.height = width, height
	local held = Plan.Held()
	local entries = self.entries
	wipe(entries)
	if held.unread then entries[1] = held.unread end
	for _, at in ipairs(held.labels) do entries[#entries + 1] = at end

	self.scroll:SetSize(width, height)
	self.content:SetWidth(width - 10)   -- (room for its bar)
	for i, at in ipairs(entries) do
		local row = self.rows[i] or Row(self, self.fills)
		self.rows[i] = row
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(i - 1) * L.row)
		row:SetPoint("RIGHT")
		if at.crate then FillLabel(row, at) else FillUnread(row, at) end
		row:Show()
	end
	for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
	self.content:SetHeight(math.max(1, #entries * L.row))
	self.scroll:Update()
	self.empty:SetShown(#entries == 0)
end

-- A cast's every tenth: only the crate being filled is drawn again, its countdown.
function Meta:Tick()
	if InCombatLockdown() then return end
	local crate, left = ns.Cast.Now()
	if not crate then return end
	for _, row in ipairs(self.rows) do
		if row:IsShown() and row.act and row.act:IsShown() and row.crate == crate then RowAct(row, Countdown(left), nil) end
	end
end

-- The footer's: the first crate ready to fill, else the first to open. { words, attrs, crate } or nil.
function Meta:Upcoming()
	local opening
	for _, row in ipairs(self.rows) do
		if row:IsShown() and row.next then
			if row.pick then return row end
			opening = opening or row
		end
	end
	return opening
end
