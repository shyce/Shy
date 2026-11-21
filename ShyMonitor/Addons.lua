-- All addons, the home view: three gauges (the frame, memory, the errors) and the table of every loaded
-- Shy addon under them, sorted by the lit column, with the costliest addons of all at its foot. Rows are
-- pooled and given a value only when it changed.

local _, ns = ...
local UI, C, Theme, Skin = Shy.UI, Shy.UI.colors, Shy.Theme, Shy.Skin
local S = ns.Samples
local W = ns.Window
local floor, format, max, min = math.floor, string.format, math.max, math.min

local GAUGE = 64          -- the gauges' height
local GAP = 8             -- between gauges
local ERRORS_W = 220      -- the errors gauge's width
local IN = 12             -- a gauge's inside margin
local TOP_Y = -10         -- its label and note, down from the top
local VALUE_Y = -28       -- its value
local SPARK_W = 150       -- a gauge's line, at most; the value has the rest
local HEAD = 20           -- the table's header row
local ROW = 22            -- a row's pitch
local BARS = 60           -- a gauge's sparkline, in bars
local TOP_ROWS = 8        -- the costliest addons of all

local view = {}
local gauges, header, scroll, content, sub
local rows, tops, order, iconOf, churn = {}, {}, {}, {}, {}
local sortKey, sortDown = "share", true

-- Columns: key, label, left, width, aligned right
local COLS = {
	{ "name", "Addon", 0, 170 },
	{ "share", "Share", 176, 112 },
	{ "now", "Now", 296, 54, true },
	{ "avg", "Average", 356, 54, true },
	{ "peak", "Peak", 416, 54, true },
	{ "mem", "Memory", 478, 104, true },
	{ "churn", "Churn", 590, 64, true },
	{ "errors", "Errors", 662, 44, true },
}
local FLAG_X = 716
-- What each column says, for its hover.
local MEANS = {
	name = "Every Shy addon the game has loaded.",
	share = "How much of each frame it takes right now, counted the way the game's addon list does.",
	now = "Milliseconds it takes each frame, averaged over the last 60 frames.",
	avg = "Milliseconds it takes each frame, on average since login.",
	peak = "Its worst frame since login, in milliseconds.",
	mem = "Memory it uses now, and in grey what it still held after the last clean-up.",
	churn = "New memory it uses each second: at least what its clocks saw, or the ten-second measure if you ran one.",
	errors = "Errors it has caused.",
}

-- A sparkline: n bars standing on the plate's foot, the tallest the ring's largest value.
local function Spark(parent, n, color)
	local s = CreateFrame("Frame", nil, parent)
	s.bars = {}
	for i = 1, n do
		local t = s:CreateTexture(nil, "ARTWORK")
		UI.Paint(t, color, 0.8)
		s.bars[i] = t
	end
	function s:Lay(width, height)
		local step = width / n
		for i, t in ipairs(self.bars) do
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * step, 0)
			t:SetWidth(max(1, step - 1))
		end
		self.h = height
		self:SetSize(width, height)
	end
	-- The last n of the ring, every `every`th.
	function s:Draw(ring, every)
		every = every or 1
		local most = ring:Max()
		local count = ring.count
		for i = 1, n do
			local at = count - (n - i) * every
			local v = at >= 1 and ring:Get(at) or 0
			ns.Height(self.bars[i], most > 0 and max(1, v / most * self.h) or 1)
		end
	end
	return s
end

-- A gauge: its label at the top left and a note across from it on the same line, the value under the
-- label, its line (where it has one) in the band to the value's right.
local function Gauge(parent, name)
	local g = CreateFrame("Button", nil, parent)
	UI.Skin(g, C.bg, C.border)
	g.name = UI.Text(g, name, 12, true, C.head)
	g.name:SetPoint("TOPLEFT", IN, TOP_Y)
	g.note = UI.Words(g, UI.NameFont(11), C.dim)
	g.note:SetPoint("TOPRIGHT", -IN, TOP_Y - 1)
	g.note:SetJustifyH("RIGHT")
	g.note:SetWordWrap(false)
	g.value = UI.Words(g, UI.NameFont(19), C.text)
	g.value:SetPoint("TOPLEFT", IN, VALUE_Y)
	g.unit = UI.Text(g, "", 11, false, C.dim)
	g.unit:SetPoint("BOTTOMLEFT", g.value, "BOTTOMRIGHT", 5, 2)
	g.unit:SetWordWrap(false)
	return g
end

