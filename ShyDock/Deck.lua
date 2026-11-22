-- The deck: one panel holding the HUD boxes that dock in the group column at the screen's top left
-- (ShyQuest's guide card, ShyGroup's status, ShyThreat's meter), with a tab per box.
--
-- `base` is the Shy.HUD box, one unit tall: only an anchor. `column` (the panel) is its
-- child, one strata under the docked boxes, which hide their own edge and fill
-- (HUD's `docked`) and have no mover of their own: in layout mode the deck's mover
-- covers the whole column, so the stack moves as one piece. A box becomes a tab
-- through the `toggle` it hands Shy.HUD.Create. A box in the deck stays in it: it has no
-- place of its own while the deck is on. Arrange.lua places the base and sizes the column (D.Stand).
-- The level is the guide's (ShyQuest's strip on its card), never the deck's.

local ADDON, ns = ...
local T = ns.T
local UI, Console = Shy.UI, ns.Console
local C = UI.colors

local D = {}
ns.Deck = D

local HEADER, LIP = UI.HEAD_STRIP, UI.HEAD_LIP
local RULE = UI.LINE                    -- accent line under the header
local EDGE = 3                          -- panel edge thickness
-- Closed (the header alone): a piece folded away, UI.FOLDED tall, the base's own unit at its foot.
local SHUT = UI.FOLDED - HEADER - 1
local TEXT = UI.TITLE_SIZE
local GAP = 16                          -- gap between tabs
local LIGHT = 6                         -- size of a tab's light
local WATCH = 0.5                       -- seconds between tab repaints

local base, column
local up = false
local tabs = {}
local seams = {}                        -- hairlines between docked boxes

-- Tabs

-- Light: accent while the box shows or another piece shows its content (HUD's `away`), gold on
-- alert, dim when on but empty, dark when off.
local function Paint(tab)
	local toggle, box = tab.box.toggle, tab.box
	local on = toggle.get() and true or false
	local alert = toggle.alert and toggle.alert() or false
	local showing = box:IsShown() or (box.awayFn ~= nil and box.awayFn() == true)
	UI.Ink(tab.text, (tab.hover and C.hot) or (on and C.text) or C.dim)
	if alert then
		UI.Paint(tab.light, C.alert)
	elseif on and showing then
		UI.Paint(tab.light, Shy.Theme.Accent)
	elseif on then
		UI.Paint(tab.light, C.dim)
	else
		UI.Paint(tab.light, C.bg)
	end
end

local function Hint(tab)
	local toggle = tab.box.toggle
	-- A box can name its own click through toggle.onText / offText.
	local click
	if toggle.get() then click = toggle.onText or "Hide" else click = toggle.offText or "Show" end
	UI.Tip(tab, toggle.label, toggle.tip, { side = "TOP", hints = { { "left", click } } })
end

-- A box's switch flipped (a tab's, or the fold's: the header), and everything that shows it changed at once, not
-- a frame later.
local function Flip(box)
	local toggle = box.toggle
	toggle.set(not toggle.get())
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	ns.Arrange.Apply()
	local tab = tabs[box.id]
	if tab and tab.hover and tab:IsShown() then Hint(tab) end
	if D.fold == box then D.head:Set(toggle.get()) end
end

local function Tab(box)
	local tab = CreateFrame("Button", nil, column)
	tab.box = box
	local well = CreateFrame("Frame", nil, tab)
	well:SetSize(LIGHT + 2, LIGHT + 2)
	well:SetPoint("LEFT", 0, 0)
	UI.Skin(well, C.bg, C.border)
	tab.light = well:CreateTexture(nil, "ARTWORK")
	tab.light:SetPoint("TOPLEFT", 1, -1)
	tab.light:SetPoint("BOTTOMRIGHT", -1, 1)
	tab.text = UI.TitleText(tab, box.toggle.label, TEXT, C.text)
	tab.text:SetPoint("LEFT", well, "RIGHT", 5, 0)
	tab:SetSize(LIGHT + 2 + 5 + tab.text:GetStringWidth(), HEADER - LIP)
	-- (Over the header's own click: a tab is its own button.)
	tab:SetFrameLevel(column:GetFrameLevel() + 3)
	tab:SetScript("OnClick", function(self) Flip(self.box) end)
	tab:SetScript("OnEnter", function(self)
		self.hover = true
		Paint(self)
		Hint(self)
	end)
	tab:SetScript("OnLeave", function(self)
		self.hover = false
		Paint(self)
		UI.TipHide(self)
	end)
	return tab
end

-- A box whose switch folds it (toggle.caret: ShyQuest's quests) is the header's own, as every piece that folds
-- (UI.FoldHead): its name where a header's title stands, the caret after it, a click anywhere across the header.
-- The other boxes are tabs after it, each with its light.
local function ShowTabs(boxes)
	local fold
	for _, box in ipairs(boxes) do
		if box.toggle.caret then
			fold = box
			break
		end
	end
	D.fold = fold
	column.hit:SetShown(fold ~= nil)
	D.head:SetShown(fold ~= nil)
	local at = UI.HeadLeft(column, UI.HEAD.piece)
	if fold then
		D.head:SetTitle(fold.toggle.label)
		D.head:Set(fold.toggle.get())
		at = D.head:Width() + GAP
	end
	local wanted = {}
	for _, box in ipairs(boxes) do
		if box ~= fold then
			local tab = tabs[box.id]
			if not tab then
				tab = Tab(box)
				tabs[box.id] = tab
			end
			wanted[tab] = true
			tab:ClearAllPoints()
			UI.OnHead(tab, "LEFT", column, "LEFT", at)
			tab:Show()
			Paint(tab)
			at = at + tab:GetWidth() + GAP
		end
	end
	-- Never hide a tab that stays, even briefly: the mouse may be on it.
	for _, tab in pairs(tabs) do
		if not wanted[tab] then tab:Hide() end
	end
end

-- Show the deck with a tab for each of `boxes` (left to right). Returns the base for the boxes it holds to
-- stack on, or nil with no boxes.
function D.Show(boxes)
	if #boxes == 0 then
		D.Hide()
		return nil
	end
	ShowTabs(boxes)
	up = true
	Shy.HUD.Update(base)
	return base
end

-- Size the column over the stack. rise: height of the top docked box's top above
-- the base's top, in screen units (0 with no box). edges: heights where one box
-- ends and the next begins, for the hairlines. Returns the header's height in base units.
function D.Stand(rise, edges)
	local scale = base:GetScale()
	-- With no box (all folded away) the column is the header alone, a piece folded away (UI.FOLDED): no accent
	-- line under it and no strip for content, closed by its edge.
	local open = rise > 0
	column:SetPoint("TOPRIGHT", base, "TOPRIGHT", 0, rise / scale + D.Head(open))
	UI.FoldLine(column, open)
	Shy.HUD.Folded(base, not open)   -- nothing to size while folded: no handles to size it by
	local lines = {}
	for _, edge in ipairs(edges or {}) do lines[#lines + 1] = edge / scale end
	for i, y in ipairs(lines) do
		local seam = seams[i]
		if not seam then
			seam = column:CreateTexture(nil, "ARTWORK")
			seam:SetHeight(1)
			UI.Paint(seam, C.rowEdge, 0.9)
			seams[i] = seam
		end
		seam:ClearAllPoints()
		seam:SetPoint("BOTTOMLEFT", base, "TOPLEFT", EDGE, y)
		seam:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", -EDGE, y)
		seam:Show()
	end
	for i = #lines + 1, #seams do seams[i]:Hide() end
	return D.Head(open)
end

-- How far the column stands over the top of what it holds (its base, and the boxes on it): the header, then
-- the accent line while it is open (`open`: a box shows in it; left out, open) or its closing edge while it is
-- the header alone. The same that D.Stand puts it at, so a place worked out with it is exact either way.
function D.Head(open)
	return HEADER + ((open == false) and SHUT or RULE)
end

-- For a docked box that keeps controls in the header (ShyQuest's pager): the deck's panel, whose header they
-- stand in through UI.OnHead as in their own. nil while the deck is down.
function T:DeckHeader()
	if not (up and column) then return nil end
	return column
end

function D.Fit(width)
	if math.abs(base:GetWidth() - width) > 0.5 then base:SetWidth(width) end
end

function D.Hide()
	if not up then return end
	up = false
	Shy.HUD.Update(base)
end

local function Menu(root)
	root:CreateButton("Console settings", function() T:OpenOptions() end)
end

function D.Start()
	base = Shy.HUD.Create({
		id = "shydock-deck", title = "Deck", name = "ShyDockDeck",
		width = Console.DECK, height = 1,
		point = { "BOTTOMLEFT", "BOTTOM", -Console.DECK / 2, 300 },   -- placeholder until Arrange.lua gives it a home
		shown = function() return up end,
	})
	Shy.HUD.Manage(base, base, Menu)

	column = CreateFrame("Frame", nil, base)
	column:SetFrameStrata("LOW")
	column:SetPoint("BOTTOMLEFT", base, "BOTTOMLEFT", 0, 0)
	UI.Panel(column, { cap = true, title = HEADER, facets = false, hud = true })
	Shy.HUD.Manage(base, column, Menu)
	Shy.HUD.Cover(base, column)   -- in layout mode the whole column is the handle

	-- The header, a click across all of it: the fold's (ShowTabs, UI.FoldHead). The tabs and a docked box's tools
	-- in it (ShyQuest's pager and lens) stand over it and keep their own clicks; a drag is still a drag, and the
	-- right button still the deck's menu.
	local hit = CreateFrame("Button", nil, column)
	hit:SetPoint("TOPLEFT", EDGE, 0)
	hit:SetPoint("TOPRIGHT", -EDGE, 0)
	hit:SetHeight(HEADER)
	hit:SetFrameLevel(column:GetFrameLevel() + 1)
	D.head = UI.FoldHead(hit, column)
	hit:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or Shy.HUD.WasDragged(base) or not D.fold then return end
		Flip(D.fold)
	end)
	Shy.HUD.Manage(base, hit, Menu)
	hit:Hide()
	column.hit = hit
	D.Stand(0)
	D.base, D.column, D.tabs = base, column, tabs

	-- Tab state changes with no event, so poll while shown.
	local since = 0
	base:SetScript("OnUpdate", function(_, elapsed)
		since = since + elapsed
		if since < WATCH then return end
		since = 0
		ns.Arrange.Watch()
		for _, tab in pairs(tabs) do
			if tab:IsShown() then Paint(tab) end
		end
		if D.fold then D.head:Set(D.fold.toggle.get()) end
	end)
end
