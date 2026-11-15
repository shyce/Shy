-- The recap line and the ledger (the blow-by-blow panel), built from a death record.
-- ns.CreateLine(parent) and ns.CreateLedger(parent) return a frame with :Set(view) (see
-- ns.View) and :Tick(). The on-screen box (Line.lua) and the options preview share them.
-- Record text is saved plain values, never secret, so measuring it is safe.

local ADDON, ns = ...
local UI, Theme, Skin, B = Shy.UI, Shy.Theme, Shy.Skin, Shy.Brand
local C = UI.colors

-- The line: `left` and `right` are where its words begin and end; `close` is how far in the x stands,
-- clear of the bottom right corner, which resizes the line.
-- The line is the column's make (Shy.Top.Make): a plaque begun behind the steel ring with the killing sign,
-- pointed at its right end, 24 tall like every row up there.
local LINE = { w = 360, h = 24, left = 30, right = 50, close = 24 }
local SIGN = 12                -- the killing sign in the ring: the small glyphs are drawn for 12 units
local LEDGER = { w = 460, top = 56, step = 23, row = 22, foot = 30, pad = 14, bar = 70, inner = 418, prior = 20 }
ns.LINE, ns.LEDGER = LINE, LEDGER

local WHITE = { 1, 1, 1 }
local TIMES = "\195\151"       -- multiplication sign: an x present in every font used here
local DOT = " \194\183 "

-- Helpers

-- SetFontObject also sets color, shadow and alignment, so apply ours after it.
local function Face(fs, font, justify)
	fs:SetFontObject(font)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
end

