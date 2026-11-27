-- Shy.Party: your group's business at the top's middle, one piece in the drawer under the head. Your run (what
-- it is, how many of how many, what it still needs), the replies waiting, and the routes someone suggests, each
-- with Accept and Decline at its end. Every one is a row of the column's tray (Shy.Top.Make.Cell). The addons
-- that know these things say them here: the piece, its look and its settings are one, in layout mode as in play.
--
--   Shy.Party.Run({ name, count, size, need = "Need healer", full = true, unread = 2,
--       open = function(replies) end,                -- a click: the run, or (true) the replies
--       menu = function(root) end })                 -- its right click. nil: no run and nothing waiting
--   Shy.Party.Offers({ { key, from, color = { r, g, b }, says = "Goldshire  ·  4 min", at, till,
--       accept = fn, decline = fn, show = fn }, ... })   -- the routes waiting for your answer, oldest first
--   Shy.Party.Setting(key, { label, get, set, hint })    -- a setting of the piece's: an "On" box in its layout panel
--   Shy.Party.Toggle(toggle)                             -- the switch a deck shows for it (HUD.Create's `toggle`)
--   Shy.Party.Rows()                                     -- what it shows: { { kind = "run" | "replies" | "offer",
--                                                        -- cell, offer }, ... } (samples in layout mode)
--   Shy.Party.Box()

local Shy = Shy
local HUD, UI, Theme, Skin = Shy.HUD, Shy.UI, Shy.Theme, Shy.Skin
local C = UI.colors

local P = {}
Shy.Party = P

local CELL = Shy.Top.Make.CELL
local ROW, RULE = CELL.ROW, CELL.RULE
local K = {
	LEAST = 200,        -- the narrowest its rows stand
	MOST = 360,         -- the most a row's words are given
	BUTTON = CELL.ROW,  -- Accept and Decline: square, a row tall
	MARK = 12,          -- their signs
	PULSE = 0.8,        -- seconds a new offer's light takes to die
}
local DOT = "  \194\183  "
local TIMES = "\195\151"
local SAMPLE = {
	run = { name = "Deadmines", count = 3, size = 5, need = "Need healer", sample = true },
	offer = { key = "sample", from = "Thrall", color = { 0.0, 0.44, 0.87 }, says = "Goldshire" .. DOT .. "4 min", sample = true },
}

local box, tray
local run, offers = nil, {}
local settings, order = {}, {}
local cells = {}      -- the rows made, reused in order
local shown = {}      -- { kind, cell, offer } as laid now
local cameAt = {}     -- offer key -> when it came (its light)

local function Sampled()
	return HUD.IsUnlocked() and run == nil and #offers == 0
end

-- A row: a cell that is clicked, with Accept and Decline made on it the first time it shows an offer.
local function Choice(cell, glyph, color, click)
	local b = CreateFrame("Button", nil, cell)
	b:SetSize(K.BUTTON, K.BUTTON)
	b:SetFrameLevel(cell.over:GetFrameLevel() + 2)
	b.hot = b:CreateTexture(nil, "BACKGROUND")
	b.hot:SetAllPoints()
	b.hot:SetColorTexture(1, 1, 1, CELL.HOT * 1.5)
	b.hot:Hide()
	b.edge = b:CreateTexture(nil, "ARTWORK")
	b.edge:SetColorTexture(1, 1, 1, 1)
	b.edge:SetWidth(CELL.RULE)
	b.edge:SetPoint("TOPLEFT")
	b.edge:SetPoint("BOTTOMLEFT")
	UI.Tint(b.edge, Theme.skin.metal, CELL.LINE)
	if glyph then
		b.sign = b:CreateTexture(nil, "OVERLAY")
		b.sign:SetSize(K.MARK, K.MARK)
		b.sign:SetPoint("CENTER")
		Shy.Hover.Glyph(b.sign, glyph, K.MARK)
		UI.Tint(b.sign, color)
	else
		b.sign = UI.Words(b, UI.NameFont(14), color, { justify = "CENTER", wrap = false })
		b.sign:SetPoint("CENTER", 0, 1)
		b.sign:SetText(TIMES)
	end
	b:SetScript("OnEnter", function(self) self.hot:Show() end)
	b:SetScript("OnLeave", function(self) self.hot:Hide() end)
	b:SetScript("OnClick", function()
		local offer = cell.offer
		if offer and not offer.sample then click(offer) end
	end)
	return b
end

local function Cell(i)
	local cell = cells[i]
	if cell then return cell end
	cell = Shy.Top.Make.Cell(box, "Button")
	cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cell:SetScript("OnEnter", function(self) self:Hot(true) end)
	cell:SetScript("OnLeave", function(self) self:Hot(false) end)
	-- A press that moves drags the column (the head leads it); a click is the row's.
	HUD.Manage(box, cell, false)
	cell:SetScript("OnClick", function(self, button)
		if HUD.WasDragged(box) or HUD.IsUnlocked() then return end
		local kind, offer = self.kind, self.offer
		if offer and offer.sample then return end
		if button == "RightButton" then
			if kind == "offer" then
				UI.ContextMenu(self, function(root)
					root:CreateTitle(offer.from)
					root:CreateButton("Accept", function() offer.accept(offer) end)
					root:CreateButton("Decline", function() offer.decline(offer) end)
				end)
			elseif run and run.menu then
				UI.ContextMenu(self, function(root) run.menu(root) end)
			end
		elseif kind == "offer" then
			if offer.show then offer.show(offer) end
		elseif run and run.open then
			run.open(kind == "replies")
		end
	end)
	cell.accept = Choice(cell, "check", C.good, function(offer) offer.accept(offer) end)
	cell.decline = Choice(cell, nil, C.dim, function(offer) offer.decline(offer) end)
	cell.decline:SetPoint("TOPRIGHT")
	cell.accept:SetPoint("TOPRIGHT", cell.decline, "TOPLEFT")
	cells[i] = cell
	return cell
end

-- Dresses a cell as one row. Returns the width its words need.
local function Dress(cell, kind, what)
	cell.kind, cell.offer = kind, kind == "offer" and what or nil
	cell.accept:SetShown(kind == "offer")
	cell.decline:SetShown(kind == "offer")
	local need
	if kind == "run" then
		local full = what.full == true
		local color = full and C.good or Theme.Accent
		local name = what.name or "Your run"
		if what.need and not full then name = name .. UI.Wrap(C.dim, DOT .. what.need) end
		if full then name = name .. UI.Wrap(C.dim, DOT .. "Group is full") end
		need = cell:Set({ file = Shy.MEDIA .. "GlyphPeople", color = color, name = name,
			right = what.size and (what.count .. "/" .. what.size) or "", rightColor = full and C.good or C.head,
			fill = what.size and color or nil })
		if what.size and what.size > 0 then cell:Share(math.min(1, (what.count or 0) / what.size)) end
	elseif kind == "replies" then
		need = cell:Set({ sign = "talk", color = C.alert,
			name = what.unread == 1 and "1 reply waiting" or (what.unread .. " replies waiting"), nameColor = C.alert })
	else
		local color = what.color or C.text
		need = cell:Set({ file = Skin.GLYPH.pin, color = color,
			name = UI.Wrap(color, what.from or "") .. " " .. UI.Wrap(C.dim, "suggests") .. " " .. (what.says or ""),
			room = 2 * K.BUTTON - CELL.PAD, fill = color })
		cell:Share(1)
	end
	return math.min(K.MOST, need or K.MOST)
end

-- The rows stood in the tray, one right on the next, the tray's width; the box hugs them.
local function Lay()
	if not (box and tray) then return end
	local list = {}
	local r = run or (Sampled() and SAMPLE.run) or nil
	if r then
		if r.name or r.size then list[#list + 1] = { "run", r } end
		if (r.unread or 0) > 0 then list[#list + 1] = { "replies", r } end
	end
	if #offers > 0 then
		for _, offer in ipairs(offers) do list[#list + 1] = { "offer", offer } end
	elseif Sampled() then
		list[#list + 1] = { "offer", SAMPLE.offer }
	end
	local need = K.LEAST
	wipe(shown)
	for i, each in ipairs(list) do
		local cell = Cell(i)
		need = math.max(need, Dress(cell, each[1], each[2]))
		shown[i] = { kind = each[1], cell = cell, offer = cell.offer }
	end
	local n = #list
	local width, inset = tray:Fit(need, n > 0 and n * ROW + (n - 1) * RULE or 0)
	local hung = Shy.Top.Hung(box)
	for i, cell in ipairs(cells) do
		if i <= n then
			cell:SetWidth(width)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -(inset + (i - 1) * (ROW + RULE)))
			cell:Rule(hung or i > 1)
			cell:Show()
		else
			cell:Hide()
		end
	end
	if n ~= box.rows then
		box.rows = n
		HUD.Update(box)
		Shy.Top.Apply()
	end
end

-- An offer's light: the time left to answer drains from the right; a new one is lit as it comes.
local function Tick()
	local now = GetTime()
	local any = false
	for _, each in ipairs(shown) do
		local offer = each.offer
		if offer and offer.till and offer.at and offer.till > offer.at then
			any = true
			each.cell:Share(math.max(0, math.min(1, (offer.till - now) / (offer.till - offer.at))))
			local came = cameAt[offer.key]
			each.cell:Pulse(came and math.max(0, 1 - (now - came) / K.PULSE) or 0)
		end
	end
	if not any then box:SetScript("OnUpdate", nil) end
end

local function Changed()
	if not box then return end
	Lay()
	box:SetScript("OnUpdate", #offers > 0 and Tick or nil)
end

function P.Run(def)
	run = def
	Changed()
end

function P.Offers(list)
	local now, seen = GetTime(), {}
	offers = list or {}
	for _, offer in ipairs(offers) do
		seen[offer.key] = true
		cameAt[offer.key] = cameAt[offer.key] or now
	end
	for key in pairs(cameAt) do
		if not seen[key] then cameAt[key] = nil end
	end
	Changed()
end

function P.Setting(key, def)
	if not settings[key] then order[#order + 1] = key end
	settings[key] = def
	if box then
		HUD.Update(box)
		Shy.Top.Apply()   -- (in the column now)
	end
end

function P.Toggle(toggle)
	if box then box.toggle = toggle end
	P.toggle = toggle
end

function P.Rows()
	local list = {}
	for i, each in ipairs(shown) do list[i] = { kind = each.kind, cell = each.cell, offer = each.offer } end
	return list
end

function P.Box()
	return box
end

-- The piece as a picture, for a drawing of the screen: your run and a route suggested, in a tray by itself.
local function Sample(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:EnableMouse(false)
	local rows = {}
	for i, kind in ipairs({ "run", "offer" }) do
		local cell = Shy.Top.Make.Cell(f)
		cell.accept = Choice(cell, "check", C.good, function() end)
		cell.decline = Choice(cell, nil, C.dim, function() end)
		cell.decline:SetPoint("TOPRIGHT")
		cell.accept:SetPoint("TOPRIGHT", cell.decline, "TOPLEFT")
		Dress(cell, kind, SAMPLE[kind])
		rows[i] = cell
	end
	return Shy.Top.Make.Still(f, 300, rows)
end

local function Build()
	if box then return end
	box = HUD.Create({
		id = "shy.party", title = "Group",
		width = K.LEAST, height = ROW,
		point = { "TOP", "TOP", 0, -150 },
		shown = function() return (box and box.rows or 0) > 0 end,
		-- Only while an addon of ours says something here (ShyGroup, ShyWay).
		away = function() return next(settings) == nil end,
		-- In the drawer under the head, after the messages.
		top = { order = 34, sample = Sample, passing = true, wrap = true,
			empty = function() return (box.rows or 0) == 0 end },
		-- On a deck: the deck's width, and the deck is its housing.
		fit = function(_, width, own) tray:Fix(not own and width or nil) end,
		docked = function() Lay() end,
	})
	box:SetFrameStrata("DIALOG")
	box.rows = 0
	box.toggle = P.toggle
	tray = Shy.Top.Tray(box, { least = K.LEAST, lay = Lay })
	-- Its layout panel: an "On" box for each setting the addons gave it.
	box.panel = function(panel, Put, group)
		for _, key in ipairs(order) do
			local s = settings[key]
			if not s.check then
				s.check = group:Checkbox(panel, s.label, function() return s.get() == true end,
					function(on)
						s.set(on)
						HUD.Switched(box)
					end, { desc = s.hint })
			end
			Put(s.check, 20)
		end
	end
	Shy:On("SHY_HUD_LAYOUT", Changed)
	Shy:On("SHY_THEME", Changed)
	-- Keeps watch with the group while the screen is faded: a reply lights it.
	if Shy.Immersion and Shy.Immersion.Watch then Shy.Immersion.Watch("group", box) end
	Changed()
end

Shy:On("SHY_LOGIN", Build)
