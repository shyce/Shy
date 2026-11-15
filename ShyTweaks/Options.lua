-- Options: a searchable list of feature cards, each with a switch and its settings while on.

local ADDON, ns = ...
local T = ns.T
local B, UI = Shy.Brand, Shy.UI

local CARD_W = 596
local ALL = "All"

-- "ClassTrainerFrame" -> "Class Trainer"
local function FriendlyName(name)
	return (name:gsub("Frame$", ""):gsub("(%l)(%u)", "%1 %2"))
end

local function CategoryColor(category)
	for i, name in ipairs(ns.CATEGORIES) do
		if name == category then return B.Ramp((i - 1) / math.max(1, #ns.CATEGORIES - 1)) end
	end
	return 1, 1, 1
end

-- Option widgets inside a card

local function WindowList(parent, onChange)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(CARD_W - 40, 1)
	local rows = {}
	function f:Refresh()
		local names = ns.MovedWindows()
		for i, name in ipairs(names) do
			local row = rows[i]
			if not row then
				row = CreateFrame("Frame", nil, f)
				row:SetSize(300, 24)
				row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
				row.label = UI.Text(row, "", 13)
				row.label:SetPoint("LEFT")
				row.reset = UI.Button(row, "Reset", 64, function()
					ns.ResetFrame(row.name)
					onChange()
				end)
				row.reset:SetPoint("LEFT", 190, 0)
				rows[i] = row
			end
			row.name = name
			local saved = T.db.frames[name]
			local scale = saved.scale and ("  |cff888888" .. math.floor(saved.scale * 100 + 0.5) .. "%|r") or ""
			row.label:SetText(FriendlyName(name) .. scale)
			row:Show()
		end
		for i = #names + 1, #rows do rows[i]:Hide() end
		if #names == 0 then
			f.empty = f.empty or UI.Text(f, "No moved windows yet. Drag one by its title bar.", 12, false, UI.colors.dim)
			f.empty:SetPoint("TOPLEFT")
			f.empty:Show()
		elseif f.empty then
			f.empty:Hide()
		end
		f:SetHeight(math.max(20, #names * 26))
	end
	return f
end

local function OptionWidget(parent, feature, o, g, onChange)
	local get = function() return feature.opt[o.key] end
	local set = function(v) feature:SetOption(o.key, v) end
	local opts = { desc = o.desc, width = 280, format = o.format, placeholder = o.placeholder and function() return o.placeholder end,
		enabled = o.enabled and function() return o.enabled(feature) end }
	if o.kind == "checkbox" then return g:Checkbox(parent, o.label, get, set, opts) end
	if o.kind == "slider" then return g:Slider(parent, o.label, o.min, o.max, o.step, get, set, opts) end
	if o.kind == "dropdown" then return g:Dropdown(parent, o.label, o.items, get, set, opts) end
	if o.kind == "input" then return g:Input(parent, o.label, get, set, opts) end
	if o.kind == "button" then
		return UI.Button(parent, o.label, 180, function()
			o.run(feature)
			onChange()
		end)
	end
	if o.kind == "windows" then return g:Add(WindowList(parent, onChange)) end
end

-- Cards

local function Card(parent, feature, g, onChange)
	local card = CreateFrame("Frame", nil, parent)
	card:SetWidth(CARD_W)
	UI.Skin(card)

	local accent = card:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT")
	accent:SetPoint("BOTTOMLEFT")
	accent:SetWidth(3)
	UI.Paint(accent, function() return CategoryColor(feature.category) end)

	local title = UI.Text(card, feature.title, 16, true)
	title:SetPoint("TOPLEFT", 16, -10)
	card.category = UI.Text(card, feature.category, 11, false, UI.colors.dim)
	card.category:SetPoint("LEFT", title, "RIGHT", 10, -1)

	local desc = UI.Text(card, feature.desc, 12, false, UI.colors.dim)
	desc:SetWidth(CARD_W - 110)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)

	local switch = g:Switch(card, feature.title, function() return feature:IsOn() end, function(v) feature:SetOn(v) end)
	switch:SetPoint("TOPRIGHT", -16, -12)

	local body = CreateFrame("Frame", nil, card)
	body:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
	body:SetWidth(CARD_W - 32)
	local widgets = {}
	for _, o in ipairs(feature.options or {}) do
		local w = OptionWidget(body, feature, o, g, onChange)
		if w then widgets[#widgets + 1] = w end
	end

	function card:Layout(showCategory)
		self.category:SetShown(showCategory)
		local y = 0
		for _, w in ipairs(widgets) do
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y)
			y = y - w:GetHeight() - 8
		end
		body:SetHeight(math.max(1, -y))
		local open = feature:IsOn() and #widgets > 0
		body:SetShown(open)
		self:SetHeight(10 + title:GetStringHeight() + 5 + desc:GetStringHeight() + 12 + (open and (-y + 4) or 0))
	end

	card.feature = feature
	card.search = (feature.title .. " " .. feature.desc .. " " .. (feature.keywords or "") .. " " .. feature.category):lower()
	return card
end

-- Panel

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	panel.scrollsItself = true   -- the card list has its own scroll area; RegisterOptions must not wrap it
	local cards, scroll, empty, tabs = {}, nil, nil, nil
	local category, search = ALL, ""
	local group

	local function Relayout()
		local content = scroll.content
		local y, shown = 0, 0
		for _, card in ipairs(cards) do
			local match = (search == "" and (category == ALL or card.feature.category == category))
				or (search ~= "" and card.search:find(search, 1, true))
			card:SetShown(match and true or false)
			if match then
				card:Layout(category == ALL or search ~= "")
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
				y = y - card:GetHeight() - 8
				shown = shown + 1
			end
		end
		empty:SetShown(shown == 0)
		content:SetHeight(math.max(1, -y))
		scroll:Update()
	end

	local function Changed()
		group:Refresh()
		Relayout()
	end

	local function Build()
		UI.PageHeader(panel, T)
		-- Refresh first so widgets have their new heights, then lay out.
		group = UI.Group(function() group:Refresh(); Relayout() end)

		local labels = { ALL }
		for _, name in ipairs(ns.CATEGORIES) do labels[#labels + 1] = name end
		tabs = UI.Tabs(panel, labels, function(i)
			category = labels[i]
			if scroll then
				scroll:SetVerticalScroll(0)
				Relayout()
			end
		end, CARD_W, 14)
		tabs:SetPoint("TOPLEFT", 24, -112)

		local searchBox = UI.Input(panel, nil, function() return search end, function(v)
			search = strtrim(v):lower()
			scroll:SetVerticalScroll(0)
			Relayout()
		end, { width = CARD_W, live = true, placeholder = function() return "Search tweaks..." end })
		searchBox:SetPoint("TOPLEFT", 24, -150)
		searchBox:Refresh()

		scroll = UI.ScrollArea(panel, CARD_W + 14, 300)
		scroll:ClearAllPoints()
		scroll:SetPoint("TOPLEFT", 24, -186)
		scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", 24 + CARD_W + 14, 10)

		empty = UI.Text(scroll.content, "No tweaks match that search.", 13, false, UI.colors.dim)
		empty:SetPoint("TOP", 0, -20)

		for _, cat in ipairs(ns.CATEGORIES) do
			for _, feature in ipairs(ns.features) do
				if feature.category == cat then cards[#cards + 1] = Card(scroll.content, feature, group, Changed) end
			end
		end
		tabs:Select(1)
	end

	ns.RefreshOptions = function()
		if panel.built then Changed() end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		Changed()
	end)

	-- Also called to reset a profile, possibly before this page was ever opened.
	function panel:OnDefault()
		T:ResetAll()
		ns.RefreshOptions()
	end

	return panel
end
