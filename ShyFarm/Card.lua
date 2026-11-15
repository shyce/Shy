-- The piece on the screen while you farm. Its header says what you are doing and where, the clock (stopped while
-- you rest) and the cog. Under it, side by side, the two figures that matter: what the session made and what that
-- comes to an hour; under them kills and corpses looted (or catches and the ones that got away). The item you farm
-- stands next in a slot with how many you hold of how many you want, the odds you have had and when you will have
-- them all; one with no price asks how to value it (the auction house, a price you type, or the vendor's). Then
-- the loot, the best first, each at what it is worth: coin, things, and junk as one row. What was just looted
-- lights a moment. At the auction house its foot looks up the prices it lacks.
--
-- In ShyDock's deck it is a box with a tab ("Farm") that is offered while a session goes on, lowest in the deck so
-- nothing else moves for it; alone it stands where you put it, and is sized from its corners: the rows that fit
-- show, the rest are added up in the last.

local ADDON, ns = ...
local T, S, P, A = ns.T, ns.Session, ns.Prices, ns.Auction
local UI, Theme, HUD, Hover = Shy.UI, Shy.Theme, Shy.HUD, Shy.Hover
local C = UI.colors
local GLYPH = Shy.Skin.GLYPH

local Card = {}
ns.Card = Card

local K = {
	WIDTH = 300,                  -- room for the theme's widest lettering on its buttons
	HEAD = UI.HEAD.window.line,   -- a window's header: the icon, the title, the clock, the cog and the ×
	PAD = 9,                      -- in from the sides
	HERO = 38,                    -- the two figures and their captions
	STATS = 20,                   -- kills and corpses, or catches
	WANT = 48,                    -- the item farmed
	ASK = 50,                     -- the question of its price
	ROW = 22,                     -- a loot row
	ICON = 18,                    -- a loot row's picture
	SLOT = 32,                    -- the farmed item's picture
	BAR = 3,                      -- the farmed item's progress
	FOOT = 30,                    -- the auction house's button
	BAND = 48,                    -- how the session stands, when it isn't running: ready, paused, or asking to start
	TOOLS = 30,                   -- the controls: start or pause, go there, favorite, end
	END = 8,                      -- under the last row
	LEAST = 3,                    -- loot rows at the least
	MIN_W = 280,
	GLOW = 0.9,                   -- seconds the light of a new loot takes to fade
	WASH = 0.16, EDGE = 0.9,      -- that light's strength: the wash over the row, the line at its edge (as the kit's)
	SEP = "  \194\183  ",
	HINTS = { { "left", "Move" }, { "right", "Menu" } },
}
local TOP = K.HEAD + UI.LINE + 6

ns.cards = {}

-- Words

-- "42:05" or "1:02:05".
local function Clock(seconds)
	seconds = math.floor(seconds or 0)
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
	if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
	return ("%d:%02d"):format(m, s)
end
Card.Clock = Clock

-- "6 min", "1 h 20 min".
local function Minutes(seconds)
	local m = math.max(1, math.floor(seconds / 60 + 0.5))
	if m < 60 then return m .. " min" end
	return ("%d h %d min"):format(math.floor(m / 60), m % 60)
end

local function Plural(n, one, many) return ("%d %s"):format(n, n == 1 and one or many) end

local function Quality(item)
	local q = C_Item.GetItemQualityByID(item)
	if q == nil then return nil end
	return q
end

local function QualityColor(q)
	if not q then return C.text end
	local r, g, b = C_Item.GetItemQualityColor(q)
	return { r, g, b }
end