local function Text(parent, font, color, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Face(fs, font, justify)
	fs:SetWordWrap(false)
	UI.Ink(fs, color or C.text)
	return fs
end

-- Text in the display font (Latin only).
local function Brand(parent, size, color, justify)
	local fs = UI.Text(parent, "", size, true, color)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	return fs
end

-- Sets a font string to its natural width, capped at `room`. Returns the width.
local function Fit(fs, room)
	local natural = math.ceil(fs:GetUnboundedStringWidth()) + 1
	local width = math.max(1, math.min(natural, room))
	fs:SetWidth(width)
	return width
end

local function Close(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(18, 18)
	button.glyph = Text(button, UI.NameFont(13), C.dim, "CENTER")
	button.glyph:SetPoint("CENTER", 0, 0)
	button.glyph:SetText(TIMES)
	button:SetScript("OnEnter", function(self) UI.Ink(self.glyph, C.hot) end)
	button:SetScript("OnLeave", function(self) UI.Ink(self.glyph, C.dim) end)
	button:SetScript("OnClick", function()
		if parent.onClose then parent.onClose() end
	end)
	return button
end

local function Amount(n)
	return BreakUpLargeNumbers(math.floor(n + 0.5))
end

-- Returns the health a blow removed and the health left.
local function Took(blow)
	if not (blow.before and blow.amount) then return nil end
	local took = math.min(blow.before, blow.amount)
	return took, blow.before - took
end

local function SchoolColor(blow, kill)
	if kill then return Theme.Harm() end
	if blow.school then return Theme.School(blow.school) end
	return C.text[1], C.text[2], C.text[3]
end

-- A row's tooltip

local function Tip(row)
	local blow, death = row.blow, row.death
	local rows = {}
	if blow.amount then
		local text = UI.Wrap({ SchoolColor(blow, false) }, Amount(blow.amount))
		local school
		if blow.school then school = C_Spell.GetSchoolString(blow.school) end
		if not issecretvalue(school) and type(school) == "string" and school ~= "" then text = text .. " " .. school end
		if blow.crit then text = text .. ", critical" end
		local took = Took(blow)
		local over = blow.over or (row.kill and took and blow.amount - took) or 0
		if over > 0 then text = text .. UI.Wrap(C.dim, (" (%s overkill)"):format(Amount(over))) end
		rows[#rows + 1] = { icon = blow.icon, glyph = "star", text = text }
	end
	local a = blow.by and death.who[blow.by]
	if a then
		local line = ns.Describe(a)
		rows[#rows + 1] = { glyph = "kill", text = UI.Wrap(C.dim, "by ") .. UI.Wrap(ns.NameColor(a), a.name)
			.. (line ~= "" and UI.Wrap(C.dim, " " .. line) or "") }
	end
	local when = row.kill and "The killing blow" or (blow.t and ("%.1f s before you died"):format(blow.t)) or nil
	local health = blow.before and death.max and death.max > 0 and ("at %d%% health"):format(math.floor(blow.before / death.max * 100 + 0.5)) or nil
	if when or health then
		rows[#rows + 1] = { glyph = "clock", text = when and health and (when .. ", " .. health) or when or health, quiet = true }
	end
	local nameless
	if not blow.spell then nameless = "No spell name was recorded." end
	UI.Tip(row, blow.spell or "A blow", nameless, { side = "RIGHT", width = 262, sections = { { rows = rows } } })
end

-- The line

-- The plate width the line's words want, from its ring's middle to its point (the column lays every plate
-- at the widest such: Shy.Top.Want).
local function LineNeed(line)
	local need = LINE.left - Shy.Top.Make.RING / 2 + math.ceil(line.name:GetUnboundedStringWidth()) + 10
		+ math.ceil(line.ago:GetUnboundedStringWidth()) + LINE.right
	if line.more:IsShown() then need = need + 4 + math.ceil(line.more:GetUnboundedStringWidth()) end
	if line.verb:IsShown() then need = need + 4 + math.ceil(line.verb:GetUnboundedStringWidth()) end
	return need
end

local function LineFit(line)
	local room = line:GetWidth() - LINE.left - LINE.right - 10 - math.ceil(line.ago:GetUnboundedStringWidth())
	if line.more:IsShown() then room = room - 4 - math.ceil(line.more:GetUnboundedStringWidth()) end
	if line.verb:IsShown() then room = room - 4 - math.ceil(line.verb:GetUnboundedStringWidth()) end
	Fit(line.name, room)
end

local function LineSet(line, view)
	line.view = view
	local death = view.death
	local words, color, more, verb = ns.Headline(death)
	line.name:SetText(words)
	UI.Ink(line.name, color)
	line.more:SetShown(more > 0)
	line.more:SetText(more > 0 and ("+" .. more) or "")
	line.verb:SetShown(verb ~= nil)
	line.verb:SetText(verb or "")
	line.verb:ClearAllPoints()
	line.verb:SetPoint("LEFT", more > 0 and line.more or line.name, "RIGHT", 4, 0)
	line:Light()
	line:Tick()
end

local function LineTick(line)
	if not line.view then return end
	line.ago:SetText(ns.Ago(line.view.death.at))
	LineFit(line)
end

-- Its light along the top is the killing blow's red, full and glowing round the ring until the death's
-- ledger has been opened, then quiet.
local function LineLight(line)
	local fresh = not line.view.death.seen
	UI.Tint(line.light, Theme.Harm, fresh and 0.9 or 0.35)
	UI.Tint(line.sign, fresh and Theme.Harm or C.dim)
	line.glow:SetShown(fresh)
	Shy.Top.Make.Look(line.plaque)
end

function ns.CreateLine(parent)
	local Make = Shy.Top.Make
	local line = CreateFrame("Frame", nil, parent)
	line:SetSize(LINE.w, LINE.h)
	local top = (LINE.h - Make.TALL) / 2
	line.plaque = Make.Plaque(line)
	Make.Shape(line, line.plaque, top, Make.RING / 2, true)
	Make.Look(line.plaque)
	line.glow = line:CreateTexture(nil, "BACKGROUND", nil, -7)
	line.glow:SetTexture(B.GLOW)
	line.glow:SetBlendMode("ADD")
	line.glow:SetSize(44, 44)
	line.glow:SetPoint("CENTER", line, "LEFT", Make.RING / 2, 0)
	UI.Tint(line.glow, Theme.Harm, 0.45)
	-- (The line is the column's width: what stands at its right end rides its point.)
	line.light = line:CreateTexture(nil, "ARTWORK")
	line.light:SetTexture(Shy.MEDIA .. "HoverLight")
	line.light:SetHeight(Make.LIGHT)
	line.light:SetPoint("TOPLEFT", line, "TOPLEFT", Make.RING - 4, -top)
	line.light:SetPoint("TOPRIGHT", line, "TOPRIGHT", -Make.POINT, -top)
	line.ring = Make.Ring(line)
	line.ring:SetPoint("CENTER", line, "LEFT", Make.RING / 2, 0)
	UI.Tint(line.ring, Theme.skin.metal)
	line.sign = line:CreateTexture(nil, "OVERLAY")
	line.sign:SetSize(SIGN, SIGN)
	line.sign:SetPoint("CENTER", line.ring, "CENTER")
	Shy.Hover.Glyph(line.sign, "kill", SIGN)
	UI.Concentric(line.ring, line.sign)

	line.name = Text(line, UI.NameFont(13))
	line.name:SetPoint("LEFT", LINE.left, 0)
	line.more = Text(line, UI.NameFont(12), C.dim)
	line.more:SetPoint("LEFT", line.name, "RIGHT", 4, 0)
	line.verb = Text(line, UI.TextFont(12), C.dim)
	line.ago = Brand(line, 12, C.head, "RIGHT")
	line.ago:SetPoint("RIGHT", line, "RIGHT", -LINE.right, 0)
	line.close = Close(line)
	line.close:SetPoint("RIGHT", line, "RIGHT", -LINE.close, 0)

	line.Set, line.Tick, line.Light, line.Need = LineSet, LineTick, LineLight, LineNeed
	return line
end

-- The ledger's rows

local function Row(ledger, i)
	local row = CreateFrame("Frame", nil, ledger)
	local y = -(LEDGER.top + (i - 1) * LEDGER.step)
	row:SetHeight(LEDGER.row)
	row:SetPoint("TOPLEFT", 8, y)
	row:SetPoint("TOPRIGHT", -8, y)

	row.hover = row:CreateTexture(nil, "BACKGROUND")
	row.hover:SetAllPoints()
	UI.Paint(row.hover, C.row, 0.9)
	row.hover:Hide()
	-- Killing blow: a red gradient and a red bar at the left end.
	row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.wash:SetAllPoints()
	row.wash:SetColorTexture(1, 1, 1, 1)
	local r, g, b = Theme.Harm()
	row.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.20), CreateColor(r, g, b, 0.04))
	row.mark = row:CreateTexture(nil, "BORDER")
	row.mark:SetPoint("TOPLEFT")
	row.mark:SetPoint("BOTTOMLEFT")
	row.mark:SetWidth(2)
	row.mark:SetColorTexture(r, g, b, 1)

	row.time = Text(row, UI.NameFont(10), C.dim, "RIGHT")
	row.time:SetPoint("RIGHT", row, "LEFT", 42, 0)

	-- Spell icon; an empty well when there is none.
	row.well = row:CreateTexture(nil, "BORDER")
	row.well:SetSize(Shy.Slot.SIZES.tiny, Shy.Slot.SIZES.tiny)
	row.well:SetPoint("LEFT", 48, 0)
	UI.Paint(row.well, Theme.skin.well)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints(row.well)
	row.icon:SetTexCoord(0.054, 0.946, 0.054, 0.946)
	-- Shy.Slot frame round the icon: a small slot, its frame outside the tiny icon.
	local out = (Shy.Slot.SIZES.small - Shy.Slot.SIZES.tiny) / 2
	row.slot = Shy.Slot.New(row, { to = row.well, x = -out, y = -out, icon = row.icon, well = false, hover = false, size = Shy.Slot.SIZES.small })

	row.spell = Text(row, UI.TextFont(12))
	row.spell:SetPoint("LEFT", 74, 0)
	row.by = Text(row, UI.NameFont(11))
	row.by:SetPoint("LEFT", row.spell, "RIGHT", 6, 0)
	row.crit = Text(row, UI.TextFont(10), C.dim)
	row.amount = Text(row, UI.NameFont(13), C.text, "RIGHT")
	row.amount:SetPoint("RIGHT", -(LEDGER.bar + 16), 0)

	-- Health bar: health left in the accent color, health the blow removed in red.
	local bar = CreateFrame("Frame", nil, row)
	bar:SetSize(LEDGER.bar, 8)
	bar:SetPoint("RIGHT", -6, 0)
	local rim = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
	rim:SetPoint("TOPLEFT", -2, 2)
	rim:SetPoint("BOTTOMRIGHT", 2, -2)
	UI.Paint(rim, C.border)
	local dark = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
	dark:SetPoint("TOPLEFT", -1, 1)
	dark:SetPoint("BOTTOMRIGHT", 1, -1)
	dark:SetColorTexture(0, 0, 0, 1)
	local floor = bar:CreateTexture(nil, "BACKGROUND", nil, 3)
	floor:SetAllPoints()
	floor:SetColorTexture(0.02, 0.02, 0.024, 1)
	bar.left = bar:CreateTexture(nil, "ARTWORK")
	bar.left:SetPoint("TOPLEFT")
	bar.left:SetPoint("BOTTOMLEFT")
	Skin.Hatch(bar.left)
	UI.Tint(bar.left, Theme.Accent)
	bar.took = bar:CreateTexture(nil, "ARTWORK")
	bar.took:SetPoint("TOP")
	bar.took:SetPoint("BOTTOM")
	Skin.Hatch(bar.took)
	UI.Tint(bar.took, Theme.Harm)
	row.bar = bar

	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		self.hover:Show()
		Tip(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hover:Hide()
		UI.TipHide(self)
	end)
	return row
end

local function RowSet(row, death, blow, kill, biggest)
	row.death, row.blow, row.kill = death, blow, kill
	row.wash:SetShown(kill)
	row.mark:SetShown(kill)
	row.time:SetText((kill or not blow.t) and "" or ("-%.1f s"):format(blow.t))

	row.icon:SetShown(blow.icon ~= nil)
	if blow.icon then row.icon:SetTexture(blow.icon) end
	if kill then row.slot:Mark(Theme.Harm()) else row.slot:Mark() end

	row.spell:SetText(blow.spell or "A blow")
	UI.Ink(row.spell, blow.spell and C.text or C.dim)
	local a = blow.by and death.who[blow.by]
	row.by:SetShown(a ~= nil)
	if a then
		row.by:SetText(a.name)
		UI.Ink(row.by, ns.NameColor(a))
	end
	row.crit:SetShown(blow.crit == true)
	row.crit:SetText(blow.crit and "crit" or "")
	row.crit:ClearAllPoints()
	row.crit:SetPoint("LEFT", a and row.by or row.spell, "RIGHT", 5, 0)

	-- The hardest blow is larger; the killing blow is red.
	Face(row.amount, UI.NameFont(biggest and 15 or 13), "RIGHT")
	row.amount:SetText(blow.amount and Amount(blow.amount) or "")
	UI.Ink(row.amount, SchoolColor(blow, kill))

	-- Spell and attacker share the width the amount leaves.
	local room = LEDGER.w - 16 - 74 - (LEDGER.bar + 16) - 10 - math.ceil(row.amount:GetUnboundedStringWidth())
	if blow.crit then room = room - 5 - math.ceil(row.crit:GetUnboundedStringWidth()) end
	room = room - Fit(row.spell, a and room - 46 or room)
	if a then Fit(row.by, room - 6) end

	local took, left = Took(blow)
	local max = death.max
	local bar = row.bar
	if took and max and max > 0 then
		local scale = LEDGER.bar / max
		local leftWide = math.min(LEDGER.bar, left * scale)
		local tookWide = math.min(LEDGER.bar - leftWide, took * scale)
		bar.left:SetShown(leftWide >= 0.5)
		bar.left:SetWidth(math.max(leftWide, 0.5))
		bar.took:SetShown(tookWide >= 0.5)
		bar.took:SetWidth(math.max(tookWide, 0.5))
		bar.took:ClearAllPoints()
		bar.took:SetPoint("TOPLEFT", bar, "TOPLEFT", leftWide, 0)
		bar.took:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", leftWide, 0)
	else
		bar.left:Hide()
		bar.took:Hide()
	end
end

-- One summary line above the rows for death.prior: start time, blow count, total damage.
local function Prior(f)
	local line = CreateFrame("Frame", nil, f)
	line:SetHeight(LEDGER.prior - 3)
	line:SetPoint("TOPLEFT", 8, -(LEDGER.top - 2))
	line:SetPoint("TOPRIGHT", -8, -(LEDGER.top - 2))
	line.time = Text(line, UI.NameFont(10), C.dim, "RIGHT")
	line.time:SetPoint("RIGHT", line, "LEFT", 42, 0)
	line.words = Text(line, UI.TextFont(11), C.dim)
	line.words:SetPoint("LEFT", 74, 0)
	line.amount = Text(line, UI.NameFont(12), C.dim, "RIGHT")
	line.amount:SetPoint("RIGHT", -(LEDGER.bar + 16), 0)
	local hair = line:CreateTexture(nil, "ARTWORK")
	hair:SetHeight(1)
	hair:SetPoint("BOTTOMLEFT", 0, -2)
	hair:SetPoint("BOTTOMRIGHT", 0, -2)
	UI.Paint(hair, C.rowEdge)
	line:EnableMouse(true)
	line:SetScript("OnEnter", function(self)
		local prior = self.prior
		if not prior then return end
		UI.Tip(self, "Earlier in the fight", ("%d earlier %s hit you for %s."):format(prior.n,
			prior.n == 1 and "blow" or "blows", Amount(prior.amount)), { side = "RIGHT",
			sections = { { rows = { { text = "Only the last few blows get full detail.", quiet = true } } } } })
	end)
	line:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	return line
end

local function PriorSet(line, prior)
	line.prior = prior
	line.time:SetText(prior.t and ("-%.1f s"):format(prior.t) or "")
	line.words:SetText(("%d earlier %s"):format(prior.n, prior.n == 1 and "blow" or "blows"))
	line.amount:SetText(Amount(prior.amount))
end

-- The ledger

-- Header: killer at the left, time and place at the right.
local function Head(f, view)
	local death = view.death
	local killer = ns.Killer(death)
	local words, color = ns.Headline(death)
	local second = killer and death.who[2] or nil
	f.name:SetText(words)
	UI.Ink(f.name, color)
	f.joint:SetShown(second ~= nil)
	f.second:SetShown(second ~= nil)
	if second then
		-- "Zugg Skullsplitter and Mala Coldhand +2"
		local others = #death.who - 2
		f.joint:SetText(" and ")
		f.second:SetText(second.name .. (others > 0 and UI.Wrap(C.dim, " +" .. others) or ""))
		UI.Ink(f.second, ns.NameColor(second))
	end

	f.ago:SetText(ns.Ago(death.at))
	local place = ns.Place(death)
	local where = ns.Clock(death.at) .. (place and (DOT .. place) or "")
	if death.away then where = where .. DOT .. UI.Wrap(C.alert, "you were AFK") end
	f.where:SetText(where)

	-- The names share the width the time leaves.
	local room = LEDGER.inner - 12 - math.ceil(f.ago:GetUnboundedStringWidth())
	if second then
		local joint = math.ceil(f.joint:GetUnboundedStringWidth())
		local name = Fit(f.name, room - joint - 50)
		Fit(f.joint, joint + 1)
		Fit(f.second, room - name - joint)
	else
		Fit(f.name, room)
	end

	-- Second row: level, race and class, guild, and the repeat-kill chip.
	local line = killer and ns.Describe(killer) or ""
	local guild = killer and killer.guild
	f.sub:SetText(line)
	f.guild:SetShown(guild ~= nil)
	f.guild:SetText(guild and ("<" .. guild .. ">") or "")
	f.chip:SetShown(view.again ~= nil)
	local chipWide = 0
	if view.again then
		f.chip.text:SetText(ns.Nth(view.again) .. " time today")
		chipWide = math.ceil(f.chip.text:GetUnboundedStringWidth()) + 10
		f.chip:SetWidth(chipWide)
	end
	room = LEDGER.inner - 10 - math.ceil(f.where:GetUnboundedStringWidth()) - (view.again and chipWide + 6 or 0)
	local x = LEDGER.pad
	if line ~= "" then x = x + Fit(f.sub, room) + 4 end
	if guild then
		f.guild:ClearAllPoints()
		f.guild:SetPoint("TOPLEFT", x, -34)
		x = x + Fit(f.guild, math.max(30, room - (x - LEDGER.pad))) + 4
	end
	f.chip:ClearAllPoints()
	f.chip:SetPoint("TOPLEFT", x + 2, -33)
end

-- Footer: "174 health in 4.1 s" at the left, the day's earlier deaths at the right.
local function Foot(f, view)
	local blows, prior = view.death.blows, view.death.prior
	local first = blows[1]
	local lost, span = nil, first and first.t
	if first then
		lost = first.before
		if not lost then
			lost = 0
			for _, blow in ipairs(blows) do lost = lost + (blow.amount or 0) end
		end
		-- Include the damage summed in `prior`.
		if prior then lost, span = lost + prior.amount, prior.t or span end
	end
	local timed = span ~= nil and span > 0
	f.lost:SetText(lost and Amount(lost) or "")
	f.lostWord:SetText(lost and (timed and " health in " or #blows == 1 and not prior and " health in one blow" or " health") or "")
	f.span:SetText(lost and timed and ("%.1f s"):format(span) or "")
	local used = math.ceil(f.lost:GetUnboundedStringWidth()) + math.ceil(f.lostWord:GetUnboundedStringWidth())
		+ math.ceil(f.span:GetUnboundedStringWidth())

	local earlier = view.earlier
	f.first:SetShown(#earlier == 0)
	f.kicker:SetShown(#earlier > 0)
	-- The newer death always shows, truncated if needed; the older only if it fits whole.
	local room = LEDGER.w - 2 * LEDGER.pad - used - 16 - math.ceil(f.kicker:GetUnboundedStringWidth()) - 6
	local x = -LEDGER.pad
	local shown = 0
	for i, entry in ipairs(f.entries) do
		local death = earlier[i]
		entry.death = death
		if death then
			local name, color = ns.Short(death)
			entry.time:SetText(ns.Clock(death.at))
			entry.name:SetText(name)
			UI.Ink(entry.name, color)
			local timeWide = math.ceil(entry.time:GetUnboundedStringWidth()) + 4
			if i == 1 then
				entry.wide = timeWide + Fit(entry.name, math.max(40, room - timeWide))
				room = room - entry.wide
				shown = 1
			else
				entry.wide = timeWide + Fit(entry.name, 400)
				if entry.wide + 12 <= room then shown = 2 end
			end
		end
	end
	for i, entry in ipairs(f.entries) do entry:SetShown(i <= shown) end
	f.dot:SetShown(shown == 2)
	for i = shown, 1, -1 do
		local entry = f.entries[i]
		entry:SetSize(entry.wide, 16)
		entry:ClearAllPoints()
		entry:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", x, 5)
		x = x - entry.wide
		if i == 2 then
			f.dot:ClearAllPoints()
			f.dot:SetPoint("RIGHT", entry, "LEFT", 0, 0)
			x = x - 12
		end
	end
	f.kicker:ClearAllPoints()
	f.kicker:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", x - 6, 8)
end

local function LedgerSet(f, view)
	f.view = view
	local death = view.death
	local blows = death.blows
	local n = #blows
	Head(f, view)

	local biggest, most = nil, 0
	for i, blow in ipairs(blows) do
		if blow.amount and blow.amount > most then biggest, most = i, blow.amount end
	end
	-- The rows shift down when the `prior` summary line shows.
	local prior = n > 0 and death.prior or nil
	local down = prior and LEDGER.prior or 0
	if prior and not f.prior then f.prior = Prior(f) end
	if f.prior then f.prior:SetShown(prior ~= nil) end
	if prior then PriorSet(f.prior, prior) end
	for i, blow in ipairs(blows) do
		local row = f.rows[i]
		if not row then
			row = Row(f, i)
			f.rows[i] = row
		end
		local y = -(LEDGER.top + down + (i - 1) * LEDGER.step)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 8, y)
		row:SetPoint("TOPRIGHT", -8, y)
		RowSet(row, death, blow, i == n, i == biggest and n > 1)
		row:Show()
	end
	for i = n + 1, #f.rows do f.rows[i]:Hide() end
	f.none:SetShown(n == 0)

	Foot(f, view)
	f:SetHeight(LEDGER.top + down + math.max(n, 1) * LEDGER.step + LEDGER.foot)
end

local function LedgerTick(f)
	if f.view then Head(f, f.view) end
end

local function Entry(f)
	local entry = CreateFrame("Button", nil, f)
	entry.time = Text(entry, UI.TextFont(11), C.dim)
	entry.time:SetPoint("LEFT", 0, 0)
	entry.name = Text(entry, UI.NameFont(11))
	entry.name:SetPoint("LEFT", entry.time, "RIGHT", 4, 0)
	entry:SetScript("OnEnter", function(self)
		if not f.onEarlier then return end
		UI.Tip(self, "Earlier death", nil, { side = "TOP", hints = { { "left", "Show it" } } })
	end)
	entry:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	entry:SetScript("OnClick", function(self)
		if f.onEarlier and self.death then f.onEarlier(self.death) end
	end)
	return entry
end

function ns.CreateLedger(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(LEDGER.w)
	f:SetHeight(LEDGER.top + LEDGER.step + LEDGER.foot)
	-- The killer's name and the time stand in the window header; who they were, under it.
	local head = UI.Head(f, { size = "window", close = function() if f.onClose then f.onClose() end end })
	f:EnableMouse(true)
	local pad = LEDGER.pad

	f.name = Text(f, UI.NameFont(head.size.text))
	UI.OnHead(f.name, "LEFT", f, "LEFT", pad)
	f.joint = Text(f, UI.NameFont(11), C.dim)
	f.joint:SetPoint("BOTTOMLEFT", f.name, "BOTTOMRIGHT", 0, 2)
	f.second = Text(f, UI.NameFont(11))
	f.second:SetPoint("BOTTOMLEFT", f.joint, "BOTTOMRIGHT", 0, 0)
	f.sub = Text(f, UI.TextFont(11))
	f.sub:SetPoint("TOPLEFT", pad, -34)
	f.guild = Text(f, UI.TextFont(11), C.dim)
	f.chip = CreateFrame("Frame", nil, f)
	f.chip:SetHeight(14)
	local fill = f.chip:CreateTexture(nil, "ARTWORK")
	fill:SetAllPoints()
	UI.Paint(fill, C.fill)
	f.chip.text = Text(f.chip, UI.NameFont(10), WHITE, "CENTER")
	f.chip.text:SetPoint("CENTER", 0, 0)

	f.ago = Brand(f, head.size.text, C.head, "RIGHT")
	f.ago:SetPoint("RIGHT", head.close, "LEFT", -8, 0)
	f.where = Text(f, UI.TextFont(11), C.dim, "RIGHT")
	f.where:SetPoint("TOPRIGHT", -pad, -34)
	f.close = head.close

	f.rows = {}
	f.none = Text(f, UI.TextFont(12), C.dim, "CENTER")
	f.none:SetPoint("TOP", 0, -(LEDGER.top + 4))
	f.none:SetText("No damage was recorded for this death.")

	local hair = f:CreateTexture(nil, "ARTWORK")
	hair:SetHeight(1)
	hair:SetPoint("BOTTOMLEFT", 8, 25)
	hair:SetPoint("BOTTOMRIGHT", -8, 25)
	UI.Paint(hair, C.rowEdge)
	f.lost = Text(f, UI.NameFont(11), C.head)
	f.lost:SetPoint("BOTTOMLEFT", pad, 7)
	f.lostWord = Text(f, UI.TextFont(11), C.dim)
	f.lostWord:SetPoint("BOTTOMLEFT", f.lost, "BOTTOMRIGHT", 0, 0)
	f.span = Text(f, UI.NameFont(11), C.head)
	f.span:SetPoint("BOTTOMLEFT", f.lostWord, "BOTTOMRIGHT", 0, 0)

	f.first = Text(f, UI.TextFont(11), C.dim, "RIGHT")
	f.first:SetPoint("BOTTOMRIGHT", -pad, 7)
	f.first:SetText("Your first death today")
	f.kicker = Brand(f, 9, Theme.Accent, "RIGHT")
	f.kicker:SetText("EARLIER")
	f.entries = { Entry(f), Entry(f) }
	f.dot = Text(f, UI.TextFont(11), C.dim, "CENTER")
	f.dot:SetWidth(12)
	f.dot:SetText("\194\183")

	f.Set, f.Tick = LedgerSet, LedgerTick
	return f
end
