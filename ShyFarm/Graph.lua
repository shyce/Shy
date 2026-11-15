-- A favorite's graph: a bar a session, the latest at the right (lit while it is the session going on), over a
-- hairline; its caption and latest figure over it. A click turns it between how many an hour and the gold an hour
-- (T.db.graph, shared by every graph). Built for the finder's favorites (T:Graph); it draws nothing a frame.

local ADDON, ns = ...
local T, P, St = ns.T, ns.Prices, ns.Stats
local UI, Theme, Skin = Shy.UI, Shy.Theme, Shy.Skin
local C = UI.colors

local K = { GAP = 2, HEAD = 14, LEAST = 2, REST = 0.45 }
local CAPTION = { items = "AN HOUR", gold = "GOLD AN HOUR" }

function ns.Graph(parent, width, height)
	local g = CreateFrame("Button", nil, parent)
	g:SetSize(width, height)
	g.caption = UI.Text(g, "", 9, true, C.dim)
	g.caption:SetPoint("TOPLEFT", 0, 0)
	g.figure = g:CreateFontString(nil, "OVERLAY")
	g.figure:SetFontObject(UI.NameFont(11))
	g.figure:SetPoint("TOPRIGHT", 0, 1)
	g.figure:SetJustifyH("RIGHT")
	g.base = g:CreateTexture(nil, "ARTWORK")
	g.base:SetHeight(1)
	g.base:SetPoint("BOTTOMLEFT")
	g.base:SetPoint("BOTTOMRIGHT")
	UI.Paint(g.base, C.rowEdge, 0.9)
	g.bars, g.wells = {}, {}
	local n = St.K.SERIES
	local each = (width - (n - 1) * K.GAP) / n
	for i = 1, n do
		local x = (i - 1) * (each + K.GAP)
		local well = g:CreateTexture(nil, "BACKGROUND")
		well:SetPoint("BOTTOMLEFT", x, 1)
		well:SetSize(each, height - K.HEAD - 1)
		UI.Paint(well, C.bg, 0.35)
		g.wells[i] = well
		local bar = g:CreateTexture(nil, "ARTWORK", nil, 1)
		bar:SetPoint("BOTTOMLEFT", x, 1)
		bar:SetSize(each, K.LEAST)
		Skin.Hatch(bar)
		g.bars[i] = bar
	end
	g.empty = UI.Text(g, "No sessions yet", 10, false, C.dim)
	g.empty:SetPoint("CENTER", 0, -K.HEAD / 2)

	-- Draws an item's sessions in the graph's mode.
	function g:Show(item)
		self.item = item
		local mode = T.db.graph == "gold" and "gold" or "items"
		local st = St.Of(item)
		local values = mode == "gold" and st.golds or st.series
		local most = 0
		for _, v in ipairs(values) do most = math.max(most, v) end
		local room = height - K.HEAD - 1
		local from = n - #values
		for i = 1, n do
			local v = values[i - from]
			local bar = self.bars[i]
			bar:SetShown(v ~= nil)
			if v then
				bar:SetHeight(math.max(K.LEAST, most > 0 and room * v / most or K.LEAST))
				local latest = i == n
				UI.Tint(bar, latest and st.live and C.hot or Theme.Accent, latest and 1 or K.REST + 0.4 * (v / math.max(1, most)))
			end
		end
		self.empty:SetShown(#values == 0)
		self.caption:SetText(CAPTION[mode])
		local last = values[#values]
		if not last then
			self.figure:SetText("")
		elseif mode == "gold" then
			self.figure:SetText(P.Text(last, 11, self.figure))
		else
			self.figure:SetText(("%d"):format(math.floor(last + 0.5)))
		end
		UI.Ink(self.figure, st.live and C.hot or C.text)
	end

	g:SetScript("OnClick", function(self)
		T.db.graph = T.db.graph == "gold" and "items" or "gold"
		ns.Changed("graph")
		if self.item then self:Show(self.item) end
	end)
	g:SetScript("OnEnter", function(self)
		UI.Tip(self, T.db.graph == "gold" and "Gold an hour" or "How many an hour",
			"A bar a session, the latest at the right, lit while you farm it now.", { hints = { { "left", "Show the other" } }, side = "CURSOR" })
	end)
	g:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	return g
end