-- What the card shows, from a session: everything worked out, nothing drawn. Tests read it.
function Card.View(s)
	local view = { title = S.Kind(s) == "fishing" and "Fishing" or "Grinding", zone = s.map and C_Map.GetMapInfo(s.map),
		seconds = S.Seconds(s), running = S.Running(s), state = s.state, value = S.Value(s), perHour = S.PerHour(s), rows = {} }
	view.zone = view.zone and view.zone.name or nil
	-- How it stands, said plainly when it isn't running: ready (not started), paused (by hand or by a reload), or
	-- asking to start (you reached where it drops, or looted it while it didn't count).
	if s.ask then
		view.band = { kind = "ask", words = s.state == "paused" and "You looted it while paused" or "You're where it drops",
			sub = s.state == "paused" and "Go on counting?" or "Start the clock now?", start = s.state == "paused" and "Go on" or "Start" }
	elseif s.state == "ready" then
		view.band = { kind = "ready", words = "Ready when you are",
			sub = s.want and "Nothing counts yet. You'll be asked when you get there." or "Nothing counts until you start." }
	elseif s.state == "paused" then
		view.band = { kind = "paused", words = "Paused",
			sub = s.why == "reload" and "Kept over the reload. It goes on where it drops."
				or s.why == "left" and "You left where it drops. It goes on when you're back."
				or "Nothing counts until you go on." }
	elseif s.state == "running" and s.there and time() - s.there < 5 then
		-- (Just begun as you got there: said a moment, in the color of things going well.)
		view.band = { kind = "go", words = "You're there", sub = "Counting from now." }
	end
	view.tools = { main = s.state == "running" and "Pause" or s.state == "ready" and "Start" or "Go on",
		primary = s.state ~= "running", want = s.want and s.want.item,
		favorite = s.want ~= nil and ns.Stats ~= nil and ns.Stats.IsFavorite(s.want.item) }
	if S.Kind(s) == "fishing" then
		view.stats = { { "loot", Plural(s.catches, "catch", "catches") } }
		if s.escaped > 0 then view.stats[2] = { "note", s.escaped .. " got away" } end
	else
		view.stats = { { "kill", Plural(S.Kills(s), "kill", "kills") }, { "loot", s.corpses .. " looted" } }
		if s.catches > 0 then view.stats[3] = { "loot", Plural(s.catches, "catch", "catches") } end
	end
	view.want = S.Wanted(s)
	if view.want and P.Needs(view.want.item) then view.ask = view.want.item end
	-- The loot: coin, then things by what they came to, then the junk as one row.
	if s.coin > 0 then view.rows[1] = { coin = true, name = "Coin", value = s.coin } end
	local things, junk = {}, { junk = true, name = "Junk", n = 0, value = 0 }
	for item, n in pairs(s.items) do
		local each = P.Value(item) or 0
		local q = Quality(item)
		if q == 0 then
			junk.n, junk.value = junk.n + n, junk.value + n * each
			junk.icon = junk.icon or C_Item.GetItemIconByID(item)
		else
			things[#things + 1] = { item = item, n = n, value = n * each, quality = q, unpriced = P.Value(item) == nil,
				name = C_Item.GetItemNameByID(item), icon = C_Item.GetItemIconByID(item) }
		end
	end
	table.sort(things, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		if a.n ~= b.n then return a.n > b.n end
		return a.item < b.item
	end)
	for _, row in ipairs(things) do view.rows[#view.rows + 1] = row end
	if junk.n > 0 then view.rows[#view.rows + 1] = junk end
	if A.IsOpen() and T.db.auction then
		local left = A.Left()
		if left > 0 then
			view.foot = { text = ("Checking prices, %d to go"):format(left), busy = true }
		else
			local wanting = #A.Wanting()
			if wanting > 0 then view.foot = { text = ("Check %s here"):format(Plural(wanting, "price", "prices")) } end
		end
	end
	if #view.rows == 0 then
		view.quiet = S.Kind(s) == "fishing" and { "Nothing caught yet", "Your catches add up here." }
			or { "Nothing looted yet", "What you loot adds up here, at what it's worth." }
	end
	return view
end

-- A made-up session, for layout mode: what the piece looks like at work.
local SAMPLE = {
	title = "Grinding", zone = "Westfall", seconds = 1873, running = true, state = "running", value = 42350, perHour = 81400,
	tools = { main = "Pause", favorite = true, want = true },
	stats = { { "kill", "38 kills" }, { "loot", "36 looted" } },
	want = { name = "Stringy meat", have = 14, goal = 20, odds = "1 in 2", rate = 27, eta = 800, sample = true },
	rows = {
		{ coin = true, name = "Coin", value = 11240 },
		{ name = "Stringy meat", n = 17, value = 13600, quality = 1 },
		{ name = "Ruined pelt", n = 12, value = 9600, quality = 1 },
		{ name = "Light leather", n = 9, value = 6300, quality = 1 },
		{ junk = true, name = "Junk", n = 21, value = 1610 },
	},
}
Card.SAMPLE = SAMPLE

-- Drawing

-- A loot row: its picture in a slot, its name in its quality's color, the count, what it came to.
local function NewRow(card)
	local row = CreateFrame("Frame", nil, card)
	row:SetHeight(K.ROW)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(K.ICON, K.ICON)
	row.icon:SetPoint("LEFT", 2, 0)
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = K.ICON, hover = false })
	row.glyph = row:CreateTexture(nil, "ARTWORK")
	row.glyph:SetSize(14, 14)
	row.glyph:SetPoint("CENTER", row.icon)
	row.value = row:CreateFontString(nil, "OVERLAY")
	row.value:SetFontObject(UI.NameFont(12))
	row.value:SetPoint("RIGHT", -2, 0)
	row.value:SetJustifyH("RIGHT")
	row.count = row:CreateFontString(nil, "OVERLAY")
	row.count:SetFontObject(UI.NameFont(11))
	row.name = row:CreateFontString(nil, "OVERLAY")
	row.name:SetFontObject(UI.NameFont(12))
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.count:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
	-- The light a row takes as something lands in it, as the kit lights a picked row: your color washed over it,
	-- faint, with a fine line of it at its left edge; painted through the theme (it follows your color and look),
	-- under the words, fading out. (The faintness is in the paint itself, not only in the fade.)
	row.lit = {}
	row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.wash:SetAllPoints()
	UI.Paint(row.wash, Theme.Accent, K.WASH)
	row.edge = row:CreateTexture(nil, "BACKGROUND", nil, 3)
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(2)
	UI.Paint(row.edge, Theme.Accent, K.EDGE)
	row.fades = {}
	for _, t in ipairs({ row.wash, row.edge }) do
		t:SetAlpha(0)
		local group = t:CreateAnimationGroup()
		group:SetToFinalAlpha(true)
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0)
		fade:SetDuration(K.GLOW)
		fade:SetSmoothing("OUT")
		row.fades[#row.fades + 1] = group
	end
	row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 2)
	row.hover:SetAllPoints()
	UI.Paint(row.hover, C.hot, 0.08)
	row.hover:Hide()
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		self.hover:Show()
		if Card.RowTip then Card.RowTip(self) end
	end)
	row:SetScript("OnLeave", function(self)
		self.hover:Hide()
		UI.TipHide(self)
	end)
	row:SetScript("OnMouseUp", function(self, button)
		if card.box and HUD.WasDragged(card.box) then return end
		if Card.RowClick then Card.RowClick(self, button) end
	end)
	if card.box then HUD.Manage(card.box, row, false) end
	return row
