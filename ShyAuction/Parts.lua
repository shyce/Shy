-- The pieces the pages share: an item row, a trend line, a section's kicker, the market's word on a price.
--   P.Row(parent, opts)        an item row: slot, name in its quality's color, a second line, money at the right with a
--                              word under it, a trend line; row:Item(id, count), row:Say(name, sub), row:Price(copper,
--                              word, color), row:Trend(prices, color), row:Pick(on); opts.height, opts.click(row)
--   P.Versus(unit, market)     the word for a price against the market and its color: "16% under market" (good)
--   P.Spark(parent)            a trend line: spark:Set(prices, width, height, color)
--   P.Name(item)               the item's name, quality, icon (the game's, asked for when it hasn't them yet)

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local C = UI.colors
local Shop = Shy.Shop

local P = {}
ns.Parts = P

-- With the auction house's item key, as the auction house names it (its own name and quality; gear with its item level).
function P.Name(item, key)
	if key then
		local info = C_AuctionHouse.GetItemKeyInfo(key)
		if info and info.itemName and not issecretvalue(info.itemName) then
			local level = info.isEquipment and key.itemLevel and key.itemLevel > 0 and (" (%d)"):format(key.itemLevel) or ""
			return info.itemName .. level, info.quality or 1, info.iconFileID
		end
	end
	local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(item)
	if not name then
		C_Item.RequestLoadItemDataByID(item)
		return C_Item.GetItemNameByID(item) or ("Item " .. item), 1, C_Item.GetItemIconByID(item)
	end
	return name, quality or 1, icon
end

function P.Versus(unit, market)
	if not (unit and market and market > 0) then return "", C.dim end
	local off = (unit - market) / market
	if math.abs(off) < 0.04 then return "at market", C.dim end
	if off < 0 then return ("%d%% under market"):format(math.floor(-off * 100 + 0.5)), C.good end
	return ("%d%% over"):format(math.floor(off * 100 + 0.5)), C.bad
end

-- A line through a few prices, the last one marked.
function P.Spark(parent)
	local spark = CreateFrame("Frame", nil, parent)
	spark.lines, spark.dot = {}, spark:CreateTexture(nil, "OVERLAY")
	spark.dot:SetSize(4, 4)
	spark.dot:SetColorTexture(1, 1, 1, 1)
	function spark:Set(prices, width, height, color)
		self:SetSize(width, height)
		local n = prices and #prices or 0
		for i = 1, math.max(n - 1, #self.lines) do
			local line = self.lines[i]
			if i < n then
				if not line then
					line = self:CreateLine(nil, "ARTWORK")
					line:SetThickness(1.4)
					self.lines[i] = line
				end
				line:Show()
			elseif line then
				line:Hide()
			end
		end
		self.dot:SetShown(n >= 2)
		if n < 2 then return end
		local lo, hi = math.huge, 0
		for _, p in ipairs(prices) do lo, hi = math.min(lo, p), math.max(hi, p) end
		lo, hi = lo * 0.9, hi * 1.05
		local function At(i)
			return (i - 1) * (width - 4) / (n - 1) + 2, 2 + (prices[i] - lo) / math.max(1, hi - lo) * (height - 4)
		end
		for i = 1, n - 1 do
			local x1, y1 = At(i)
			local x2, y2 = At(i + 1)
			local line = self.lines[i]
			line:SetStartPoint("BOTTOMLEFT", self, x1, y1)
			line:SetEndPoint("BOTTOMLEFT", self, x2, y2)
			line:SetColorTexture(color[1], color[2], color[3], 1)
		end
		local x, y = At(n)
		self.dot:ClearAllPoints()
		self.dot:SetPoint("CENTER", self, "BOTTOMLEFT", x, y)
	end
	return spark
end

-- A picked row: your color washed in from the left, a fine line of it at the edge.
local function Wash(row)
	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetAllPoints()
	row.wash:SetColorTexture(1, 1, 1, 1)
	row.edge = row:CreateTexture(nil, "BORDER")
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(2)
	row.hot = row:CreateTexture(nil, "BACKGROUND")
	row.hot:SetAllPoints()
	row.hot:SetColorTexture(1, 1, 1, 0.04)
	row.hot:Hide()
	function row:Pick(on)
		self.picked = on
		self.wash:SetShown(on)
		self.edge:SetShown(on)
		if on then
			local r, g, b = Theme.AccentSolid()
			self.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.3), CreateColor(r, g, b, 0.06))
			self.edge:SetColorTexture(r, g, b, 1)
		end
	end
	row:Pick(false)