local function Header(parent)
	local h = CreateFrame("Frame", nil, parent)
	h.cells = {}
	for _, col in ipairs(COLS) do
		local key, label, left, width, right = col[1], col[2], col[3], col[4], col[5]
		local b = CreateFrame("Button", nil, h)
		b:SetPoint("TOPLEFT", left, 0)
		b:SetSize(width, HEAD)
		b.text = UI.Text(b, label:upper(), 10, false, C.dim)
		b.text:SetPoint(right and "RIGHT" or "LEFT", 0, 0)
		b.line = b:CreateTexture(nil, "ARTWORK")
		b.line:SetPoint("BOTTOMLEFT", 0, 1)
		b.line:SetPoint("BOTTOMRIGHT", 0, 1)
		b.line:SetHeight(1)
		UI.Paint(b.line, Theme.light)
		b.key = key
		b:SetScript("OnClick", function(self)
			if sortKey == self.key then sortDown = not sortDown else sortKey, sortDown = self.key, self.key ~= "name" end
			view.refresh()
		end)
		b:SetScript("OnEnter", function(self) UI.Tip(self, label, (MEANS[key] or "") .. " Click to sort by it. Click again to reverse.", { side = "BOTTOM" }) end)
		b:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		h.cells[key] = b
	end
	function h:Look()
		if self.lit == sortKey then return end
		self.lit = sortKey
		for key, b in pairs(self.cells) do
			local on = key == sortKey
			UI.Ink(b.text, on and C.hot or C.dim)
			ns.Shown(b.line, on)
		end
	end
	return h
end

local function Cell(row, col)
	local key, _, left, width, right = col[1], col[2], col[3], col[4], col[5]
	local fs = UI.Words(row, UI.NameFont(11), C.text)
	fs:SetPoint(right and "RIGHT" or "LEFT", row, "LEFT", right and left + width or left, 0)
	fs:SetWidth(width)
	fs:SetJustifyH(right and "RIGHT" or "LEFT")
	fs:SetWordWrap(false)
	row[key] = fs
	return fs
end

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, content)
	row:SetHeight(ROW)
	row:SetPoint("TOPLEFT", 0, -HEAD - 2 - (i - 1) * ROW)
	row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	row.edge = row:CreateTexture(nil, "BACKGROUND")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetPoint("BOTTOMRIGHT")
	row.edge:SetHeight(1)
	UI.Paint(row.edge, C.rowEdge, 0.55)
	row.hot = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.row, 0.9)
	row.hot:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 0, 0)
	row.name = UI.Text(row, "", 12, true, C.head)
	row.name:SetPoint("LEFT", 22, 0)
	row.name:SetWidth(COLS[1][4] - 22)
	row.name:SetWordWrap(false)
	-- The share: a short hatch bar, then the percent.
	row.bar = CreateFrame("StatusBar", nil, row)
	row.bar:SetSize(64, 8)
	row.bar:SetPoint("LEFT", COLS[2][3], 0)
	Skin.HatchBar(row.bar)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(0)
	UI.Skin(row.bar, C.bg, C.rowEdge)
	row.barFill = row.bar:GetStatusBarTexture()
	row.share = UI.Words(row, UI.NameFont(11), C.text)
	row.share:SetPoint("LEFT", COLS[2][3] + 72, 0)
	for i2 = 3, #COLS do Cell(row, COLS[i2]) end
	UI.Ink(row.errors, C.bad)
	row.data = UI.Text(row, "data, loaded while you are there", 11, false, C.dim)
	row.data:SetPoint("RIGHT", row, "LEFT", COLS[5][3] + COLS[5][4], 0)
	row.data:Hide()
	row.flag = UI.Text(row, "", 11, false, C.alert)
	row.flag:SetPoint("LEFT", FLAG_X + 14, 0)
	row.flag:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.flag:SetWordWrap(false)
	row:SetScript("OnEnter", function(self) self.hot:Show() end)
	row:SetScript("OnLeave", function(self) self.hot:Hide() end)
	row:SetScript("OnClick", function(self)
		if W.Views().addon and self.addon then W.Open("addon", self.addon) end
	end)
	rows[i] = row
	return row
end

local function TopRow(i)
	local row = tops[i]
	if row then return row end
	row = CreateFrame("Frame", nil, content)
	row:SetHeight(ROW)
	row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	row.edge = row:CreateTexture(nil, "BACKGROUND")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetPoint("BOTTOMRIGHT")
	row.edge:SetHeight(1)
	UI.Paint(row.edge, C.rowEdge, 0.55)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 0, 0)
	row.name = UI.Text(row, "", 12, true, C.head)
	row.name:SetPoint("LEFT", 22, 0)
	row.name:SetWidth(260)
	row.name:SetWordWrap(false)
	Cell(row, COLS[3])
	Cell(row, { "share", "", COLS[4][3], 114, true })
	UI.Ink(row.share, C.dim)
	tops[i] = row
	return row