end

-- width: the row's, from the card (a row just anchored has not been measured by the game yet).
local function PaintRow(row, data, width)
	row.data = data
	local item = data.item
	row.slot:Empty(false)
	row.glyph:Hide()
	row.icon:Show()
	if data.coin then
		row.icon:Hide()
		row.slot:Empty(true)
		Hover.Glyph(row.glyph, "coin", 14)
		UI.Tint(row.glyph, C.alert)
		row.glyph:Show()
	elseif data.more then
		row.icon:Hide()
		row.slot:Empty(true)
		Hover.Glyph(row.glyph, "bag", 14)
		UI.Tint(row.glyph, C.dim)
		row.glyph:Show()
	else
		row.icon:SetTexture(data.icon or QUESTION_MARK_ICON)
		row.icon:SetDesaturated(data.junk == true)
	end
	row.name:SetText(data.name or (item and "…") or "")
	if data.coin or data.more then
		UI.Ink(row.name, data.more and C.dim or C.text)
	elseif data.junk then
		UI.Ink(row.name, QualityColor(0))
	else
		UI.Ink(row.name, QualityColor(data.quality))
	end
	row.count:SetText(data.n and data.n > 0 and ("\195\151" .. data.n) or "")
	UI.Ink(row.count, C.dim)
	if data.unpriced then
		row.value:SetText("")
	else
		row.value:SetText(P.Text(data.value or 0, 12, row.value))
	end
	UI.Ink(row.value, data.more and C.dim or C.text)
	-- (The name gives way to the count and the value.)
	local room = width - K.ICON - 11 - row.value:GetStringWidth() - 8 - row.count:GetStringWidth() - 6
	row.name:SetWidth(math.max(20, math.min(row.name:GetUnboundedStringWidth() + 1, room)))
end