end
P.Wash = Wash

function P.Row(parent, opts)
	opts = opts or {}
	local tall = opts.height or 34
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(tall)
	Wash(row)
	row.rule = Shop.Rule(row)
	row.rule:SetPoint("BOTTOMLEFT")
	row.rule:SetPoint("BOTTOMRIGHT")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(tall - 8, tall - 8)
	row.icon:SetPoint("LEFT", 4, 0)
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = tall - 8, hover = false })
	row.count = Shop.Text(row, UI.NameFont(10), C.text)
	row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 0, 1)
	row.name = Shop.Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
	row.sub = Shop.Text(row, UI.TextFont(10), C.dim)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
	row.spark = P.Spark(row)
	row.spark:SetPoint("RIGHT", -8, 0)
	row.money = Shop.Text(row, UI.NameFont(12), C.text)
	row.money:SetJustifyH("RIGHT")
	row.word = Shop.Text(row, UI.NameFont(10), C.dim)
	row.word:SetJustifyH("RIGHT")
	row.money:SetPoint("TOPRIGHT", -(opts.spark == false and 8 or 74), -5)
	row.word:SetPoint("BOTTOMRIGHT", -(opts.spark == false and 8 or 74), 5)
	row.name:SetPoint("RIGHT", row.money, "LEFT", -8, 0)

	function row:Item(id, count, key)
		self.id, self.key = id, key
		local name, quality, icon = P.Name(id, key)
		self.icon:SetTexture(icon or 134400)
		self.slot:Quality(quality)
		local color = ITEM_QUALITY_COLORS[quality or 1]
		self.name:SetText(name)
		if color then self.name:SetTextColor(color.r, color.g, color.b) end
		self.count:SetText(count and count > 1 and count or "")
	end
	function row:Say(sub) self.sub:SetText(sub or "") end
	function row:Price(copper, word, color)
		self.money:SetText(copper and UI.Money(copper, true, 12, self.money) or "")
		self.word:SetText(word or "")
		UI.Ink(self.word, color or C.dim)
	end
	function row:Trend(prices, color)
		if opts.spark == false then return end
		self.spark:Set(prices, 58, 18, color or C.hot)
	end
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if not self.id then return end
		UI.GameTipAt(self, self.icon):SetItemByID(self.id)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if opts.click then opts.click(self) end
	end)
	return row
end

-- A list down a scroll area that holds only the rows in sight: list:Lay(n, fill(row, i)) says there are n and how each
-- is filled; as the area scrolls or is sized, the few rows in sight are filled again for the entries under them.
--   P.List(scroll, opts)   scroll: a UI.ScrollArea; opts as P.Row's (height)
function P.List(scroll, opts)
	opts = opts or {}
	local tall = opts.height or 34
	local holder = scroll.content
	local list = { rows = {}, n = 0 }
	local function Fill()
		local fill = list.fill
		if not fill then return end
		local view = list.view or scroll:GetHeight()
		if issecretvalue(view) or not view or view <= 0 then view = 400 end
		local at = scroll:At() or 0
		local first = math.max(1, math.floor(at / tall) + 1)
		local count = math.ceil(view / tall) + 1
		for k = 1, math.max(count, #list.rows) do
			local i = first + k - 1
			local row = list.rows[k]
			if k <= count and i <= list.n then
				if not row then
					row = P.Row(holder, opts)
					row:SetPoint("RIGHT")
					list.rows[k] = row
				end
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -(i - 1) * tall)
				row:SetPoint("RIGHT")
				row.index = i
				row:Show()
				fill(row, i)
			elseif row then
				row:Hide()
			end
		end
	end
	list.Fill = Fill
	-- view: how tall the list's area is (the page knows; read from the area while it is being laid it may not be yet)
	function list:Lay(n, fill, view)
		self.n, self.fill, self.view = n, fill, view
		holder:SetHeight(math.max(1, n * tall))
		Fill()
	end
	scroll:HookScript("OnVerticalScroll", Fill)
	scroll:HookScript("OnSizeChanged", Fill)
	return list
end
