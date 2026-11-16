-- The options: one card per module with a switch and, while it is on, its checkboxes.
-- Cards are built from ns.modules when the page shows, so a module only has to register itself.

local ADDON, ns = ...
local T = ns.T
local B, UI = Shy.Brand, Shy.UI

local LEFT, INTRO, CARD_W = 24, -112, 596   -- the intro starts under the page header
local PAD = 16                          -- card padding
local COLUMN = (CARD_W - 2 * PAD) / 2   -- width of one of two columns
local ROW = 28                          -- height of a row of checkboxes

-- Two checkboxes to a row; one whose label is wider than a column takes a whole row.
local function PlaceOptions(body, boxes)
	local column, y = 0, 0
	for _, box in ipairs(boxes) do
		local wide = box:GetWidth() > COLUMN - 12
		if wide and column > 0 then column, y = 0, y - ROW end
		box:SetPoint("TOPLEFT", column * COLUMN, y)
		if wide or column > 0 then column, y = 0, y - ROW else column = 1 end
	end
	if column > 0 then y = y - ROW end
	return -y
end

local function Card(parent, m, index, group)
	local card = CreateFrame("Frame", nil, parent)
	card:SetWidth(CARD_W)
	UI.Skin(card, UI.colors.row, UI.colors.rowEdge)
	card.module = m

	-- The side bars run along the accent ramp from the first card to the last.
	local accent = card:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT")
	accent:SetPoint("BOTTOMLEFT")
	accent:SetWidth(3)
	UI.Paint(accent, function() return B.Ramp((index - 1) / math.max(1, #ns.modules - 1)) end)
	card.accent = accent

	local title = UI.Text(card, m.title, 16, true)
	title:SetPoint("TOPLEFT", PAD, -10)
	local desc = UI.Text(card, m.desc, 12, false, UI.colors.dim)
	desc:SetWidth(CARD_W - 110)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)

	card.switch = group:Switch(card, m.title, function() return m:IsOn() end, function(v) m:SetOn(v) end,
		{ desc = "Off puts this part back to the default UI." })
	card.switch:SetPoint("TOPRIGHT", -PAD, -12)

	local body = CreateFrame("Frame", nil, card)
	body:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
	body:SetWidth(CARD_W - 2 * PAD)
	local boxes = {}
	for i, o in ipairs(m.options or {}) do
		boxes[i] = group:Checkbox(body, o.label, function() return m.opt[o.key] end,
			function(v) m:SetOption(o.key, v) end, { desc = o.desc })
	end
	local height = PlaceOptions(body, boxes)
	body:SetHeight(math.max(1, height))

	function card:Layout()
		local open = m:IsOn() == true and height > 0
		body:SetShown(open)
		self:SetHeight(10 + title:GetStringHeight() + 5 + desc:GetStringHeight() + 12 + (open and height or 0))
	end
	return card
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local cards, intro, footer = {}, nil, nil
	local group

	local function Relayout()
		local y = INTRO - intro:GetStringHeight() - 10
		for _, card in ipairs(cards) do
			card:Layout()
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT, y)
			y = y - card:GetHeight() - 8
		end
		footer:ClearAllPoints()
		footer:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT, y - 6)
	end

	local function Build()
		UI.PageHeader(panel, T)
		group = UI.Group(Relayout)

		intro = UI.Text(panel, "Turn any part off and it's back to the game's look at once. Most keep the game's layout; the vendor, trainer, mail, professions, spellbook, friends and guild windows are rebuilt to be easier to use.", 13)
		intro:SetWidth(CARD_W)
		intro:SetPoint("TOPLEFT", LEFT, INTRO)

		footer = UI.Text(panel, "To move or resize a bar or frame, or hide the main bar's gryphons or page arrows, use Edit Mode.", 12, false, UI.colors.dim)
		footer:SetWidth(CARD_W)
	end

	local function Refresh()
		for i = #cards + 1, #ns.modules do cards[i] = Card(panel, ns.modules[i], i, group) end
		group:Refresh()
		Relayout()
	end

	ns.RefreshOptions = function()
		if panel.built then Refresh() end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		Refresh()
	end)

	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
		ns.RefreshOptions()
	end

	return panel
end
