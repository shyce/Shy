-- The console's step in ShyCore's setup window: use the console or leave the
-- screen alone, which layout (a card each: the screen's bottom band with that
-- layout, where the four differ), which size, whether the bars grow with the
-- character or come all at once, whether each side bar stands out or tucks
-- away in its drawer, whether the menu tucks into a drawer, and
-- (with ShyBags) whether the bag buttons stand with the menu or in the bags.
-- Layout.SetUp only ever runs from a player's click. Every pick goes on the screen as it is made, the
-- picks standing when the page comes up too (O.Wear); closing without Finish puts back what stood.
--
-- The page flows to the width the window gives it (700 to 1000 across):
--   a band naming what happens to your screen, "Set it up" or "Keep mine" at its right; gold while the
--   layout in use is one you made your own (Layout.Custom), which Finish then leaves alone
--   the layouts as cards, four across in two rows, the one picked lit, the one in use badged
--   two columns under them, a section each under a caption with its small drawing at the caption's end:
--   the size and the bars at the left, the side bars and the menu (and the bag buttons) at the right; a
--   choice that doesn't apply to the layout picked isn't shown, and the section says why

local ADDON, ns = ...
local UI = Shy.UI
local S = Shy.Setup
local C = UI.colors
local min, max, floor = math.min, math.max, math.floor

local O = {}
ns.Offer = O

-- What a first setup from this window switches on (Layout.lua, Furnish). The damage meter, cooldown
-- manager and personal resource display are the game step's settings: that step runs first.
local MADE_OF = "action bars 2 to 5"