end

-- A data addon's folder said plainly, made once.
local shownName = {}
local function ShownName(name)
	local shown = shownName[name]
	if not shown then
		shown = name:gsub("^ShyWay_Ground_(%d+)$", "ShyWay Ground %1")
		shownName[name] = shown
	end
	return shown
end

-- An addon's mark: the one it registered, else its own folder's by the family's naming (<Addon>/Media/<Addon>Mark);
-- a data addon (ShyWay_Ground_1) wears the mark of the addon it belongs to.
function ns.IconOf(name)
	for _, addon in ipairs(Shy.order) do
		if addon.name == name then return addon.mark end
	end
	local base = name:match("^(Shy%a+)") or name
	return "Interface\\AddOns\\" .. base .. "\\Media\\" .. base .. "Mark"
end
local function IconOf(name)
	local icon = iconOf[name]
	if icon == nil then
		icon = ns.IconOf(name) or false
		iconOf[name] = icon
	end
	return icon
end

local function SetIcon(texture, name)
	local icon = IconOf(name)
	if texture.shyIcon == icon then return end
	texture.shyIcon = icon
	if icon then
		Theme.Icon(texture, icon)
		texture:Show()
	else
		texture:Hide()
	end
end

-- What each addon's clocks made, as KB a second over the time the window has been open since the
-- clocks were reset (a lower bound: the clocks see their own runs, not everything).
local openSeconds, openAt = 0, nil
local function Churn()
	for name in pairs(churn) do churn[name] = 0 end
	for _, clock in pairs(Shy.Clocks()) do
		churn[clock.addon] = (churn[clock.addon] or 0) + clock.kb
	end
end

local function Value(name, key)
	local a = S.by[name]
	if key == "name" then return name end
	if key == "mem" then return a.inUse end
	if key == "errors" then return a.errors end
	if key == "churn" then return churn[name] or 0 end
	if a.data then return -1 end
	return a[key] or 0
end
local function Before(x, y)
	local a, b = Value(x, sortKey), Value(y, sortKey)
	if a == b then return x < y end
	if sortKey == "name" then return (a < b) ~= sortDown end
	if sortDown then return a > b end
	return a < b
end

function view.build(frame)
	-- The gauges.
	gauges = { frame = Gauge(frame, "Frame"), memory = Gauge(frame, "Memory"), errors = Gauge(frame, "Errors") }
	-- The addons' share of the frame: a hatch bar under the value, as long as the value's column.
	gauges.frame.bar = CreateFrame("StatusBar", nil, gauges.frame)
	gauges.frame.bar:SetSize(100, 5)
	gauges.frame.bar:SetPoint("BOTTOMLEFT", IN, 10)
	Skin.HatchBar(gauges.frame.bar)
	gauges.frame.bar:SetMinMaxValues(0, 1)
	UI.Skin(gauges.frame.bar, C.bg, C.rowEdge)
	gauges.frame.fill = gauges.frame.bar:GetStatusBarTexture()
	gauges.frame.spark = Spark(gauges.frame, BARS, Theme.Accent)
	gauges.memory.spark = Spark(gauges.memory, BARS, C.dim)
	-- The errors: the bug where the others' value starts, the count after it.
	gauges.errors.bug = gauges.errors:CreateTexture(nil, "ARTWORK")
	gauges.errors.bug:SetTexture(Shy.MEDIA .. "GlyphBugLarge")
	gauges.errors.bug:SetSize(20, 20)
	gauges.errors.bug:SetPoint("TOPLEFT", IN - 1, VALUE_Y)
	gauges.errors.value:ClearAllPoints()
	gauges.errors.value:SetPoint("TOPLEFT", IN + 26, VALUE_Y)
	gauges.errors:SetScript("OnClick", function() if Shy.Errors then Shy.Errors.Open() end end)
	gauges.errors:SetScript("OnEnter", function(self) UI.Tip(self, "Errors", "Every error caught, with its stack.", { side = "BOTTOM", hints = { { "left", "Open" } } }) end)
	gauges.errors:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	gauges.frame:SetScript("OnEnter", function(self) UI.Tip(self, "Frame", "How long each frame takes, averaged over the last 60, and how much of it the addons take.", { side = "BOTTOM" }) end)
	gauges.frame:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	gauges.memory:SetScript("OnEnter", function(self) UI.Tip(self, "Memory", "Memory the addons use now, with the last ten minutes beside it.", { side = "BOTTOM" }) end)
	gauges.memory:SetScript("OnLeave", function(self) UI.TipHide(self) end)

	-- The table.
	scroll = UI.ScrollArea(frame, 100, 100)
	scroll:SetPoint("TOPLEFT", 0, -GAUGE - 10)
	content = scroll.content
	header = Header(content)
	header:SetPoint("TOPLEFT")
	header:SetPoint("RIGHT")
	header:SetHeight(HEAD)
	sub = UI.Text(content, "COSTLIEST OF ALL", 10, false, C.dim)
	sub.edge = content:CreateTexture(nil, "BACKGROUND")
	sub.edge:SetHeight(1)
	UI.Paint(sub.edge, C.border, 0.7)
