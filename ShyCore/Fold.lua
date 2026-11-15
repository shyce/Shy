-- Folds: a piece folded away down to its header and opened again, the one way every piece that folds does it (the
-- quest card standing alone, the quests in the deck, the menu's drawer).
--
-- The header is the fold's button, clicked anywhere across it. The title stands where every header's words do
-- (UI.HeadLeft: in from the look's inner face, so a look's thicker frame moves it in with it), the caret right after
-- it: pointing down while open, onward while folded. Under the mouse the strip lights faintly and the title and the
-- caret go hot; the header says nothing in a tip. Folded is not off: the title is never dimmed.
--
-- Folded, a piece is its header alone, a plain rectangle UI.FOLDED tall (the strip under its top edge and a closing
-- edge as thick): no accent line under the strip, no room for content under it, and the same width and border as
-- open (every look's border draws true down to it: UI.LookLeast).
--
--   local head = UI.FoldHead(button, house, { title = "Quests", lead = 0 })
--     button   what takes the click: the caller's own scripts stay (its click, its drag); the fold hooks the hover
--     house    the panel whose header it is (a UI.Panel with a title): the strip it lights, the middle it stands on
--     lead     room before the title for a control at the header's left (the card's guide chevron)
--   head:Set(open)        the caret
--   head:SetTitle(text)   head:SetLead(x)   head:SetShown(on)   head:SetFoldable(on) (off: the title alone, no click)
--   head:Width()          from the header's left edge to past the caret: where a next tab may stand
--   UI.FoldLine(house, open)   the header's accent line (and what a look lays over it) while open; none folded
--   UI.FOLDED             a folded piece's height

local Shy = Shy
local UI = Shy.UI
local C = UI.colors

UI.FOLD_EDGE = 2                                    -- the closing edge under a folded header (UI.Panel's top edge)
UI.FOLDED = UI.HEAD_STRIP + UI.FOLD_EDGE

local SIZE = UI.HEAD.piece
local GAP = 5                                       -- between the title and its caret
local OPEN, SHUT = 0, math.pi / 2                   -- the caret's turn
local WASH = 0.07                                   -- the strip's light under the mouse

local heads = setmetatable({}, { __mode = "k" })

local Head = {}
Head.__index = Head

local function Left(self)
	return UI.HeadLeft(self.house, SIZE) + self.lead
end

function Head:Place()
	self.title:ClearAllPoints()
	UI.OnHead(self.title, "LEFT", self.house, "LEFT", Left(self))
end

function Head:SetHot(on)
	on = on and self.foldable and self.shown or false
	if on == self.hot then return end
	self.hot = on
	self.wash:SetShown(on)
	UI.Ink(self.title, on and C.hot or C.text)
	UI.Tint(self.caret, on and C.hot or C.text, 1)
end

function Head:Set(open)
	open = open and true or false
	if open == self.open then return end
	self.open = open
	self.caret:SetRotation(open and OPEN or SHUT)
end

function Head:SetTitle(text)
	self.title:SetText(text)
end

function Head:SetLead(x)
	x = x or 0
	if x == self.lead then return end
	self.lead = x
	self:Place()
end

function Head:SetShown(on)
	on = on and true or false
	self.shown = on
	self.title:SetShown(on)
	self.caret:SetShown(on and self.foldable)
	if not on then self:SetHot(false) end
end

function Head:SetFoldable(on)
	on = on and true or false
	self.foldable = on
	self.caret:SetShown(on and self.shown)
	self.button:EnableMouse(on)
	if not on then self:SetHot(false) end
end

function Head:Width()
	return Left(self) + self.title:GetStringWidth() + GAP + SIZE.glyph
end

function UI.FoldHead(button, house, opts)
	opts = opts or {}
	local self = setmetatable({ button = button, house = house, lead = opts.lead or 0,
		open = true, shown = true, foldable = true, hot = false }, Head)
	-- The light over the strip, under the words.
	self.wash = button:CreateTexture(nil, "ARTWORK")
	if house.shyStrip then self.wash:SetAllPoints(house.shyStrip) else self.wash:SetAllPoints(button) end
	UI.Paint(self.wash, C.hot, WASH)
	self.wash:Hide()
	self.title = UI.TitleText(button, opts.title or "", UI.TITLE_SIZE, C.text)
	self.title:SetDrawLayer("OVERLAY")
	self.caret = button:CreateTexture(nil, "OVERLAY")
	self.caret:SetSize(SIZE.glyph, SIZE.glyph)
	self.caret:SetTexture(Shy.Skin.GLYPH.caret)
	self.caret:SetPoint("LEFT", self.title, "RIGHT", GAP, 0)
	self.caret:SetRotation(OPEN)
	UI.Tint(self.caret, C.text, 1)
	self:Place()
	button:HookScript("OnEnter", function() self:SetHot(true) end)
	button:HookScript("OnLeave", function() self:SetHot(false) end)
	heads[self] = true
	return self
end

-- A look worn anew may have a frame of another width: every title stands in from its inner face again.
Shy:On("SHY_THEME", function()
	for head in pairs(heads) do head:Place() end
end)

function UI.FoldLine(house, open)
	if house.shyLine then house.shyLine:SetShown(open and true or false) end
end