function ns.CreateCard(parent, box)
	local card = CreateFrame("Frame", nil, parent)
	card.box = box
	card:SetSize(K.WIDTH, 200)
	-- The header, a window's: ShyFarm's icon, what you do and where, the clock, the cog and the ×.
	card.head = UI.Head(card, { size = "window", icon = T.smallIcon, title = "Farming", drag = box,
		close = box and function() if Card.Close then Card.Close() end end or nil,
		buttons = { { glyph = GLYPH.gear, tip = { "Farming menu", "Pause, what you farm and its price, past sessions." },
			click = function(b) UI.ContextMenu(b, function(root) if Card.Menu then Card.Menu(root) end end) end } },
		panel = { hud = true, facets = false } })
	card.title = card.head.title
	card.zone = UI.Text(card, "", 11, false, C.dim)
	card.zone:SetWordWrap(false)
	card.clock = card:CreateFontString(nil, "OVERLAY")
	card.clock:SetFontObject(UI.NameFont(12))
	card.clockGlyph = card:CreateTexture(nil, "ARTWORK")
	card.clockGlyph:SetSize(12, 12)
	Hover.Glyph(card.clockGlyph, "clock", 12)

	-- The two figures, side by side, each with a small caption under it.
	card.made = card:CreateFontString(nil, "OVERLAY")
	card.made:SetFontObject(UI.NameFont(17))
	card.madeSays = UI.Text(card, "MADE", 9, true, C.dim)
	card.rate = card:CreateFontString(nil, "OVERLAY")
	card.rate:SetFontObject(UI.NameFont(17))
	card.rate:SetJustifyH("RIGHT")
	card.rateSays = UI.Text(card, "AN HOUR", 9, true, C.dim)
	card.rateSays:SetJustifyH("RIGHT")
	-- A light behind the figures when the session's worth goes up: gold, fading.
	card.glow = card:CreateTexture(nil, "BACKGROUND", nil, 2)
	card.glow:SetTexture(Shy.Brand.GLOW)
	card.glow:SetBlendMode("ADD")
	card.glow:SetAlpha(0)
	card.glowFade = card.glow:CreateAnimationGroup()
	card.glowFade:SetToFinalAlpha(true)
	local fade = card.glowFade:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.55)
	fade:SetToAlpha(0)
	fade:SetDuration(K.GLOW * 1.4)
	fade:SetSmoothing("OUT")

	-- Kills and corpses (or catches): glyphs and words on one quiet line, a hairline over it.
	card.rule = card:CreateTexture(nil, "ARTWORK")
	card.rule:SetHeight(1)
	UI.Paint(card.rule, C.rowEdge, 0.8)
	card.stats = {}
	for i = 1, 3 do
		local glyph = card:CreateTexture(nil, "ARTWORK")
		glyph:SetSize(13, 13)
		UI.Tint(glyph, C.dim)
		local words = UI.Text(card, "", 11, false, C.dim)
		card.stats[i] = { glyph = glyph, words = words }
	end

	-- The item farmed: its slot, its name, how many of how many, the odds and when, a bar under it all.
	local want = CreateFrame("Frame", nil, card)
	want:SetHeight(K.WANT)
	want.icon = want:CreateTexture(nil, "ARTWORK")
	want.icon:SetSize(K.SLOT, K.SLOT)
	want.icon:SetPoint("TOPLEFT", 2, -4)
	want.slot = Shy.Slot.New(want, { to = want.icon, icon = want.icon, size = K.SLOT, hover = false })
	want.count = want:CreateFontString(nil, "OVERLAY")
	want.count:SetFontObject(UI.NameFont(14))
	want.count:SetPoint("TOPRIGHT", -2, -5)
	want.count:SetJustifyH("RIGHT")
	want.name = want:CreateFontString(nil, "OVERLAY")
	want.name:SetFontObject(UI.NameFont(13))
	want.name:SetPoint("TOPLEFT", want.icon, "TOPRIGHT", 9, -2)
	want.name:SetPoint("RIGHT", want.count, "LEFT", -6, 0)
	want.name:SetJustifyH("LEFT")
	want.name:SetWordWrap(false)
	want.line = UI.Text(want, "", 11, false, C.dim)
	want.line:SetPoint("TOPLEFT", want.name, "BOTTOMLEFT", 0, -4)
	want.line:SetPoint("RIGHT", -2, 0)
	want.line:SetWordWrap(false)
	local bar = CreateFrame("StatusBar", nil, want)
	bar:SetHeight(K.BAR)
	bar:SetPoint("TOPLEFT", want.line, "BOTTOMLEFT", 0, -5)
	bar:SetPoint("RIGHT", -2, 0)
	bar:SetMinMaxValues(0, 1)
	Shy.Skin.HatchBar(bar)
	bar.well = bar:CreateTexture(nil, "BACKGROUND")
	bar.well:SetAllPoints()
	UI.Paint(bar.well, C.bg, 0.7)
	bar.lit = bar:CreateTexture(nil, "ARTWORK", nil, 3)
	bar.lit:SetColorTexture(1, 1, 1, 0.3)
	bar.lit:SetWidth(2)
	bar.lit:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT")
	bar.lit:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
	want.bar = bar
	want:EnableMouse(true)
	want:SetScript("OnEnter", function(self) if Card.WantTip then Card.WantTip(self) end end)
	want:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	want:SetScript("OnMouseUp", function(self, button)
		if box and HUD.WasDragged(box) then return end
		if Card.WantClick then Card.WantClick(self, button) end
	end)
	if box then HUD.Manage(box, want, false) end
	card.want = want

	-- How to value it: a line, then the three ways (or the box to type a price in).
	local ask = CreateFrame("Frame", nil, card)
	ask:SetHeight(K.ASK)
	ask.says = UI.Text(ask, "", 11, false, C.alert)
	ask.says:SetPoint("TOPLEFT", 2, -2)
	ask.says:SetPoint("RIGHT", -2, 0)
	ask.says:SetWordWrap(false)
	ask.buttons = {}
	for i, key in ipairs({ "auction", "own", "vendor" }) do
		local b = UI.Button(ask, "", 80, function() if Card.Answer then Card.Answer(key) end end)
		b:SetHeight(22)
		ask.buttons[i] = b
		ask.buttons[key] = b
	end
	ask.input = UI.Input(ask, nil, function() return "" end, function(text) if Card.Typed then Card.Typed(text) end end,
		{ width = 160, maxLetters = 20, placeholder = function() return "Like 1g 20s" end })
	ask.input:Hide()
	ask.cancel = UI.Button(ask, "Back", 60, function()
		card.typing = false
		if Card.Paint then Card.Paint() end
	end)
	ask.cancel:SetHeight(22)
	card.ask = ask

	-- At the auction house: the prices it lacks, a click away.
	card.foot = UI.Button(card, "", 100, function() A.Check() end)

	-- How the session stands while it isn't running: a band in its meaning's color (gold paused, your color ready),
	-- its words, and when it asks, Start and Not now.
	local band = CreateFrame("Frame", nil, card)
	band:SetHeight(K.BAND - 4)
	band.wash = band:CreateTexture(nil, "BACKGROUND", nil, 1)
	band.wash:SetAllPoints()
	band.wash:SetColorTexture(1, 1, 1, 1)
	band.edge = band:CreateTexture(nil, "ARTWORK")
	band.edge:SetWidth(2)
	band.edge:SetPoint("TOPLEFT")
	band.edge:SetPoint("BOTTOMLEFT")
	band.words = UI.Text(band, "", 12, true, C.text)
	band.words:SetPoint("TOPLEFT", 9, -4)
	band.words:SetWordWrap(false)
	band.sub = UI.Text(band, "", 10, false, C.dim)
	band.sub:SetPoint("TOPLEFT", band.words, "BOTTOMLEFT", 0, -2)
	band.sub:SetWordWrap(true)
	band.sub:SetJustifyH("LEFT")
	band.later = UI.Button(band, "Not now", 62, function() if Card.Answer then Card.Answer("later") end end)
	band.later:SetHeight(22)
	band.later:SetPoint("RIGHT", -4, 0)
	band.start = UI.Button(band, "Start", 56, function() if Card.Answer then Card.Answer("start") end end)
	band.start:SetHeight(22)
	band.start:SetPoint("RIGHT", band.later, "LEFT", -5, 0)
	card.band = band

	-- The controls, in view: start or pause (lit while it isn't running), go where it drops, keep it as a favorite,
	-- end the session (asked twice).
	card.tools = {}
	local WORDS = { main = "Pause", go = "Go there", favorite = "Favorite", stop = "End" }
	for i, key in ipairs({ "main", "go", "favorite", "stop" }) do
		local b = UI.Button(card, WORDS[key], 60, function() if Card.Tool then Card.Tool(key) end end)
		b:SetHeight(22)
		card.tools[i], card.tools[key] = b, b
	end
	UI.Twice(card.tools.stop, function() if Card.Tool then Card.Tool("stop") end end)
	card.foot:SetHeight(22)

	card.quiet = UI.Text(card, "", 12, true, C.dim)
	card.quiet:SetJustifyH("CENTER")
	card.quietLine = UI.Text(card, "", 11, false, C.dim)
	card.quietLine:SetJustifyH("CENTER")

	card.rows = {}

	-- Where everything stands, from the top, for the blocks the view has.
	function card:Lay(view)
		local width = self:GetWidth()
		local inner = width - 2 * K.PAD
		-- In the strip: the clock where the controls end, the zone after the title's words.
		local head = self.head
		self.clock:ClearAllPoints()
		self.clock:SetPoint("RIGHT", self, "TOPRIGHT", -head.right, -head.mid)
		self.clockGlyph:ClearAllPoints()
		self.clockGlyph:SetPoint("RIGHT", self.clock, "LEFT", -4, 0)
		self.zone:ClearAllPoints()

		local y = TOP + 4
		self.band:ClearAllPoints()
		self.band:SetShown(view and view.band ~= nil or false)
		if self.band:IsShown() then
			self.band:SetPoint("TOPLEFT", K.PAD - 3, -(y - 2))
			self.band:SetPoint("TOPRIGHT", -(K.PAD - 3), -(y - 2))
			y = y + K.BAND
		end
		self.made:ClearAllPoints()
		self.made:SetPoint("TOPLEFT", K.PAD, -y)
		self.rate:ClearAllPoints()
		self.rate:SetPoint("TOPRIGHT", -K.PAD, -y)
		self.madeSays:ClearAllPoints()
		self.madeSays:SetPoint("TOPLEFT", K.PAD + 1, -(y + 21))
		self.rateSays:ClearAllPoints()
		self.rateSays:SetPoint("TOPRIGHT", -K.PAD - 1, -(y + 21))
		self.glow:ClearAllPoints()
		self.glow:SetPoint("TOPLEFT", 4, -(y - 6))
		self.glow:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -4, -(y + K.HERO))
		y = y + K.HERO
		self.rule:ClearAllPoints()
		self.rule:SetPoint("TOPLEFT", K.PAD, -y)
		self.rule:SetPoint("TOPRIGHT", -K.PAD, -y)
		local x = K.PAD
		for _, stat in ipairs(self.stats) do
			stat.glyph:ClearAllPoints()
			stat.glyph:SetPoint("LEFT", self, "TOPLEFT", x, -(y + K.STATS / 2 + 1))
			stat.words:ClearAllPoints()
			stat.words:SetPoint("LEFT", stat.glyph, "RIGHT", 4, 0)
			if stat.words:IsShown() then x = x + 13 + 4 + stat.words:GetStringWidth() + 14 end
		end
		self.zone:SetPoint("RIGHT", self, "TOPRIGHT", -K.PAD, -(y + K.STATS / 2 + 1))
		self.zone:SetPoint("LEFT", self, "TOPLEFT", x, -(y + K.STATS / 2 + 1))
		self.zone:SetJustifyH("RIGHT")
		y = y + K.STATS
		do
			local gap = 5
			local each = math.floor((inner - 3 * gap) / 4)
			for i, b in ipairs(self.tools) do
				b:ClearAllPoints()
				b:SetWidth(each)
				b:SetPoint("TOPLEFT", K.PAD + (i - 1) * (each + gap), -(y + 2))
			end
			y = y + K.TOOLS
		end
		self.want:ClearAllPoints()
		self.want:SetShown(view and view.want ~= nil or false)
		if self.want:IsShown() then
			self.want:SetPoint("TOPLEFT", K.PAD, -y)
			self.want:SetPoint("TOPRIGHT", -K.PAD, -y)
			y = y + K.WANT
		end
		self.ask:ClearAllPoints()
		self.ask:SetShown(view and view.ask ~= nil or false)
		if self.ask:IsShown() then
			self.ask:SetPoint("TOPLEFT", K.PAD, -y)
			self.ask:SetPoint("TOPRIGHT", -K.PAD, -y)
			local shown, gap = {}, 6
			for _, b in ipairs(self.ask.buttons) do if b:IsShown() then shown[#shown + 1] = b end end
			local each = math.floor((inner - (#shown - 1) * gap) / math.max(1, #shown))
			for i, b in ipairs(shown) do
				b:ClearAllPoints()
				b:SetWidth(each)
				b:SetPoint("TOPLEFT", (i - 1) * (each + gap), -20)
			end
			self.ask.input:ClearAllPoints()
			self.ask.input:SetPoint("TOPLEFT", 0, -20)
			self.ask.input:SetWidth(inner - 66)
			self.ask.input.box:SetWidth(inner - 66)
			self.ask.cancel:ClearAllPoints()
			self.ask.cancel:SetPoint("TOPRIGHT", 0, -21)
			y = y + K.ASK
		end
		self.listTop = y + 2
		for i, row in ipairs(self.rows) do
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", K.PAD, -(self.listTop + (i - 1) * K.ROW))
			row:SetPoint("RIGHT", -K.PAD, 0)
		end
		self.foot:ClearAllPoints()
		self.foot:SetPoint("BOTTOMLEFT", K.PAD, K.END)
		self.foot:SetPoint("BOTTOMRIGHT", -K.PAD, K.END)
		self.quiet:ClearAllPoints()
		self.quiet:SetPoint("TOP", self, "TOP", 0, -(self.listTop + 10))
		self.quietLine:ClearAllPoints()
		self.quietLine:SetPoint("TOP", self.quiet, "BOTTOM", 0, -4)
		self.quietLine:SetWidth(inner - 16)
	end

	-- Loot rows the card has room for at its height.
	function card:Places(view)
		local fixed = TOP + 4 + (view.band and K.BAND or 0) + K.HERO + K.STATS + K.TOOLS + (view.want and K.WANT or 0) + (view.ask and K.ASK or 0)
			+ (view.foot and K.FOOT or 0) + K.END + 2
		-- (On the screen it is its box's height: it is anchored all round to it.)
		local height = (self.box or self):GetHeight()
		return math.max(1, math.floor((height - fixed) / K.ROW))
	end

	-- Draws a view (Card.View's, or the sample).
	function card:Fill(view)
		self.view = view
		self.title:SetText(view.title)
		self.zone:SetText(view.zone or "")
		self.clock:SetText(view.state == "paused" and "paused" or view.state == "ready" and "ready" or Clock(view.seconds))
		UI.Ink(self.clock, view.running and C.text or C.dim)
		UI.Tint(self.clockGlyph, view.running and C.hot or C.dim)
		self.made:SetText(view.value > 0 and P.Text(view.value, 17, self.made) or "\226\128\148")
		UI.Ink(self.made, C.text)
		if view.perHour then
			self.rate:SetText(P.Text(view.perHour, 17, self.rate))
			UI.Ink(self.rate, C.hot)
		else
			self.rate:SetText("\226\128\148")
			UI.Ink(self.rate, C.dim)
		end
		for i, stat in ipairs(self.stats) do
			local said = view.stats[i]
			stat.glyph:SetShown(said ~= nil)
			stat.words:SetShown(said ~= nil)
			if said then
				Hover.Glyph(stat.glyph, said[1], 13)
				stat.words:SetText(said[2])
			end
		end
		self:FillBand(view.band)
		self:FillTools(view.tools)
		self:FillWant(view.want)
		self:FillAsk(view.ask)
		self.foot:SetShown(view.foot ~= nil)
		if view.foot then
			self.foot:SetLabel(view.foot.text)
			self.foot:SetUsable(not view.foot.busy, "Looking them up")
			if self.foot.SetPrimary then self.foot:SetPrimary(not view.foot.busy) end
		end
		self:Lay(view)
		local places = self:Places(view)
		local rows = view.rows
		if #rows > places then
			rows = Card.Trim(rows, places)
		end
		for i = 1, math.max(#rows, #self.rows) do
			local data, row = rows[i], self.rows[i]
			if data then
				if not row then
					row = NewRow(self)
					self.rows[i] = row
					row:SetPoint("TOPLEFT", K.PAD, -(self.listTop + (i - 1) * K.ROW))
					row:SetPoint("RIGHT", -K.PAD, 0)
				end
				PaintRow(row, data, (self.box or self):GetWidth() - 2 * K.PAD)
				row:Show()
			elseif row then
				row:Hide()
			end
		end
		local quiet = view.quiet
		self.quiet:SetShown(quiet ~= nil)
		self.quietLine:SetShown(quiet ~= nil)
		if quiet then
			self.quiet:SetText(quiet[1])
			self.quietLine:SetText(quiet[2])
		end
	end

	function card:FillBand(b)
		local band = self.band
		if not b then return end
		local color = b.kind == "paused" and C.alert or b.kind == "go" and C.good or C.hot
		band.wash:SetGradient("HORIZONTAL", CreateColor(color[1], color[2], color[3], 0.22), CreateColor(color[1], color[2], color[3], 0.03))
		UI.Paint(band.edge, color)
		band.words:SetText(b.words)
		UI.Ink(band.words, color)
		band.sub:SetText(b.sub)
		band.start:SetShown(b.start ~= nil)
		band.later:SetShown(b.start ~= nil)
		if b.start then
			band.start:SetLabel(b.start)
			if band.start.SetPrimary then band.start:SetPrimary(true) end
		end
		local room = (self.box or self):GetWidth() - 2 * K.PAD - 16 - (b.start and 130 or 0)
		band.words:SetWidth(room)
		band.sub:SetWidth(room)
	end

	function card:FillTools(t)
		local tools = self.tools
		t = t or {}
		tools.main:SetLabel(t.main or "Start")
		if tools.main.SetPrimary then tools.main:SetPrimary(t.primary == true) end
		tools.go:SetUsable(t.want ~= nil and t.go ~= false, t.want and "No place is known for it" or "Pick something to farm")
		tools.favorite:SetUsable(t.want ~= nil, "Pick something to farm")
		if tools.favorite.SetOn then tools.favorite:SetOn(t.favorite == true) end
		if tools.favorite.SetMark then tools.favorite:SetMark(t.favorite and C.alert or nil) end
	end

	function card:FillWant(w)
		local want = self.want
		if not w then return end
		local item = w.item
		local name = item and C_Item.GetItemNameByID(item) or w.name
		want.name:SetText(name or "\226\128\166")
		UI.Ink(want.name, QualityColor(item and Quality(item) or 1))
		want.icon:SetTexture(item and C_Item.GetItemIconByID(item) or QUESTION_MARK_ICON)
		local got = w.goal and w.have or w.got
		if w.goal then
			want.count:SetText(("%d / %d"):format(math.min(w.have, w.goal), w.goal))
			UI.Ink(want.count, w.have >= w.goal and C.good or C.hot)
		else
			want.count:SetText(tostring(got or 0))
			UI.Ink(want.count, C.hot)
		end
		local words = {}
		if w.odds then words[#words + 1] = w.odds end
		if w.rate and w.rate > 0 then words[#words + 1] = ("%d an hour"):format(math.floor(w.rate + 0.5)) end
		if w.goal and w.have >= w.goal then
			words[#words + 1] = "you have them all"
		elseif w.eta then
			words[#words + 1] = Minutes(w.eta) .. " to go"
		end
		if #words == 0 then
			local from = w.from
			words[1] = from and ("from " .. from) or (w.got and w.got > 0 and (w.got .. " this session") or "none yet")
		end
		want.line:SetText(table.concat(words, K.SEP))
		want.bar:SetShown(w.goal ~= nil)
		if w.goal then
			want.bar:SetValue(math.min(1, w.have / math.max(1, w.goal)))
			if w.have >= w.goal then want.bar:SetStatusBarColor(C.good[1], C.good[2], C.good[3]) else want.bar:SetStatusBarColor(Theme.Accent()) end
		end
	end

	function card:FillAsk(item)
		local ask = self.ask
		if not item then return end
		local auction = T.db.auction
		local vendor = P.Vendor(item)
		local typing = self.typing == item
		if typing then
			ask.says:SetText("Your price for one:")
		elseif A.Reminded(item) then
			ask.says:SetText("Checked when you next open the auction house.")
		else
			local pays = vendor and vendor > 0 and (" A vendor pays " .. P.Text(vendor, 11, ask.says) .. ".") or ""
			ask.says:SetText("No price yet." .. pays)
		end
		ask.buttons.auction:SetShown(auction and not typing)
		ask.buttons.auction:SetLabel(A.IsOpen() and "Check now" or "Auction")
		ask.buttons.own:SetShown(not typing)
		ask.buttons.own:SetLabel("Type it")
		ask.buttons.vendor:SetShown(not typing)
		ask.buttons.vendor:SetLabel("Vendor")
		ask.input:SetShown(typing)
		ask.cancel:SetShown(typing)
	end

	-- A light on what just landed: the figures, and the row it is in.
	function card:Light(item)
		if self.glowFade:IsPlaying() then self.glowFade:Stop() end
		UI.Tint(self.glow, C.alert)
		self.glowFade:Play()
		for _, row in ipairs(self.rows) do
			local data = row:IsShown() and row.data
			if data and ((item and data.item == item) or (item == "coin" and data.coin)) then
				for _, group in ipairs(row.fades) do
					if group:IsPlaying() then group:Stop() end
					group:Play()
				end
			end
		end
	end

	if box then
		card:SetAllPoints(box)
		card:EnableMouse(true)
		card:SetScript("OnEnter", function(self)
			if Card.CardTip then Card.CardTip(self) end
		end)
		card:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	end
	ns.cards[card] = true
	return card
end

-- Rows cut to `places`: the last place adds up the rest.
function Card.Trim(rows, places)
	local out, rest = {}, { more = true, value = 0, count = 0 }
	for i, row in ipairs(rows) do
		if i < places then
			out[i] = row
		else
			rest.count, rest.value = rest.count + 1, rest.value + (row.value or 0)
		end
	end
	rest.name = ("%d more"):format(rest.count)
	out[places] = rest
	return out
end

-- The card's height with the view's blocks and `rows` loot rows.
function Card.Height(view, rows)
	return TOP + 4 + (view.band and K.BAND or 0) + K.HERO + K.STATS + K.TOOLS + (view.want and K.WANT or 0) + (view.ask and K.ASK or 0) + rows * K.ROW
		+ (view.foot and K.FOOT or 0) + K.END + 2
end

Card.K = K