end

function view.lay(w, h)
	local g = (w - GAP * 2 - ERRORS_W) / 2
	gauges.frame:SetSize(g, GAUGE)
	gauges.frame:SetPoint("TOPLEFT", 0, 0)
	gauges.memory:SetSize(g, GAUGE)
	gauges.memory:SetPoint("TOPLEFT", g + GAP, 0)
	gauges.errors:SetSize(ERRORS_W, GAUGE)
	gauges.errors:SetPoint("TOPLEFT", (g + GAP) * 2, 0)
	-- The line takes the band right of the value, at most SPARK_W; the note has the top line short of the
	-- label; nothing runs under anything else.
	local sw = max(60, min(SPARK_W, g * 0.38))
	local value = g - sw - IN * 3
	for _, gauge in ipairs({ gauges.frame, gauges.memory }) do
		gauge.spark:Lay(sw, GAUGE + VALUE_Y - 10)
		gauge.spark:SetPoint("BOTTOMRIGHT", -IN, 10)
		gauge.note:SetWidth(g - IN * 3 - gauge.name:GetStringWidth())
		gauge.unit:SetWidth(max(30, value - 70))
	end
	gauges.frame.bar:SetWidth(value)
	gauges.errors.note:SetWidth(ERRORS_W - IN * 3 - gauges.errors.name:GetStringWidth())
	gauges.errors.unit:SetWidth(ERRORS_W - IN * 2 - 26 - 30)
	scroll:SetSize(w, h - GAUGE - 10)
	content:SetWidth(w - 14)
end

local function Gauges()
	local f, m, e = gauges.frame, gauges.memory, gauges.errors
	if S.off then
		ns.Text(f.value, "off")
		ns.Text(f.unit, "")
		ns.Text(f.note, "the game's addon profiler is off")
	else
		ns.Num(f.value, S.game, "%.1f ms", 10)
		ns.Text(f.unit, "a frame")
		local share = S.game > 0 and S.all / S.game or 0
		f.bar:SetValue(share)
		local key = floor(S.all * 100) * 1000 + floor(share * 100)
		if f.note.shyKey ~= key then
			f.note.shyKey = key
			f.note:SetText(format("addons take %.2f ms, %.0f%%", S.all, share * 100))
		end
	end
	f.spark:Draw(S.frame.game)
	ns.Num(m.value, S.heapNow / 1024, "%.0f MB", 1)
	local M = ns.Memory
	if M and M.heapKept then
		ns.Num(m.unit, M.heapKept / 1024, "%.0f held", 1)
	else
		ns.Text(m.unit, "in use")
	end
	local left = M and M.ChurnLeft(GetTime())
	if left then
		ns.Num(m.note, left, "counting the churn, %.0f s left", 1)
	elseif M and M.churnAt then
		ns.Num(m.note, M.churnTotal or 0, "churn %.0f KB/s over 10 s", 1)
	elseif M and M.keptAt then
		local ago = GetTime() - M.keptAt
		local k = math.floor(ago / 10)
		if m.note.shyKey ~= k then
			m.note.shyKey = k
			m.note.shyText = nil
			m.note:SetText(format("cleaned up %.0f s ago%s", ago, M.watch and ", watching" or ""))
		end
	else
		ns.Text(m.note, "Collect shows what is held")
	end
	m.spark:Draw(S.heap, 10)
	ns.Num(e.value, S.errorsFresh, "%d", 1)
	local key = S.errorsTotal
	if e.unit.shyKey ~= key then
		e.unit.shyKey = key
		e.unit:SetText(key > 0 and format("new, %d in all", key) or "")
	end
	ns.Text(e.note, S.errorsFresh > 0 and "click to read" or (S.errorsTotal > 0 and "none new" or "none caught"))
