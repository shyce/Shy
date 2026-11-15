-- The console's step in ShyCore's setup window: use the console or leave the
-- screen alone, which layout (a card each: the screen's bottom band with that
-- layout, where the four differ), which size, whether the bars grow with the
-- character or come all at once, whether each side bar stands out or tucks
-- away in its drawer, whether the menu tucks into a drawer, and
-- (with ShyBags) whether the bag buttons stand with the menu or in the bags.
-- Layout.SetUp only ever runs from a player's click. Every pick goes on the screen as it is made, the
-- picks standing when the page comes up too (O.Wear); closing without Finish puts back what stood.
--
-- The page, 1000 x 480 (ShyCore's Setup.lua), with nothing to scroll:
--   the switch
--   four cards across, the one picked lit
--   the screen drawn large with the layout picked or pointed at (600 wide), its name and line on a band
--   across its top; beside it the sizes, the bars and the menu (its drawer, and the bag buttons under
--   it) as a column of chips and words

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
	if not pick.on then
		return { { text = "Your screen stays as it is", sub = "you can set up the console later from /shy" } }
	end
	local name = ns.Preview.NAMES[pick.size]
	local style = pick.style or L.Style()
	local sub
	if L.IsActive() then
		sub = L.Size() == pick.size and L.Style() == style and "its layout is rewritten so every piece fits"
			or "its layout is rewritten at this size, chat text included"
	elseif ns.char.furnished or Grow(pick) then
		sub = "as an Edit Mode layout named \"Shy\"; your own layout is kept"
	else
		sub = "as an Edit Mode layout named \"Shy\"; turns on " .. MADE_OF
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

local GAP = 8
local CHIP_W, CHIP_H = 86, 24   -- a size chip
local BARS_W = 130              -- a bars chip
local ROW_X = 70                -- a row's chips start here, after its label
local ROW_GAP = 14              -- between two rows
local BARS = { { key = true, text = "Grow with me" }, { key = false, text = "Every bar now" } }
local ROWS = { "One bar", "Two bars", "Three bars" }
local BAGS = { { key = "window", text = "In my bags" }, { key = "screen", text = "With the menu" } }

-- ShyBags, while it has the bag buttons as one choice; nil without it: the default bar stays.
local function Keeper()
	local bags = Shy.addons.Bags
	return bags and bags.BagButtons and bags.SetBagButtons and bags or nil
end

-- What a choice of the bag buttons comes to.
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
local SIDE_W = 64   -- an out / tucked chip

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

-- A chip: a small button lit when picked; hovered, the page shows that choice.
local function Chip(parent, text, width, onClick, onLook)
	local b = UI.Button(parent, text, width, onClick)
	b:SetHeight(CHIP_H)
	b:HookScript("OnEnter", function() onLook(true) end)
	b:HookScript("OnLeave", function() onLook(false) end)
	function b:Paint(lit)
		UI.SetFill(self, lit and C.fill or C.bgHot)
	end
	return b
end

function O.Build(parent, width, plan)
	local L, P = ns.Layout, ns.Preview
	local f = CreateFrame("Frame", nil, parent)
	local looking, lookingStyle, lookingBars   -- the size, the layout and the bars choice under the mouse
	local lookingBags                          -- where the bag buttons are, under the mouse
	local take, cards, chips, barChips, bagChips = nil, {}, {}, {}, {}
	take = UI.Checkbox(f, "Set up my screen", function() return plan.screen.on end, function(v)
		plan.screen.on = v
		O.Wear(plan)
		f:Refresh()
	end, { desc = "Your action bars, chat and damage meter laid out together, with the cooldown manager under your character. Off, your screen stays as it is." })
	take:SetPoint("TOPLEFT")
	-- Every housing drawn wears the look the theme step picked, so the screen is shown as setup leaves it.
	local function Look() return plan.theme and plan.theme.look end

	-- The cards across the top, one a layout: the classic ones in a row, those by role in a row under them.
	local y = -26
	for _, row in ipairs(P.STYLE_ROWS) do
		local count = #row[2]
		local cardW = (width - (count - 1) * GAP) / count
		for i, key in ipairs(row[2]) do
			local card = P.Card(f, cardW, key, function(picked)
				plan.screen.on, plan.screen.style = true, picked
				O.Wear(plan)
				f:Refresh()
			end, function(over)
				lookingStyle = over
				f:Refresh()
			end, Look)
			card:SetPoint("TOPLEFT", (i - 1) * (cardW + GAP), y)
			cards[key] = card
		end
		y = y - P.CardHeight(cardW) - GAP
	end

	-- Under the cards, a row each: the size, the bars, the menu. The cards are the drawing: a big one over
	-- them would be too much and take the page's height.
	local cy = y
	local function Label(text, at)
		local label = UI.Text(f, text, 12, true, C.head)
		label:SetPoint("TOPLEFT", 0, at - 6)
		return label
	end
	Label("Size", cy)
	for i, key in ipairs(ns.Console.SIZE_ORDER) do
		local chip = Chip(f, P.NAMES[key], CHIP_W, function()
			plan.screen.on, plan.screen.size = true, key
			O.Wear(plan)
			f:Refresh()
		end, function(over)
			looking = over and key or nil
			f:Refresh()
		end)
		chip:SetPoint("TOPLEFT", ROW_X + (i - 1) * (CHIP_W + 6), cy)
		chips[key] = chip
	end
	-- What the size under the mouse (or picked) is; or, in its place, why the console can't be set up.
	local afterChips = ROW_X + 3 * (CHIP_W + 6) + 10
	local words = UI.Text(f, "", 11, false, C.dim)
	words:SetPoint("TOPLEFT", afterChips, cy - 6)
	words:SetWidth(width - afterChips)
	words:SetWordWrap(false)
	words:SetJustifyH("LEFT")
	cy = cy - CHIP_H - ROW_GAP

	Label("Bars", cy)
	for i, def in ipairs(BARS) do
		local chip = Chip(f, def.text, BARS_W, function()
			if def.key and Keyed() then return end   -- (your keys stand on every bar)
			plan.screen.on, plan.screen.grow = true, def.key
			O.Wear(plan)
			f:Refresh()
		end, function(over)
			lookingBars = over and def or nil
			f:Refresh()
		end)
		chip:SetPoint("TOPLEFT", ROW_X + (i - 1) * (BARS_W + 6), cy)
		barChips[i] = chip
	end
	local afterBars = ROW_X + 2 * (BARS_W + 6) + 10
	local drawing = P.BarsDrawing(f, 4, 1)
	drawing:SetPoint("TOPLEFT", afterBars, cy - 2)
	local barWords = UI.Text(f, "", 11, false, C.dim)
	barWords:SetPoint("TOPLEFT", afterBars + drawing:GetWidth() + 10, cy - 6)
	barWords:SetWidth(width - afterBars - drawing:GetWidth() - 10)
	barWords:SetWordWrap(false)
	barWords:SetJustifyH("LEFT")
	cy = cy - CHIP_H - ROW_GAP

	-- The side bars: for each side, out or tucked away (a pair of chips after its name), then the drawing of
	-- both and what the pick comes to. A pick goes on the side bar on screen at once (O.Wear).
	Label("Side bars", cy)
	local sideChips, sideNames, lookingSide = {}, {}, nil
	local sx = ROW_X + 20
	for _, side in ipairs(SIDES) do
		local name = UI.Text(f, side.text, 11, false, C.text)
		name:SetPoint("TOPLEFT", sx, cy - 6)
		sideNames[side.key] = name
		sx = sx + 36
		sideChips[side.key] = {}
		for i, def in ipairs(OUT) do
			local chip = Chip(f, def.text, SIDE_W, function()
				plan.screen.sides = plan.screen.sides or { left = true, right = true }
				plan.screen.on, plan.screen.sides[side.key] = true, def.key
				O.Wear(plan)
				f:Refresh()
			end, function(over)
				lookingSide = over and { side = side.key, out = def.key } or nil
				f:Refresh()
			end)
			chip:SetPoint("TOPLEFT", sx + (i - 1) * (SIDE_W + 4), cy)
			sideChips[side.key][i] = chip
		end
		sx = sx + 2 * (SIDE_W + 4) + 18
	end
	local sideDrawing = P.SidesDrawing(f)
	sideDrawing:SetPoint("TOPLEFT", sx, cy)
	local sideWords = UI.Text(f, "", 11, false, C.dim)
	sideWords:SetPoint("TOPLEFT", sx + sideDrawing:GetWidth() + 10, cy - 6)
	sideWords:SetWidth(width - sx - sideDrawing:GetWidth() - 10)
	sideWords:SetWordWrap(false)
	sideWords:SetJustifyH("LEFT")
	cy = cy - CHIP_H - ROW_GAP

	Label("Menu", cy)
	local drawer = UI.Checkbox(f, "In a drawer", function() return plan.screen.drawer end, function(v)
		plan.screen.drawer = v and true or false
		O.Wear(plan)
		f:Refresh()
	end, { desc = "The micro menu and bags tuck away under the guide. Point at its header to use them; click it to keep them out." })
	drawer:SetPoint("TOPLEFT", ROW_X, cy - 2)

	-- After it, the bag buttons: with the menu, or in the bags.
	local keeper = Keeper()
	local bagLabel, bagDrawing, bagWords
	if keeper and plan.screen.bags then
		local bx = ROW_X + 150
		bagLabel = UI.Text(f, "Bag buttons", 11, false, C.text)
		bagLabel:SetPoint("TOPLEFT", bx, cy - 6)
		bx = bx + 76
		for i, def in ipairs(BAGS) do
			local chip = Chip(f, def.text, BARS_W, function()
				plan.screen.on, plan.screen.bags = true, def.key
				O.Wear(plan)
				f:Refresh()
			end, function(over)
				lookingBags = over and def.key or nil
				f:Refresh()
			end)
			chip:SetPoint("TOPLEFT", bx + (i - 1) * (BARS_W + 6), cy)
			bagChips[i] = chip
		end
		bx = bx + 2 * (BARS_W + 6) + 10
		bagDrawing = P.BagsDrawing(f)
		bagDrawing:SetPoint("TOPLEFT", bx, cy)
		bagWords = UI.Text(f, "", 11, false, C.dim)
		bagWords:SetPoint("TOPLEFT", bx + bagDrawing:GetWidth() + 10, cy - 6)
		bagWords:SetWidth(width - bx - bagDrawing:GetWidth() - 10)
		bagWords:SetWordWrap(false)
		bagWords:SetJustifyH("LEFT")
	end
	cy = cy - CHIP_H - 6

	f:SetSize(width, -cy)
	f.cards, f.chips, f.barChips, f.take, f.words, f.barWords, f.drawing = cards, chips, barChips, take, words, barWords, drawing
	f.drawer = drawer
	f.bagChips, f.bagWords, f.bagDrawing = bagChips, bagWords, bagDrawing
	f.sideChips, f.sideWords, f.sideDrawing = sideChips, sideWords, sideDrawing

	function f:Refresh()
		local pick = plan.screen
		local active, inUse, size = L.IsActive(), L.Style(), L.Size()
		local shown = looking or pick.size
		local style = lookingStyle or pick.style or inUse
		-- (The bars chip under the mouse, whichever it is: "every bar now" has `false` for its key.)
		local keyed = Keyed()
		local grow = Grow(pick)
		if lookingBars and not keyed then grow = lookingBars.key end
		take:Refresh()
		drawer:Refresh()
		-- Drawn with the bars the choice gives: the step the abilities call for, or every bar.
		local bars = grow and true or "all"
		-- The bag buttons where the choice puts them; pointed at, the drawer out and the bags open to show them.
		local where = bagWords and (lookingBags or pick.bags) or nil
		for key, card in pairs(cards) do
			card.stage:Draw(shown, key, bars)
			card:Paint(pick.on and pick.style == key, active and inUse == key, not pick.on)
		end
		for key, chip in pairs(chips) do
			chip:Paint(pick.on and pick.size == key)
			chip:SetAlpha(pick.on and 1 or 0.5)
		end
		for i, chip in ipairs(barChips) do
			chip:Paint(pick.on and Grow(pick) == BARS[i].key)
			chip:SetAlpha((not pick.on and 0.5) or (keyed and BARS[i].key and 0.4) or 1)
		end
		drawer:SetAlpha(pick.on and 1 or 0.5)
		-- The side bars as picked, or the choice under the mouse; a side with no bar in the layout picked is dimmed.
		local out = pick.sides or { left = true, right = true }
		local shownOut = { left = out.left ~= false, right = out.right ~= false }
		if lookingSide then shownOut[lookingSide.side] = lookingSide.out end
		local there = SidesThere({ size = shown, style = style, grow = grow })
		for _, side in ipairs(SIDES) do
			local here = pick.on and there[side.key]
			for i, chip in ipairs(sideChips[side.key]) do
				chip:Paint(pick.on and (out[side.key] ~= false) == OUT[i].key)
				chip:SetAlpha(here and 1 or 0.4)
			end
			sideNames[side.key]:SetAlpha(here and 1 or 0.4)
		end
		sideDrawing:Paint(shownOut, there)
		sideDrawing:SetAlpha(pick.on and 1 or 0.5)
		sideWords:SetText(pick.on and SideWords(shownOut, there) or "Your side bars stay as they are.")
		if bagWords then
			for i, chip in ipairs(bagChips) do
				chip:Paint(pick.on and pick.bags == BAGS[i].key)
				chip:SetAlpha(pick.on and 1 or 0.5)
			end
			bagLabel:SetAlpha(pick.on and 1 or 0.5)
			bagDrawing:Paint(where)
			bagDrawing:SetAlpha(pick.on and 1 or 0.5)
			bagWords:SetText(pick.on and BagWords(keeper, where, pick.drawer) or "Your bag buttons stay where they are.")
		end
		local ok, why = L.CanSetUp()
		UI.Ink(words, (ok or not pick.on) and C.dim or C.alert)
		if pick.on and not ok then
			words:SetText(L.Words(why))
		elseif not pick.on then
			words:SetText("Your screen stays as it is. You can set up the console later from /shy.")
		else
			words:SetText(P.WORDS[shown] .. (active and size == shown and " In use." or ""))
		end
		local step = grow and L.GrowStep() or #L.STEPS
		drawing:Paint(nil, L.STEPS[step])
		drawing:SetAlpha(pick.on and 1 or 0.5)
		if not pick.on then
			barWords:SetText("Your bars stay as they are too.")
		elseif keyed then
			barWords:SetText("Your keys stand on every bar, so they're all there from the start, the flyout with them.")
		elseif grow and step == #L.STEPS then
			barWords:SetText(("You know %d abilities or already use every bar, so they're all there from the start."):format(L.Abilities()))
		elseif grow then
			local have = L.STEPS[step]
			local sides = have.sides > 1 and "both side bars" or "a side bar for food and potions"
			barWords:SetText(("%s and %s to start; you'll be offered more as you learn abilities. You know %d."):format(
				ROWS[have.rows], sides, L.Abilities()))
		else
			barWords:SetText("Three rows and both side bars from the start, as the game has them.")
		end
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
	id = "screen", order = 20, title = "Layout", glyph = "window",
	ask = "Pick a layout",
	lead = "A layout and size for the console. The drawing shows your screen once it's set up.",
	brief = function(plan)
		local pick = plan.screen
		if not pick.on then return "As it is" end
		return ns.Preview.STYLES[pick.style or ns.Layout.Style()] .. ", " .. ns.Preview.NAMES[pick.size]:lower()
	end,
	last = true,   -- writing the layout ends in a reload, so every other step runs first
	Plan = function(plan)
		local keeper = Keeper()
		plan.screen = { on = true, size = ns.Layout.Size(), style = ns.Layout.Style(), grow = Grows(), drawer = ns.T.db.menuDrawer ~= false,
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