-- Keys laid out, or about to be (ShyCore's keys, its pick in this window): a layout of keys stands on every
-- bar, the flyout's with them, so the bars don't grow with the character; they are all there.
local function Keyed()
	return Shy.Keys ~= nil and Shy.Keys.Wanted and Shy.Keys.Wanted() or false
end

-- Whether the picks give bars that grow.
local function Grow(pick)
	return pick.grow and not Keyed() and true or false
end

function O.Lines(plan)
	local L = ns.Layout
	local pick = plan.screen
	if not pick.on and pick.custom then
		return { { text = "Your own layout stays as it is", sub = "pick a layout on the Screen page to start fresh" } }
	elseif not pick.on then
		return { { text = "Your screen stays as it is", sub = "you can set up the console later from /shy" } }
	end
	local name = ns.Preview.NAMES[pick.size]
	local style = pick.style or L.Style()
	local sub
	if L.IsActive() then
		sub = L.Size() == pick.size and L.Style() == style and "its layout is rewritten so every piece fits"
			or "its layout is rewritten at this size, chat text included"
	elseif ns.char.furnished or Grow(pick) then
		sub = "as a new Edit Mode layout; your own layout is kept"
	else
		sub = "as a new Edit Mode layout; turns on " .. MADE_OF
	end
	if Grow(pick) then sub = sub .. "; bars grow with you" end
	if pick.drawer then sub = sub .. "; the menu in a drawer" end
	if pick.bags == "screen" then sub = sub .. "; bag buttons with the menu" end
	local away = {}
	for _, side in ipairs({ "left", "right" }) do
		if pick.sides and pick.sides[side] == false then away[#away + 1] = side end
	end
	if #away == 2 then sub = sub .. "; both side bars tucked away"
	elseif #away == 1 then sub = sub .. "; the " .. away[1] .. " side bar tucked away" end
	local named = ns.Preview.STYLE_NAMED[style]:gsub("^%l", string.upper)
	return { { text = named .. " is set up at " .. name, sub = sub } }
end

-- The band's two lines: what happens to your screen, and what that means. The third answer: the band's edge in
-- gold (the screen is the player's own, or a reason it can't be set up).
function O.BandWords(pick)
	local L, P = ns.Layout, ns.Preview
	if not pick.on then
		if pick.custom == "own" then
			return "You're on your own layout" .. (pick.named and (", " .. pick.named) or ""),
				"Finish leaves it alone. Pick a layout below to switch.", true
		elseif pick.custom then
			return "You changed your layout yourself", "Finish leaves it alone. Pick a layout below to start fresh.", true
		end
		return "Your screen stays as it is", "You can set up the console later from /shy.", false
	end
	local title = P.STYLES[pick.style or L.Style()] .. ", " .. P.NAMES[pick.size]:lower()
	local ok, why = L.CanSetUp()
	if not ok then return title, L.Words(why), true end
	if pick.custom == "own" then return title, "This takes over from your layout. Yours stays in Edit Mode's list.", true end
	if pick.custom then return title, "You'll lose the changes you made to your layout. Keep mine to hold on to them.", true end
	if L.IsActive() then return title, "Your bars, chat and meter are laid out again with what you pick.", false end
	return title, "Added as a new Edit Mode layout. Your own layout is kept.", false
end

-- The page's measures. BAND: the band's height; RING, GLYPH: the dial at its left and the glyph in it; EDGE: its
-- edge's width; CHOICE: "Set it up | Keep mine"; SEG: a choice's height; CAPTION: a section's caption; UNDER: from a
-- caption to its choices; WORDS: from the choices to their words; SECTION: between two sections down a column;
-- COLUMNS: between the columns; LABEL: a choice's small name (Left, Right, Menu, Bags) to the choice; PAIR: between
-- two choices on a line; SIZE, BARS, SIDE, MENU, BAGS: the choices' widths; ONE_LINE: the column width the menu's
-- two choices stand on one line from.
local M = { GAP = 8, BAND = 54, RING = 38, GLYPH = 20, EDGE = 3, CHOICE = 196, SEG = 24, CAPTION = 14, UNDER = 9,
	WORDS = 6, SECTION = 16, COLUMNS = 28, LABEL = 6, PAIR = 18, SIZE = 252, BARS = 236, SIDE = 112, MENU = 148,
	BAGS = 196, ONE_LINE = 420, CARDS_TOP = 12, OPTIONS_TOP = 18 }

local BARS = { { key = true, text = "Grow with me" }, { key = false, text = "Every bar now" } }
local ROWS = { "One bar", "Two bars", "Three bars" }
local BAGS = { { key = "window", text = "In my bags" }, { key = "screen", text = "With the menu" } }

-- ShyBags, while it has the bag buttons as one choice; nil without it: the default bar stays.
local function Keeper()
	local bags = Shy.addons.Bags
	return bags and bags.BagButtons and bags.SetBagButtons and bags or nil
end

-- What the menu's drawer and the bag buttons come to, in a sentence each.
local function MenuWords(drawer)
	return drawer and "The menu tucks under the guide until you point at it." or "The menu stays out under the minimap."
end
local function BagWords(keeper, where, drawer)
	if where == "screen" then
		return (drawer and "The bag bar tucks into the drawer with the menu." or "The bag bar stands under the menu.")
			.. " Click a bag to open them all."
	end
	local key = keeper.BagsKey and keeper:BagsKey()
	return "A slot for each bag beside your items. " .. (key and (key .. " opens your bags.") or "No key opens your bags yet.")
end

-- The side bars: each out beside the bars or tucked away in its drawer (Drawers.lua's racks), the picks in
-- plan.screen.sides = { left =, right = } (true: out).
local SIDES = { { key = "left", text = "Left" }, { key = "right", text = "Right" } }
local OUT = { { key = true, text = "Out" }, { key = false, text = "Tucked" } }

-- Which side bars the picks give: none in the stack, the left one only once bar 5 is on.
local function SidesThere(pick)
	local g = ns.Layout.Plan(pick.size, true, pick.style, pick.grow and true or "all")
	local rects = g.rack and g.rack.kind ~= "row" and g.rack.rects or {}
	return { left = rects[-1] ~= nil, right = rects[1] ~= nil }
end

local function SideWords(out, there)
	if not (there.left or there.right) then return "No side bars in this layout." end
	if (there.left and not out.left) or (there.right and not out.right) then
		return "Tucked away, it slides out when you point at its handle."
	end
	return (there.left and there.right) and "Both side bars stay out." or "The side bar stays out."
end

-- A choice of a few (UI.Segmented) whose choices show on the page while pointed at: look(i) as one is, look(nil)
-- as the mouse leaves.
local function Choice(parent, labels, width, get, set, look)
	local seg = UI.Segmented(parent, labels, get, set, { width = width, height = M.SEG })
	for i, b in ipairs(seg.buttons) do
		b:HookScript("OnEnter", function() look(i) end)
		b:HookScript("OnLeave", function() look(nil) end)
	end
	return seg
end

-- The band over the cards: a dial with the screen's glyph, what happens to your screen and what that means, and
-- the choice at its right. Its edge and dial wear the accent, or gold while the screen is the player's own.
local function Band(f, width, plan)
	local band = CreateFrame("Frame", nil, f)
	band:SetSize(width, M.BAND)
	UI.Skin(band, C.row, C.border)
	band.edge = band:CreateTexture(nil, "ARTWORK")
	band.edge:SetPoint("TOPLEFT", 1, -1)
	band.edge:SetPoint("BOTTOMLEFT", 1, 1)
	band.edge:SetWidth(M.EDGE)
	local ring = band:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(Shy.MEDIA .. "DialMid")
	ring:SetSize(M.RING, M.RING)
	ring:SetPoint("CENTER", band, "LEFT", M.EDGE + 10 + M.RING / 2, 0)
	UI.Tint(ring, Shy.Theme.skin.metal)
	band.glyph = band:CreateTexture(nil, "ARTWORK", nil, 1)
	band.glyph:SetSize(M.GLYPH, M.GLYPH)
	band.glyph:SetPoint("CENTER", ring, "CENTER")
	UI.GlyphArt(band.glyph, "window")
	UI.Concentric(ring, band.glyph)
	band.choice = UI.Segmented(band, { "Set it up", "Keep mine" }, function() return plan.screen.on and 1 or 2 end, function(i)
		plan.screen.on = i == 1
		O.Wear(plan)
		f:Refresh()
	end, { width = M.CHOICE, height = M.SEG + 2 })
	band.choice:SetPoint("RIGHT", -12, 0)
	band.title = UI.Text(band, "", 14, true, C.head)
	band.title:SetPoint("TOPLEFT", M.EDGE + 10 + M.RING + 12, -10)
	band.title:SetPoint("RIGHT", band.choice, "LEFT", -16, 0)
	band.title:SetWordWrap(false)
	band.title:SetJustifyH("LEFT")
	band.line = UI.Text(band, "", 11, false, C.dim)
	band.line:SetPoint("TOPLEFT", band.title, "BOTTOMLEFT", 0, -4)
	band.line:SetPoint("RIGHT", band.choice, "LEFT", -16, 0)
	band.line:SetWordWrap(false)
	band.line:SetJustifyH("LEFT")
	function band:Tell(pick)
		local title, line, gold = O.BandWords(pick)
		self.title:SetText(title)
		self.line:SetText(line)
		UI.Ink(self.line, gold and C.alert or C.dim)
		local edge = gold and C.alert or (pick.on and Shy.Theme.Accent or C.border)
		Shy.Theme.Paint(self.edge, edge, 1)
		UI.Tint(self.glyph, gold and C.alert or (pick.on and Shy.Theme.Accent or C.dim))
		-- "Keep mine" for a screen of the player's own; else what it is: leaving the screen as it is.
		self.choice.buttons[2].text:SetText(pick.custom and "Keep mine" or "Leave it")
		self.choice:Refresh()
	end
	return band
end

-- A section: its caption with a rule after it (a small drawing at its end, when it has one), its choices under it,
-- then its words, wrapping in the column's width.
local function Section(f, x, y, width, title, drawing)
	local s = CreateFrame("Frame", nil, f)
	s:SetPoint("TOPLEFT", x, y)
	s:SetWidth(width)
	s.caption = Shy.Hub.Caption(s, width, title)
	s.caption:SetPoint("TOPLEFT")
	if drawing then
		drawing:SetParent(s)
		drawing:ClearAllPoints()
		drawing:SetPoint("RIGHT", s.caption, "RIGHT", 0, 0)
		s.caption.rule:SetPoint("RIGHT", drawing, "LEFT", -8, 0)
	end
	s.words = UI.Text(s, "", 11, false, C.dim)
	s.words:SetWidth(width)
	s.words:SetWordWrap(true)
	s.words:SetJustifyH("LEFT")
	-- Its words under the last line of its choices, `lines` of them; its height to the words' foot.
	function s:Under(lines)
		local top = M.CAPTION + M.UNDER + lines * M.SEG + (lines - 1) * M.WORDS
		self.words:ClearAllPoints()
		self.words:SetPoint("TOPLEFT", 0, -(top + M.WORDS))
		self.top = top
	end
	function s:Tall()
		return self.top + M.WORDS + max(14, self.words:GetStringHeight() or 14)
	end
	-- A choice on line `line` (from 1), `at` across, a small name before it when given.
	function s:Put(seg, line, at, label)
		local y = -(M.CAPTION + M.UNDER + (line - 1) * (M.SEG + M.WORDS))
		if label then
			label:ClearAllPoints()
			label:SetPoint("LEFT", s, "TOPLEFT", at, y - M.SEG / 2)
			at = at + label:GetStringWidth() + M.LABEL
		end
		seg:ClearAllPoints()
		seg:SetPoint("TOPLEFT", at, y)
		return at + seg:GetWidth()
	end
	return s
end

local function Label(parent, text)
	return UI.Text(parent, text, 11, false, C.text)
end

function O.Build(parent, width, plan)
	local L, P = ns.Layout, ns.Preview
	local f = CreateFrame("Frame", nil, parent)
	local looking, lookingStyle, lookingBars   -- the size, the layout and the bars choice under the mouse
	local lookingBags, lookingSide             -- where the bag buttons are, and a side bar's choice, under the mouse
	local lookingDrawer                        -- the menu's choice under the mouse
	local cards = {}
	-- Every housing drawn wears the look the theme step picked, so the screen is shown as setup leaves it.
	local function Look() return plan.theme and plan.theme.look end
	-- A pick: the screen is set up with it (picked over a screen kept as it is, it starts fresh).
	local function Pick(field, value)
		plan.screen.on, plan.screen[field] = true, value
		O.Wear(plan)
		f:Refresh()
	end
	-- (The choices light their pick only while the screen is set up: kept as it is, nothing is picked.)
	local function Lit(i) return plan.screen.on and i end

	local band = Band(f, width, plan)
	band:SetPoint("TOPLEFT")

	-- The cards, one a layout: the classic ones in a row, those by role in a row under them.
	local y = -(M.BAND + M.CARDS_TOP)
	for _, row in ipairs(P.STYLE_ROWS) do
		local count = #row[2]
		local cardW = (width - (count - 1) * M.GAP) / count
		for i, key in ipairs(row[2]) do
			local card = P.Card(f, cardW, key, function(picked) Pick("style", picked) end, function(over)
				lookingStyle = over
				f:Refresh()
			end, Look)
			card:SetPoint("TOPLEFT", (i - 1) * (cardW + M.GAP), y)
			cards[key] = card
		end
		y = y - P.CardHeight(cardW) - M.GAP
	end
	local painter = P.Painter(f)

	-- Two columns under the cards, a hairline between them.
	local top = y - M.OPTIONS_TOP + M.GAP
	local column = (width - M.COLUMNS) / 2
	local right = column + M.COLUMNS
	local hairline = f:CreateTexture(nil, "ARTWORK")
	Shy.Theme.Paint(hairline, C.border, 0.5)
	hairline:SetWidth(1)
	hairline:SetPoint("TOPLEFT", column + M.COLUMNS / 2, top)

	-- The size.
	local sizeKeys = ns.Console.SIZE_ORDER
	local sizeLabels = {}
	for i, key in ipairs(sizeKeys) do sizeLabels[i] = P.NAMES[key] end
	local size = Section(f, 0, top, column, "Size")
	local sizes = Choice(size, sizeLabels, min(M.SIZE, column), function()
		for i, key in ipairs(sizeKeys) do
			if key == plan.screen.size then return Lit(i) end
		end
		return false
	end, function(i) Pick("size", sizeKeys[i]) end, function(i)
		looking = i and sizeKeys[i] or nil
		f:Refresh()
	end)
	size:Put(sizes, 1, 0)
	size:Under(1)

	-- The bars: grow with you, or every bar now (not while your keys are laid out: they stand on every bar).
	local drawing = P.BarsDrawing(f, 4, 1)
	local barsSection = Section(f, 0, 0, column, "Bars", drawing)
	local bars = Choice(barsSection, { BARS[1].text, BARS[2].text }, min(M.BARS, column), function()
		return Lit(Grow(plan.screen) and 1 or 2)
	end, function(i)
		if BARS[i].key and Keyed() then return end
		Pick("grow", BARS[i].key)
	end, function(i)
		lookingBars = i and BARS[i] or nil
		f:Refresh()
	end)
	barsSection:Put(bars, 1, 0)
	barsSection:Under(1)

	-- The side bars: for each side, out or tucked away; only the sides the layout picked has.
	local sideDrawing = P.SidesDrawing(f)
	local sideSection = Section(f, right, top, column, "Side bars", sideDrawing)
	local sides, sideNames = {}, {}
	for _, side in ipairs(SIDES) do
		sideNames[side.key] = Label(sideSection, side.text)
		sides[side.key] = Choice(sideSection, { OUT[1].text, OUT[2].text }, M.SIDE, function()
			local out = plan.screen.sides
			return Lit((out and out[side.key] == false) and 2 or 1)
		end, function(i)
			plan.screen.sides = plan.screen.sides or { left = true, right = true }
			plan.screen.sides[side.key] = OUT[i].key
			Pick("sides", plan.screen.sides)
		end, function(i)
			lookingSide = i and { side = side.key, out = OUT[i].key } or nil
			f:Refresh()
		end)
	end
	sideSection:Under(1)

	-- The menu: out under the minimap or in a drawer; with ShyBags, the bag buttons with the menu or in the bags.
	local keeper = Keeper()
	local hasBags = keeper ~= nil and plan.screen.bags ~= nil
	local bagDrawing = hasBags and P.BagsDrawing(f) or nil
	local menuSection = Section(f, right, 0, column, hasBags and "Menu and bags" or "Menu", bagDrawing)
	local menuName = Label(menuSection, "Menu")
	local menu = Choice(menuSection, { "Out", "In a drawer" }, M.MENU, function()
		return Lit(plan.screen.drawer and 2 or 1)
	end, function(i) Pick("drawer", i == 2) end, function(i)
		lookingDrawer = i and (i == 2) or nil
		f:Refresh()
	end)
	local bagName, bagChoice
	if hasBags then
		bagName = Label(menuSection, "Bags")
		bagChoice = Choice(menuSection, { BAGS[1].text, BAGS[2].text }, M.BAGS, function()
			return Lit(plan.screen.bags == "screen" and 2 or 1)
		end, function(i) Pick("bags", BAGS[i].key) end, function(i)
			lookingBags = i and BAGS[i].key or nil
			f:Refresh()
		end)
	end
	local after = menuSection:Put(menu, 1, 0, menuName)
	local lines = 1
	if bagChoice then
		if column >= M.ONE_LINE then
			menuSection:Put(bagChoice, 1, after + M.PAIR, bagName)
		else
			lines = 2
			menuSection:Put(bagChoice, 2, 0, bagName)
		end
	end
	menuSection:Under(lines)

	f.cards, f.band, f.sizes, f.bars, f.sides, f.menu, f.bags = cards, band, sizes, bars, sides, menu, bagChoice
	f.words, f.barWords, f.sideWords, f.menuWords = size.words, barsSection.words, sideSection.words, menuSection.words
	f.drawing, f.sideDrawing, f.bagDrawing = drawing, sideDrawing, bagDrawing
	f.sections = { size, barsSection, sideSection, menuSection }

	-- The sections down each column, each under the one before as tall as its words make it; the page as tall as
	-- the taller column.
	local function Stack()
		barsSection:ClearAllPoints()
		barsSection:SetPoint("TOPLEFT", 0, top - size:Tall() - M.SECTION)
		menuSection:ClearAllPoints()
		menuSection:SetPoint("TOPLEFT", right, top - sideSection:Tall() - M.SECTION)
		local leftTall = size:Tall() + M.SECTION + barsSection:Tall()
		local rightTall = sideSection:Tall() + M.SECTION + menuSection:Tall()
		hairline:SetHeight(max(leftTall, rightTall))
		for _, s in ipairs(f.sections) do s:SetHeight(s:Tall()) end
		f:SetSize(width, -top + max(leftTall, rightTall) + 4)
	end

	function f:Refresh()
		local pick = plan.screen
		local active, inUse, sizeNow = L.IsActive(), L.Style(), L.Size()
		local shown = looking or pick.size
		local style = lookingStyle or pick.style or inUse
		-- (The bars choice under the mouse, whichever it is: "every bar now" has `false` for its key.)
		local keyed = Keyed()
		local grow = Grow(pick)
		if lookingBars and not keyed then grow = lookingBars.key end
		band:Tell(pick)
		-- Drawn with the bars the choice gives: the step the abilities call for, or every bar.
		local barsDrawn = grow and true or "all"
		-- (Each card laid again only where it would show something else, one a frame: a layout pointed at changes
		-- none of them, a size pointed at all.)
		local from = P.From(Look())
		painter:Forget()
		for _, row in ipairs(P.STYLE_ROWS) do
			for _, key in ipairs(row[2]) do painter:Ask(cards[key].stage, shown, key, barsDrawn, from) end
		end
		-- The layout in use, changed by the player since it was set up, is badged as theirs.
		local used = pick.custom == "changed" and "custom" or true
		for key, card in pairs(cards) do
			card:Paint(pick.on and pick.style == key, active and inUse == key and used, not pick.on)
		end
		-- Kept as it is, the choices are quiet: one picked starts the screen fresh.
		local quiet = pick.on and 1 or 0.55
		for _, s in ipairs(f.sections) do s:SetAlpha(quiet) end
		sizes:Refresh()
		bars:Refresh()
		menu:Refresh()
		if bagChoice then bagChoice:Refresh() end

		-- The size: what the one picked or pointed at is.
		size.words:SetText(not pick.on and "Your screen keeps the size it has."
			or (P.WORDS[shown] .. (active and sizeNow == shown and " In use." or "")))

		-- The bars.
		bars.buttons[1]:SetAlpha(keyed and 0.4 or 1)
		local step = grow and L.GrowStep() or #L.STEPS
		drawing:Paint(nil, L.STEPS[step])
		if not pick.on then
			barsSection.words:SetText("Your bars stay as they are.")
		elseif keyed then
			barsSection.words:SetText("Your keys stand on every bar, so they're all there from the start, the flyout with them.")
		elseif grow and step == #L.STEPS then
			barsSection.words:SetText(("You know %d abilities or already use every bar, so they're all there from the start."):format(L.Abilities()))
		elseif grow then
			local have = L.STEPS[step]
			local sideBars = have.sides > 1 and "both side bars" or "a side bar for food and potions"
			barsSection.words:SetText(("%s and %s to start. You're offered more as you learn abilities. You know %d."):format(
				ROWS[have.rows], sideBars, L.Abilities()))
		else
			barsSection.words:SetText("Three rows and both side bars from the start, as the game has them.")
		end

		-- The side bars: the ones the layout has, as picked or pointed at. A layout that shows its bars as you point
		-- at them (the minimal one) has them show with the others: no choice there.
		local out = pick.sides or { left = true, right = true }
		local shownOut = { left = out.left ~= false, right = out.right ~= false }
		if lookingSide then shownOut[lookingSide.side] = lookingSide.out end
		local there = SidesThere({ size = shown, style = style, grow = grow })
		local role = ns.Console.ROLE[style]
		local revealed = role ~= nil and role.reveal == true
		local at = 0
		for _, side in ipairs(SIDES) do
			local here = there[side.key] and not revealed
			sides[side.key]:SetShown(here)
			sideNames[side.key]:SetShown(here)
			if here then
				at = sideSection:Put(sides[side.key], 1, at, sideNames[side.key]) + M.PAIR
				sides[side.key]:Refresh()
			end
		end
		local anySide = at > 0
		sideSection:Under(anySide and 1 or 0)
		sideDrawing:Paint(shownOut, there)
		sideDrawing:SetShown(there.left or there.right)
		sideSection.words:SetText((not pick.on and "Your side bars stay as they are.")
			or (revealed and "They show with your other bars while you point at them.") or SideWords(shownOut, there))

		-- The menu, and the bag buttons.
		local drawer = pick.drawer
		if lookingDrawer ~= nil then drawer = lookingDrawer end
		local where = lookingBags or pick.bags
		if bagDrawing then bagDrawing:Paint(where) end
		if not pick.on then
			menuSection.words:SetText(bagChoice and "Your menu and bag buttons stay where they are." or "Your menu stays where it is.")
		else
			menuSection.words:SetText(MenuWords(drawer) .. (bagChoice and (" " .. BagWords(keeper, where, drawer)) or ""))
		end
		Stack()
	end
	return f
end

-- A character the console has never been set up for starts with bars that grow;
-- one set up before keeps the bars it has unless the player picks otherwise.
local function Grows()
	local grow = ns.char.grow
	if grow == nil then return not ns.Layout.IsActive() end
	return grow
end

-- The drawer and the bag buttons are profile settings: written now when the character stays on its
-- profile, else kept by the setup until the profile it switches to has loaded after the reload.
local function Keep(answers)
	ns.T.db.menuDrawer = answers.drawer and true or false
	local keeper = Keeper()
	if keeper and answers.bags then keeper:SetBagButtons(answers.bags) end
end

-- Live: the layout written and applied now (Layout.SetUp's live way), the drawer and the bag buttons set.
-- Off, what stood when the window opened (worn) goes back. Nothing is written for picks that stand already.
local worn

local function SetMenu(drawer, bags)
	ns.T.db.menuDrawer = drawer
	local keeper = Keeper()
	if keeper and bags then keeper:SetBagButtons(bags) end
end

local function Standing(pick)
	local L, keeper = ns.Layout, Keeper()
	return L.IsActive() and not L.IsStale() and L.Size() == pick.size and L.Style() == (pick.style or L.Style())
		and Grows() == Grow(pick) and (ns.T.db.menuDrawer ~= false) == (pick.drawer and true or false)
		and not (keeper and pick.bags and keeper:BagButtons() ~= pick.bags)
end

-- The game's settings for what the layout holds (the game step's rows): put on before it is laid out, while
-- the plan picks them.
local PIECES = { "damageMeter", "cooldowns", "personalResource" }
local function Pieces(on)
	local changed = false
	for _, key in ipairs(PIECES) do
		if S.Live and S.Live(key, on) then changed = true end
	end
	return changed
end

function O.Wear(plan)
	local L, pick = ns.Layout, plan.screen
	if not worn or InCombatLockdown() then return end
	if not pick.on then
		Pieces(false)
		if not L.Previewing() then return end
		SetMenu(worn.drawer, worn.bags)
		L.Unpreview()
		ns.T:Apply()
		return
	end
	-- In a setup's order: the meter, the cooldown manager and your display first, then the bars, then the
	-- layout once they're up (Layout.Wear).
	-- The side bars are pinned out or tucked on the layout once it is the one in use (a pin is kept per layout).
	local function Racks()
		if pick.sides then ns.Drawers.PinRacks(pick.sides) end
	end
	local switched = Pieces(true)
	if not switched and Standing(pick) or not L.CanSetUp() then
		Racks()
		return
	end
	SetMenu(pick.drawer and true or false, pick.bags)
	L.Wear(pick.size, pick.style, { grow = Grow(pick), settle = switched }, function()
		ns.T:Apply()
		Racks()
	end)
end

S.Step({
	id = "screen", order = 20, title = "Screen", glyph = "window",
	ask = "How do you want your screen laid out?",
	lead = "Pick a layout and a size for your bars and chat. The pictures show how your screen will look.",
	brief = function(plan)
		local pick = plan.screen
		if not pick.on then return pick.custom and "Your own" or "As it is" end
		return ns.Preview.STYLES[pick.style or ns.Layout.Style()] .. ", " .. ns.Preview.NAMES[pick.size]:lower()
	end,
	last = true,   -- writing the layout ends in a reload, so every other step runs first
	-- A screen the player made their own (Layout.Custom) is kept unless a layout is picked: the console laid out
	-- again would undo every change.
	Plan = function(plan)
		local keeper = Keeper()
		local custom, named = ns.Layout.Custom()
		plan.screen = { on = not custom, custom = custom or nil, named = named, size = ns.Layout.Size(), style = ns.Layout.Style(), grow = Grows(), drawer = ns.T.db.menuDrawer ~= false,
			bags = keeper and keeper:BagButtons() or nil,
			sides = { left = ns.Drawers.RackOut("left"), right = ns.Drawers.RackOut("right") } }
	end,
	Build = O.Build,
	Check = function(plan)
		if not plan.screen.on then return true end
		local ok, why = ns.Layout.CanSetUp()
		return ok, not ok and ns.Layout.Words(why) or nil
	end,
	Lines = O.Lines,
	Run = function(plan)
		local pick = plan.screen
		if not pick.on then return false end
		local answers = { drawer = pick.drawer and true or false, bags = pick.bags }
		local opts = { grow = Grow(pick), pieces = false }
		if S.Act(plan) == "stay" then
			Keep(answers)
		else
			-- The layout is written for the picks; the settings follow once the profile has loaded.
			S.Wait("screen", answers)
			opts.drawer = answers.drawer
			if answers.bags then opts.bags = answers.bags == "screen" end
		end
		-- On the screen already (O.Wear): kept, and the reload settles what was applied live. Written again
		-- first if it no longer fits the picks (a piece unticked on the game page since).
		local sides = pick.sides and { left = pick.sides.left, right = pick.sides.right }
		if ns.Layout.Previewing() then
			opts.keep = true   -- (the menu's drawer as the player left it)
			if not Standing(pick) then ns.Layout.Report(ns.Layout.SetUp(pick.size, pick.style, opts)) end
			ns.Layout.Keep()
			if sides then ns.Drawers.PinRacks(sides) end
			return true
		end
		local ok = ns.Layout.Report(ns.Layout.SetUp(pick.size, pick.style, opts))
		-- The side bars' pins are the layout's: pinned again after the reload, once it is surely the one in use.
		if ok and sides then
			ns.Drawers.PinRacks(sides)
			ns.char.sides = sides
		end
		return ok
	end,
	Later = function(answers)
		Keep(answers)
		ns.T:Apply()
	end,
	Shown = function(plan) O.Wear(plan) end,
	Worn = function()
		local keeper = Keeper()
		worn = { drawer = ns.T.db.menuDrawer, bags = keeper and keeper:BagButtons() or nil,
			sides = { left = ns.Drawers.RackOut("left"), right = ns.Drawers.RackOut("right") } }
		return worn
	end,
	PutBack = function(kept, moving)
		worn = nil
		-- (Only what moved goes back: laying the console out again for nothing stalls the screen.)
		local keeper = Keeper()
		local changed = ns.T.db.menuDrawer ~= kept.drawer or (keeper and kept.bags and keeper:BagButtons() ~= kept.bags)
		if changed then SetMenu(kept.drawer, kept.bags) end
		if not moving then
			if ns.Layout.Previewing() then
				changed = true
				ns.Layout.Unpreview()
			end
			-- (Still the console's layout: one set up before. Its side bars as they were.)
			if kept.sides then ns.Drawers.PinRacks(kept.sides) end
			if ns.Layout.Owed() then Shy.Reload("Your screen is back as it was. Reload to finish.") end
		end
		if changed then ns.T:Apply() end
	end,
})
