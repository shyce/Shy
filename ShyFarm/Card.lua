-- The piece on the screen while you farm. Its header says what you are doing and where, the clock (stopped while
-- you rest) and the cog. Under it, side by side, the two figures that matter: what the session made and what that
-- comes to an hour; under them kills and corpses looted (or catches and the ones that got away). What you farm, once
-- picked with Find, stands next in a slot (nothing picked: no block, the room is the loot's): a creature (all it drops:
-- what a kill brings and how many you have looted), or the item counted on its own (how many you hold of how many
-- you want, the odds you have had and when you will have them all); an item with no price asks how to value it (the
-- auction house, a price you type, or the vendor's). Then the loot, the best first, each at what it is worth: coin,
-- things, and junk as one row. What was just looted lights a moment. At the auction house its foot looks up the
-- prices it lacks. How it stands is the clock's word in the header (paused, ready) and Start or Pause: no banners.
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
	FEW = 5,                      -- free bag slots at or under which they're said in gold
	THUMB = 12,                   -- the list's thumb, while it has more to show
	ROW = 22,                     -- a loot row
	ICON = 18,                    -- a loot row's picture
	SLOT = 32,                    -- the farmed item's picture
	SIGN = 20,                    -- a creature's sign in that slot, or the bag's for everything you loot
	GLYPH = 20,                   -- Go there and Favorite, on what you farm
	BAR = 3,                      -- the farmed item's progress
	FOOT = 30,                    -- the auction house's button
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

-- Whether the block of what you farm shows: for something picked (an item, a creature), never for anything at all.
local function Picked(view)
	return view.want ~= nil or (view.target ~= nil and view.target.kind ~= "any")
end

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

-- Rows by what they came to, most first; then by how many; then steady (coin before things of the same worth).
local function Worthier(a, b)
	if a.value ~= b.value then return a.value > b.value end
	if (a.n or 0) ~= (b.n or 0) then return (a.n or 0) > (b.n or 0) end
	return (a.item or 0) < (b.item or 0)
end

-- What the card shows, from a session: everything worked out, nothing drawn. Tests read it.
function Card.View(s)
	local view = { title = S.Kind(s) == "fishing" and "Fishing" or "Grinding", zone = s.map and C_Map.GetMapInfo(s.map),
		seconds = S.Seconds(s), running = S.Running(s), state = s.state, value = S.Value(s), perHour = S.PerHour(s), rows = {} }
	view.zone = view.zone and view.zone.name or nil
	local used = S.Used(s)
	view.target = S.Farmed(s)
	-- (Its clock's word: paused or ready only once there is something to pause or start.)
	view.clockWords = (s.state == "paused" and used and "paused") or (s.state == "ready" and view.target.kind ~= "any" and "ready") or nil
	-- (Waiting, its clock at rest with nothing counted: Start, and no End, there is nothing to end yet.)
	local waiting = s.state == "running" and not used and not S.Running(s)
	view.tools = { main = (not waiting and s.state == "running") and "Pause" or "Start",
		primary = s.state ~= "running" or waiting, want = s.want and s.want.item, farmed = view.target.kind ~= "any",
		ends = used or s.want ~= nil or s.mob ~= nil,
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
	-- A creature farmed: what a kill of it brings, how many you have looted this session and how fast.
	local target = view.target
	if target.kind == "mob" then
		local mob = s.mobs[target.npc]
		target.kills = mob and mob.corpses or 0
		target.worth = ns.Worth.Worth(target.npc)
		local seconds = S.Seconds(s)
		target.rate = seconds >= 60 and target.kills * 3600 / seconds or nil
		local quest = Shy.addons.Quest
		local who = quest and quest.Npc and quest:Npc(target.npc)
		if who and who.maxLevel and who.maxLevel > 0 then
			target.level = who.minLevel ~= who.maxLevel and ("level %d-%d"):format(who.minLevel, who.maxLevel) or ("level %d"):format(who.maxLevel)
		end
		if view.want then view.want.from = target.name end
	end
	-- The loot: every thing on its own row (grey junk too), coin among them, the most it came to first; what you loot
	-- next finds its place by its worth. Unpriced last.
	if s.coin > 0 then view.rows[1] = { coin = true, name = "Coin", value = s.coin } end
	for item, n in pairs(s.items) do
		local each = P.Value(item)
		local q = Quality(item)
		view.rows[#view.rows + 1] = { item = item, n = n, value = n * (each or 0), quality = q, junk = q == 0, unpriced = each == nil,
			name = C_Item.GetItemNameByID(item), icon = C_Item.GetItemIconByID(item) }
	end
	table.sort(view.rows, Worthier)
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
			or { "Nothing looted yet", "" }
	end
	return view
end

-- A made-up session, for layout mode: what the piece looks like at work.
local SAMPLE = {
	title = "Grinding", zone = "Westfall", room = { free = 14, total = 64 }, seconds = 1873, running = true, state = "running", value = 42350, perHour = 81400,
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
	local row = CreateFrame("Frame", nil, card.list.content)
	row:SetHeight(K.ROW)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(K.ICON, K.ICON)
	row.icon:SetPoint("LEFT", 2, 0)
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = K.ICON, hover = false })
	row.glyph = row:CreateTexture(nil, "ARTWORK")
	row.glyph:SetSize(14, 14)
	row.glyph:SetPoint("CENTER", row.icon)
	row.value = UI.Words(row, UI.NameFont(12), C.text, { justify = "RIGHT" })
	row.value:SetPoint("RIGHT", -2, 0)
	row.count = UI.Words(row, UI.NameFont(11), C.dim)
	row.name = UI.Words(row, UI.NameFont(12), C.text, { wrap = false })
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
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
	else
		row.icon:SetTexture(data.icon or QUESTION_MARK_ICON)
		row.icon:SetDesaturated(data.junk == true)
	end
	row.name:SetText(data.name or (item and "…") or "")
	if data.coin then
		UI.Ink(row.name, C.text)
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
	UI.Ink(row.value, C.text)
	-- (The name gives way to the count and the value.)
	local room = width - K.ICON - 11 - row.value:GetStringWidth() - 8 - row.count:GetStringWidth() - 6
	row.name:SetWidth(math.max(20, math.min(row.name:GetUnboundedStringWidth() + 1, room)))
end

-- The room under the card's header: its box's size on screen (it is anchored all round to it), its own as a
-- preview, less the look's clearance round its body (UI.Body).
local function Room(card)
	local l, t, r, b = UI.BodyIn(card)
	local f = card.box or card
	return f:GetWidth() - l - r, f:GetHeight() - t - b
end

function ns.CreateCard(parent, box)
	local card = CreateFrame("Frame", nil, parent)
	card.box = box
	card:SetSize(K.WIDTH, 200)
	-- The header, a window's: ShyFarm's icon, what you do and where, the clock, the cog and the ×.
	card.head = UI.Head(card, { size = "window", icon = T.mark, title = "Farming", drag = box,
		close = box and function() if Card.Close then Card.Close() end end or nil,
		buttons = { { glyph = GLYPH.gear, tip = { "Farming menu", "Pause, what you farm and its price, past sessions." },
			click = function(b) UI.ContextMenu(b, function(root) if Card.Menu then Card.Menu(root) end end) end } },
		-- (its body inside the size the screen's plan gives it: the rows give the room, UI.Body)
		panel = { hud = true, facets = false }, body = true })
	card.title = card.head.title
	-- Everything drawn straight on the card: a frame of its own above the body, whose sheet would cover it.
	local face = CreateFrame("Frame", nil, card)
	face:SetAllPoints(card)
	-- Room left in your bags, at the stats line's right: how many slots are free, in words (a bag's sign there would
	-- read as another "looted"); gold when few, red when full (then nothing more is looted).
	card.room = UI.Text(face, "", 11, false, C.dim)
	card.room:SetWordWrap(false)
	card.clock = UI.Words(face, UI.NameFont(12))
	card.clockGlyph = face:CreateTexture(nil, "ARTWORK")
	card.clockGlyph:SetSize(12, 12)
	Hover.Glyph(card.clockGlyph, "clock", 12)

	-- The two figures, side by side, each with a small caption under it.
	card.made = UI.Words(face, UI.NameFont(17))
	card.madeSays = UI.Text(face, "MADE", 9, true, C.dim)
	card.rate = UI.Words(face, UI.NameFont(17), C.hot, { justify = "RIGHT" })
	card.rateSays = UI.Text(face, "AN HOUR", 9, true, C.dim)
	card.rateSays:SetJustifyH("RIGHT")
	-- A light behind the figures when the session's worth goes up: gold, fading.
	card.glow = face:CreateTexture(nil, "BACKGROUND", nil, 2)
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
	card.rule = face:CreateTexture(nil, "ARTWORK")
	card.rule:SetHeight(1)
	UI.Paint(card.rule, C.rowEdge, 0.8)
	card.stats = {}
	for i = 1, 3 do
		local glyph = face:CreateTexture(nil, "ARTWORK")
		glyph:SetSize(13, 13)
		UI.Tint(glyph, C.dim)
		local words = UI.Text(face, "", 11, false, C.dim)
		card.stats[i] = { glyph = glyph, words = words }
	end

	-- What you farm: its slot (an item's picture; a creature's sign, or the bag's for everything you loot), its name,
	-- how many of how many, the odds and when, a bar under it all; with nothing picked, Find at its right.
	local want = CreateFrame("Frame", nil, card)
	want:SetHeight(K.WANT)
	want.icon = want:CreateTexture(nil, "ARTWORK")
	want.icon:SetSize(K.SLOT, K.SLOT)
	want.icon:SetPoint("TOPLEFT", 2, -4)
	want.slot = Shy.Slot.New(want, { to = want.icon, icon = want.icon, size = K.SLOT, hover = false })
	want.sign = want:CreateTexture(nil, "ARTWORK", nil, 1)
	want.sign:SetSize(K.SIGN, K.SIGN)
	want.sign:SetPoint("CENTER", want.icon)
	want.sign:Hide()
	want.count = UI.Words(want, UI.NameFont(14), C.hot, { justify = "RIGHT" })
	want.count:SetPoint("TOPRIGHT", -2, -5)
	-- What you can do with what you farm, at the block's foot on the right: put where to farm it on your route, keep
	-- the item as a favorite (lit in gold while it is one).
	want.star = UI.GlyphButton(want, Shy.MEDIA .. "GlyphStar", K.GLYPH, function() if Card.Tool then Card.Tool("favorite") end end,
		{ tip = { "Favorite", "You'll find your favorites in Find, with how each one went." } })
	want.star:SetPoint("BOTTOMRIGHT", 0, 4)
	want.go = UI.GlyphButton(want, Shy.Skin.GLYPH.pin, K.GLYPH, function() if Card.Tool then Card.Tool("go") end end,
		{ tip = { "Go there", "Puts the best place to farm it on your route." } })
	want.go:SetPoint("RIGHT", want.star, "LEFT", -4, 0)
	want.name = UI.Words(want, UI.NameFont(13), C.text, { wrap = false })
	want.name:SetPoint("TOPLEFT", want.icon, "TOPRIGHT", 9, -2)
	want.name:SetPoint("RIGHT", want.count, "LEFT", -6, 0)
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

	-- The controls, in view: start or pause (lit while it isn't running), go where it drops, keep it as a favorite,
	-- reset: the session saved in your past ones, the table cleared (asked twice).
	card.tools = {}
	local WORDS = { main = "Start", find = "Find", stop = "Reset" }
	for i, key in ipairs({ "main", "find", "stop" }) do
		local b = UI.Button(card, WORDS[key], 60, function() if Card.Tool then Card.Tool(key) end end)
		b:SetHeight(22)
		card.tools[i], card.tools[key] = b, b
	end
	UI.Twice(card.tools.stop, function() if Card.Tool then Card.Tool("stop") end end)
	-- (What can't be seen on it: the session isn't lost.)
	UI.Help(card.tools.stop, "Reset", "Clears the table and starts fresh. This session is saved in your past sessions.", { side = "CURSOR" })
	card.foot:SetHeight(22)

	card.quiet = UI.Text(face, "", 12, true, C.dim)
	card.quiet:SetJustifyH("CENTER")
	card.quietLine = UI.Text(face, "", 11, false, C.dim)
	card.quietLine:SetJustifyH("CENTER")

	card.rows = {}
	-- The loot's list: it scrolls when there is more than the card has room for (the wheel is the list's only then, the
	-- camera's otherwise), every thing in it.
	card.list = UI.ScrollArea(card, K.WIDTH - 2 * K.PAD, 100, { quiet = true, smooth = true, shades = C.hud })

	-- Where everything stands, from the top, for the blocks the view has.
	-- (Everything under the header stands on the card's body: clear of the look's work round the edge, UI.Body.)
	function card:Lay(view)
		local inside = UI.Body(self)
		local width = UI.BodySize(self)
		local inner = width - 2 * K.PAD
		-- In the strip: the clock where the controls end.
		local head = self.head
		self.clock:ClearAllPoints()
		self.clock:SetPoint("RIGHT", self, "TOPRIGHT", -head.right, -head.mid)
		self.clockGlyph:ClearAllPoints()
		self.clockGlyph:SetPoint("RIGHT", self.clock, "LEFT", -4, 0)
		self.room:ClearAllPoints()

		local y = TOP + 4
		self.made:ClearAllPoints()
		self.made:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD, -y)
		self.rate:ClearAllPoints()
		self.rate:SetPoint("TOPRIGHT", inside, "TOPRIGHT", -K.PAD, -y)
		self.madeSays:ClearAllPoints()
		self.madeSays:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD + 1, -(y + 21))
		self.rateSays:ClearAllPoints()
		self.rateSays:SetPoint("TOPRIGHT", inside, "TOPRIGHT", -K.PAD - 1, -(y + 21))
		self.glow:ClearAllPoints()
		self.glow:SetPoint("TOPLEFT", inside, "TOPLEFT", 4, -(y - 6))
		self.glow:SetPoint("BOTTOMRIGHT", inside, "TOPRIGHT", -4, -(y + K.HERO))
		y = y + K.HERO
		self.rule:ClearAllPoints()
		self.rule:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD, -y)
		self.rule:SetPoint("TOPRIGHT", inside, "TOPRIGHT", -K.PAD, -y)
		local x = K.PAD
		for _, stat in ipairs(self.stats) do
			stat.glyph:ClearAllPoints()
			stat.glyph:SetPoint("LEFT", inside, "TOPLEFT", x, -(y + K.STATS / 2 + 1))
			stat.words:ClearAllPoints()
			stat.words:SetPoint("LEFT", stat.glyph, "RIGHT", 4, 0)
			if stat.words:IsShown() then x = x + 13 + 4 + stat.words:GetStringWidth() + 14 end
		end
		self.room:SetPoint("RIGHT", inside, "TOPRIGHT", -K.PAD, -(y + K.STATS / 2 + 1))
		self.room:SetJustifyH("RIGHT")
		y = y + K.STATS
		do
			-- (Only the controls that mean something now, sharing the width: no Go there or Favorite with nothing picked.)
			local gap, shown = 5, {}
			for _, b in ipairs(self.tools) do if b:IsShown() then shown[#shown + 1] = b end end
			local each = math.floor((inner - (#shown - 1) * gap) / math.max(1, #shown))
			for i, b in ipairs(shown) do
				b:ClearAllPoints()
				b:SetWidth(each)
				b:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD + (i - 1) * (each + gap), -(y + 2))
			end
			y = y + K.TOOLS
		end
		self.want:ClearAllPoints()
		self.want:SetShown(view ~= nil and Picked(view))
		if self.want:IsShown() then
			self.want:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD, -y)
			self.want:SetPoint("TOPRIGHT", inside, "TOPRIGHT", -K.PAD, -y)
			y = y + K.WANT
		end
		self.ask:ClearAllPoints()
		self.ask:SetShown(view and view.ask ~= nil or false)
		if self.ask:IsShown() then
			self.ask:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD, -y)
			self.ask:SetPoint("TOPRIGHT", inside, "TOPRIGHT", -K.PAD, -y)
			local shown, gap = {}, 6
			for _, b in ipairs(self.ask.buttons) do if b:IsShown() then shown[#shown + 1] = b end end
			local each = math.floor((inner - (#shown - 1) * gap) / math.max(1, #shown))
			for i, b in ipairs(shown) do
				b:ClearAllPoints()
				b:SetWidth(each)
				b:SetPoint("TOPLEFT", self.ask, "TOPLEFT", (i - 1) * (each + gap), -20)
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
		self.list:ClearAllPoints()
		self.list:SetPoint("TOPLEFT", inside, "TOPLEFT", K.PAD, -self.listTop)
		self.list:SetPoint("BOTTOMRIGHT", inside, "BOTTOMRIGHT", -K.PAD, (view and view.foot and K.FOOT or 0) + K.END)
		self.foot:ClearAllPoints()
		self.foot:SetPoint("BOTTOMLEFT", inside, "BOTTOMLEFT", K.PAD, K.END)
		self.foot:SetPoint("BOTTOMRIGHT", inside, "BOTTOMRIGHT", -K.PAD, K.END)
		self.quiet:ClearAllPoints()
		self.quiet:SetPoint("TOP", inside, "TOP", 0, -(self.listTop + 10))
		self.quietLine:ClearAllPoints()
		self.quietLine:SetPoint("TOP", self.quiet, "BOTTOM", 0, -4)
		self.quietLine:SetWidth(inner - 16)
	end

	-- Loot rows the card has room for at its height.
	function card:Places(view)
		local fixed = TOP + 4 + K.HERO + K.STATS + K.TOOLS + (Picked(view) and K.WANT or 0)
			+ (view.ask and K.ASK or 0)
			+ (view.foot and K.FOOT or 0) + K.END + 2
		local height = select(2, Room(self))
		return math.max(1, math.floor((height - fixed) / K.ROW))
	end

	-- Draws a view (Card.View's, or the sample).
	function card:Fill(view)
		self.view = view
		self.title:SetText(view.title)
		self:FillRoom(view.room)
		self.clock:SetText(view.clockWords or Clock(view.seconds))
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
		self:FillTools(view.tools)
		self:FillWant(view.want, view.target)
		self:FillAsk(view.ask)
		self.foot:SetShown(view.foot ~= nil)
		if view.foot then
			self.foot:SetLabel(view.foot.text)
			self.foot:SetUsable(not view.foot.busy, "Looking them up")
			if self.foot.SetPrimary then self.foot:SetPrimary(not view.foot.busy) end
		end
		self:Lay(view)
		local rows = view.rows
		local list = self.list
		list.content:SetHeight(math.max(1, #rows * K.ROW))
		list:Update()
		-- (Room for the list's thumb only while it has more to show.)
		local width = Room(self) - 2 * K.PAD - (list:Overflows() and K.THUMB or 0)
		list.content:SetWidth(width)
		for i = 1, math.max(#rows, #self.rows) do
			local data, row = rows[i], self.rows[i]
			if data then
				if not row then
					row = NewRow(self)
					self.rows[i] = row
					row:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(i - 1) * K.ROW)
					row:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
				end
				PaintRow(row, data, width)
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

	-- Bag space: { free, total }, or nil where it can't be told (nothing shows then).
	function card:FillRoom(room)
		self.room:SetShown(room ~= nil)
		if not room then return end
		local color = room.free <= 0 and C.bad or room.free <= K.FEW and C.alert or C.dim
		self.room:SetText(room.free <= 0 and "Bags full" or room.free == 1 and "1 slot free" or (room.free .. " slots free"))
		UI.Ink(self.room, color)
	end

	function card:FillTools(t)
		local tools = self.tools
		t = t or {}
		tools.main:SetLabel(t.main or "Start")
		if tools.main.SetPrimary then tools.main:SetPrimary(t.primary == true) end
		-- (The same three in the same places, always: Find while there is a finder, Reset dim with nothing to reset.)
		tools.find:SetShown(Card.CanFind ~= nil and Card.CanFind())
		tools.stop:SetUsable(t.ends ~= false, "Nothing to reset yet")
		-- On what you farm: Go there with something picked, Favorite with an item counted.
		local want = self.want
		local farmed = t.farmed or t.want ~= nil
		want.go:SetShown(farmed and t.go ~= false)
		want.star:SetShown(t.want ~= nil)
		if want.star.SetOn then want.star:SetOn(t.favorite == true) end
	end

	-- What you farm: the item counted (w), else the creature (target.kind "mob"), else everything you loot, with Find.
	function card:FillWant(w, target)
		local want = self.want
		local mode = w and "item" or (target and target.kind == "mob" and "mob") or "any"
		want.mode = mode
		-- (The line gives way to Go there and Favorite where they stand: FillTools says which, before this.)
		local first = (want.go:IsShown() and want.go) or (want.star:IsShown() and want.star) or nil
		want.name:ClearAllPoints()
		want.name:SetPoint("TOPLEFT", want.icon, "TOPRIGHT", 9, -2)
		want.name:SetPoint("RIGHT", want.count, "LEFT", -6, 0)
		want.line:ClearAllPoints()
		want.line:SetPoint("TOPLEFT", want.name, "BOTTOMLEFT", 0, -4)
		want.line:SetPoint("RIGHT", first or want, first and "LEFT" or "RIGHT", first and -6 or -2, 0)
		want.sign:SetShown(mode ~= "item")
		want.icon:SetShown(mode == "item")
		want.slot:Empty(mode ~= "item")
		if mode == "any" then
			Hover.Glyph(want.sign, "bag", K.SIGN)
			UI.Tint(want.sign, C.dim)
			want.name:SetText("Anything you loot")
			UI.Ink(want.name, C.text)
			want.count:SetText("")
			want.line:SetText(T.db.value == "vendor" and "It all counts, at vendor prices" or "It all counts, at auction prices")
			want.bar:Hide()
			return
		end
		if mode == "mob" then
			Hover.Glyph(want.sign, "kill", K.SIGN)
			UI.Tint(want.sign, C.text)
			want.name:SetText(target.name or "\226\128\166")
			UI.Ink(want.name, C.text)
			want.count:SetText(Plural(target.kills or 0, "kill", "kills"))
			UI.Ink(want.count, C.hot)
			local words = {}
			if target.worth and target.worth > 0 then words[#words + 1] = P.Text(target.worth, 11, want.line) .. " a kill" end
			if target.rate and target.rate > 0 then words[#words + 1] = ("%d kills an hour"):format(math.floor(target.rate + 0.5)) end
			if #words < 2 and target.level then words[#words + 1] = target.level end
			want.line:SetText(#words > 0 and table.concat(words, K.SEP) or "Everything it drops counts")
			want.bar:Hide()
			return
		end
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
		-- (One of a creature's drops: whose, first.)
		if target and target.kind == "mob" and w.from then table.insert(words, 1, "from " .. w.from) end
		if #words == 0 then
			local from = w.from
			words[1] = from and ("from " .. from) or (w.got and w.got > 0 and (w.got .. " this session") or "none yet")
		end
		while #words > 3 do table.remove(words) end
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
		local auction = P.Auctions()
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

-- The card's height with the view's blocks and `rows` loot rows.
function Card.Height(view, rows)
	return TOP + 4 + K.HERO + K.STATS + K.TOOLS + (Picked(view) and K.WANT or 0) + (view.ask and K.ASK or 0)
		+ rows * K.ROW
		+ (view.foot and K.FOOT or 0) + K.END + 2
end

Card.K = K