end

function view.refresh()
	local now = GetTime()
	if openAt then openSeconds = openSeconds + (now - openAt) end
	openAt = now
	Churn()
	Gauges()
	header:Look()
	-- The rows, in the lit column's order.
	for i = #order, 1, -1 do order[i] = nil end
	for i, name in ipairs(S.names) do order[i] = name end
	table.sort(order, Before)
	local seconds = max(openSeconds, 1)
	local y = HEAD + 2
	for i, name in ipairs(order) do
		local row = Row(i)
		local a = S.by[name]
		row.addon = name
		ns.Text(row.name, ShownName(name))
		SetIcon(row.icon, name)
		local data = a.data or S.off
		ns.Shown(row.data, data)
		ns.Shown(row.bar, not data)
		ns.Shown(row.share, not data)
		ns.Shown(row.now, not data)
		ns.Shown(row.avg, not data)
		ns.Shown(row.peak, not data)
		if not data then
			row.bar:SetValue(min(1, a.share / 35))
			local gold = a.share > 20
			if row.gold ~= gold then
				row.gold = gold
				UI.Tint(row.barFill, gold and C.alert or Theme.Accent)
			end
			ns.Num(row.share, a.share, "%.1f%%", 10)
			ns.Num(row.now, a.now, "%.2f", 100)
			ns.Num(row.avg, a.avg, "%.2f", 100)
			ns.Num(row.peak, a.peak, "%.0f", 1)
		end
		local held = ns.Memory and ns.Memory.kept[name]
		local k = math.floor(a.inUse / 102.4) * 100000 + (held and math.floor(held / 102.4) or 0)
		if row.mem.shyKey ~= k then
			row.mem.shyKey = k
			row.mem:SetText(held and format("%.1f MB |cff%s%.1f held|r", a.inUse / 1024, UI.Hex(C.dim), held / 1024) or format("%.1f MB", a.inUse / 1024))
		end
		local exact = ns.Memory and ns.Memory.churnBy[name]
		local made = exact or (churn[name] or 0) / seconds
		if made >= 0.5 then ns.Num(row.churn, made, "%.0f KB/s", 1) else ns.Text(row.churn, "") end
		if a.errors > 0 then ns.Num(row.errors, a.errors, "%d", 1) else ns.Text(row.errors, "") end
		ns.Text(row.flag, ns.FlagOf and ns.FlagOf(name) or "")
		ns.Shown(row, true)
		y = y + ROW
	end
	for i = #order + 1, #rows do ns.Shown(rows[i], false) end
	-- The costliest of all.
	local n = 0
	local some = not S.off and #S.top > 0
	ns.Shown(sub, some)
	ns.Shown(sub.edge, some)
	if some then
		ns.At(sub, 0, y + 6)
		if ns.At(sub.edge, 0, y + ROW) then sub.edge:SetPoint("RIGHT", content, "RIGHT", 0, 0) end
		y = y + ROW + 2
		for _, result in ipairs(S.top) do
			if n >= TOP_ROWS then break end
			n = n + 1
			local row = TopRow(n)
			if ns.At(row, 0, y) then row:SetPoint("RIGHT", content, "RIGHT", 0, 0) end
			ns.Text(row.name, result.addOnName)
			SetIcon(row.icon, result.addOnName)
			ns.Num(row.now, result.metricValue, "%.2f", 100)
			ns.Num(row.share, S.Share(result.addOnName), "%.1f%%", 10)
			ns.Shown(row, true)
			y = y + ROW
		end
	end
	for i = n + 1, #tops do ns.Shown(tops[i], false) end
	if ns.Height(content, y + 4) then scroll:Update() end
end

function view.show()
	openAt = nil
end

function view.reset()
	openSeconds, openAt = 0, nil
end

function view.copy()
	return ns.Copy.Addons()
end

function view.title()
	return "All addons"
end

-- Its crumb's caret: every loaded addon, by name.
function view.kids()
	local kids = {}
	for _, name in ipairs(S.names) do kids[#kids + 1] = { text = ShownName(name), view = "addon", key = name } end
	table.sort(kids, function(a, b) return a.text < b.text end)
	return kids
end

-- For the tests: the pieces.
function view.Pieces()
	return gauges, rows, tops, header, scroll
end

W.View("addons", view)
