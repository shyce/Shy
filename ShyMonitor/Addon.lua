-- One addon: its head card (the numbers the table had, the frames over 5 ms, what it holds, what it makes),
-- then sections whose headings say what they are and carry the sum: Work (its clocks by subsystem),
-- Memory (its caches with Empty, its kept tables with Weigh), Counters (what it registered), Errors.
-- A section with nothing takes no room. Rows are pooled and given a value only when it changed.

local _, ns = ...
local UI, C, Theme, B = Shy.UI, Shy.UI.colors, Shy.Theme, Shy.Brand
local S, M, W = ns.Samples, ns.Memory, ns.Window
local format, max = string.format, math.max

local SEC = 24       -- a section heading
local GROUP = 20     -- a group heading
local ROW = 20       -- a row
local C0 = 300       -- where a row's numbers begin
local CW = 70        -- a number's width
local IN = 14        -- the card's inside margin
local NAME_W = 280   -- the card's left: icon, name, version, tagline
local STAT_W = 112   -- a stat's least width beside the name; narrower, the stats take a row under it
local STAT_H = 46    -- the row of stats: label, value, caption
local STAT_IN = 12   -- a stat's words in from its rule
local STATS = 5
local LINES = 90     -- the two lines' plates
local BARS = 60

local view = {}
local addon           -- the addon shown, by name
local card, scroll, content, lines, empty
local cardHeight = 72
local pools = {}
local clocksOf, groupMs = {}, {}
local y

-- A pool of rows of one make: Get(i) makes or reuses, Trim(n) hides the rest.
local function Pool(make)
	local pool = { rows = {}, used = 0 }
	function pool:Get()
		self.used = self.used + 1
		local row = self.rows[self.used]
		if not row then
			row = CreateFrame("Button", nil, content)
			row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
			make(row)
			self.rows[self.used] = row
		end
		return row
	end
	function pool:Trim()
		for i = self.used + 1, #self.rows do ns.Shown(self.rows[i], false) end
		self.used = 0
	end
	return pool
end

local function Place(row, height)
	ns.Height(row, height)
	ns.At(row, 0, y)
	ns.Shown(row, true)
	y = y + height
end

local function Number(row, key, left, width)
	local fs = row:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(UI.NameFont(11))
	UI.Ink(fs, C.text)
	fs:SetPoint("RIGHT", row, "LEFT", left + width, 0)
	fs:SetWidth(width)
	fs:SetJustifyH("RIGHT")
	fs:SetWordWrap(false)
	row[key] = fs
	return fs
end

local function MakeSection(row)
	row.text = UI.Text(row, "", 13, true, C.head)
	row.text:SetPoint("BOTTOMLEFT", 0, 5)
	row.em = row:CreateFontString(nil, "OVERLAY")
	row.em:SetFontObject(UI.NameFont(11))
	UI.Ink(row.em, C.dim)
	row.em:SetPoint("BOTTOMRIGHT", -4, 5)
	row.line = row:CreateTexture(nil, "ARTWORK")
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.line:SetHeight(1)
	UI.Paint(row.line, C.border, 0.9)
	row.lit = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.lit:SetPoint("BOTTOMLEFT")
	row.lit:SetSize(120, 1)
	UI.Paint(row.lit, Theme.Accent, 0.7)
	row:EnableMouse(false)
end

local function MakeGroup(row)
	row.text = row:CreateFontString(nil, "OVERLAY")
	row.text:SetFontObject(UI.NameFont(10))
	UI.Ink(row.text, C.hot)
	row.text:SetPoint("LEFT", 0, 0)
	row.em = row:CreateFontString(nil, "OVERLAY")
	row.em:SetFontObject(UI.NameFont(10))
	UI.Ink(row.em, C.dim)
	row.em:SetPoint("RIGHT", -4, 0)
	row:EnableMouse(false)
end

local function MakeRow(row)
	row.edge = row:CreateTexture(nil, "BACKGROUND")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetPoint("BOTTOMRIGHT")
	row.edge:SetHeight(1)
	UI.Paint(row.edge, C.rowEdge, 0.55)
	row.hot = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.row, 0.9)
	row.hot:Hide()
	row.name = UI.Text(row, "", 11, false, C.text)
	row.name:SetPoint("LEFT", 10, 0)
	row.name:SetWidth(C0 - 10)
	row.name:SetWordWrap(false)
	row.note = UI.Text(row, "", 10, false, C.dim)
	row.note:SetPoint("LEFT", row.name, "RIGHT", 0, 0)
	row.note:Hide()
	row.flag = UI.Text(row, "", 11, false, C.alert)
	row.flag:SetPoint("LEFT", C0 + CW * 4 + 12, 0)
	row.flag:SetPoint("RIGHT", -4, 0)
	row.flag:SetWordWrap(false)
	row:SetScript("OnEnter", function(self) if self.hover then self.hot:Show() end end)
	row:SetScript("OnLeave", function(self) self.hot:Hide() end)
end

local function MakeClock(row)
	MakeRow(row)
	Number(row, "calls", C0, CW)
	UI.Ink(row.calls, C.dim)
	Number(row, "ms", C0 + CW, CW)
	Number(row, "worst", C0 + CW * 2, CW)
	UI.Ink(row.worst, C.dim)
	Number(row, "kb", C0 + CW * 3, CW)
	row.hover = true
	row:SetScript("OnClick", function(self)
		if self.clock and W.Views().clock then W.Open("clock", self.clock) end
	end)
end

local function MakeMemory(row)
	MakeRow(row)
	Number(row, "size", C0, 180)
	Number(row, "freed", C0 + 180, 110)
	UI.Ink(row.freed, C.dim)
	row.button = UI.Button(row, "", 54, function(self)
		local r = self:GetParent()
		if r.cache then
			M.Empty(r.cache)
		elseif r.keep then
			M.WeighAddon(addon)
		end
		view.refresh()
	end)
	row.button:SetHeight(18)
	row.button:SetPoint("RIGHT", -4, 0)
	row.button.text:SetFontObject(UI.NameFont(10))
end

local function MakeCounter(row)
	MakeRow(row)
	Number(row, "value", C0, 180)
	row.still = UI.Text(row, "", 10, false, C.dim)
	row.still:SetPoint("RIGHT", row, "LEFT", C0 + 290, 0)
	row.still:SetJustifyH("RIGHT")
end

local function MakeError(row)
	MakeRow(row)
	row.name:SetWidth(400)
	Number(row, "count", 400, 100)
	Number(row, "ago", 500, 120)
	UI.Ink(row.ago, C.dim)
	row.hover = true
	row:SetScript("OnClick", function(self)
		if self.key and Shy.Errors then
			Shy.Errors.Read(self.key)
			if W.Views().errors then W.Open("errors", self.key) else Shy.Errors.Open() end
		end
	end)
end

local function Section(title, em)
	local row = pools.section:Get()
	ns.Text(row.text, title)
	ns.Text(row.em, em or "")
	Place(row, SEC)
	y = y + 2
end

local function Ago(seconds)
	if seconds < 60 then return format("%d s ago", seconds) end
	if seconds < 3600 then return format("%d min ago", seconds / 60) end
	return format("%.1f h ago", seconds / 3600)
end

-- Work: the addon's clocks by group, the costliest group first, the costliest clock first in it.
local function Clocks()
	local n = 0
	for g in pairs(groupMs) do groupMs[g] = 0 end
	for name, clock in pairs(Shy.Clocks()) do
		if clock.addon == addon and (clock.calls > 0 or clock.ms > 0) then
			n = n + 1
			clocksOf[n] = clock
			groupMs[clock.group] = (groupMs[clock.group] or 0) + clock.ms
		end
	end
	for i = #clocksOf, n + 1, -1 do clocksOf[i] = nil end
	table.sort(clocksOf, function(a, b)
		local ga, gb = groupMs[a.group], groupMs[b.group]
		if ga ~= gb then return ga > gb end
		if a.group ~= b.group then return a.group < b.group end
		if a.ms ~= b.ms then return a.ms > b.ms end
		return a.name < b.name
	end)
	return n
end

local function Work(seconds)
	local n = Clocks()
	if n == 0 then return end
	local total = 0
	for _, ms in pairs(groupMs) do total = total + ms end
	local sum = pools.section:Get()
	ns.Text(sum.text, "Work")
	ns.Num(sum.em, total / seconds, "%.2f ms a second", 100)
	Place(sum, SEC)
	y = y + 2
	local group
	local last = nil
	for i = 1, n do
		local clock = clocksOf[i]
		if clock.group ~= last then
			last = clock.group
			group = pools.group:Get()
			ns.Text(group.text, clock.group:upper())
			ns.Num(group.em, groupMs[clock.group] / seconds, "%.2f ms/s", 100)
			Place(group, GROUP)
		end
		local row = pools.clock:Get()
		row.clock = clock.name
		ns.Text(row.name, clock.name)
		local entered = clock.name:find("\226\134\146", 1, true) and "entered by ShyCore" or nil
		ns.Shown(row.note, entered ~= nil)
		if entered then ns.Text(row.note, "   " .. entered) end
		if clock.calls > 0 then
			ns.Num(row.calls, clock.calls / seconds, "%.1f", 10)
			ns.Num(row.ms, clock.ms / seconds, "%.2f", 100)
			ns.Num(row.worst, clock.most, "%.1f ms", 10)
			local runs = clock.calls - clock.collected
			ns.Num(row.kb, runs > 0 and clock.kb / runs or 0, "%.1f", 10)
		else
			ns.Text(row.calls, "")
			ns.Text(row.ms, "idle")
			ns.Text(row.worst, "")
			ns.Text(row.kb, "")
		end
		local flagged = M.idleFlags[addon] and M.idleFlags[addon][clock.name]
		ns.Text(row.flag, flagged and "works while standing still" or "")
		Place(row, ROW)
	end
	y = y + 6
end

local function Memory()
	local caches, kept = Shy.Memory.Caches(), Shy.Memory.Kept()
	local any = false
	for _, cache in ipairs(caches) do if cache.addon == addon then any = true break end end
	if not any then for _, keep in ipairs(kept) do if keep.addon == addon then any = true break end end end
	if not any then return end
	local a = S.by[addon]
	local held = M.kept[addon]
	local sum = pools.section:Get()
	ns.Text(sum.text, "Memory")
	local key = (a and a.inUse or 0) * 1000 + (held or 0)
	if sum.em.shyKey ~= key then
		sum.em.shyKey = key
		sum.em:SetText(held and format("%.1f MB in use, %.1f held", (a and a.inUse or 0) / 1024, held / 1024)
			or format("%.1f MB in use", (a and a.inUse or 0) / 1024))
	end
	Place(sum, SEC)
	y = y + 2
	for _, cache in ipairs(caches) do
		if cache.addon == addon then
			local row = pools.memory:Get()
			row.cache, row.keep = cache, nil
			ns.Text(row.name, cache.name)
			if cache.size then
				local ok, size = pcall(cache.size)
				ns.Num(row.size, ok and tonumber(size) or 0, "%d", 1)
			else
				ns.Text(row.size, "")
			end
			local freed = M.freed[cache]
			if freed then ns.Num(row.freed, freed / 1024, "%.1f MB freed", 10) else ns.Text(row.freed, "") end
			row.button:SetLabel("Empty")
			local flagged = M.cacheFlags[cache]
			ns.Text(row.flag, flagged or "")
			Place(row, ROW)
		end
	end
	local weighed = M.weighed[addon]
	for _, keep in ipairs(kept) do
		if keep.addon == addon then
			local row = pools.memory:Get()
			row.cache, row.keep = nil, keep
			ns.Text(row.name, keep.name)
			local found
			if weighed then
				for _, w in ipairs(weighed) do if w.name == keep.name then found = w end end
			end
			if found then
				local k = found.entries * 100000 + found.tables
				if row.size.shyKey ~= k then
					row.size.shyKey = k
					row.size:SetText(format("%d entries, %d tables", found.entries, found.tables))
				end
			else
				ns.Text(row.size, "")
			end
			ns.Text(row.freed, "")
			row.button:SetLabel("Weigh")
			ns.Text(row.flag, "")
			Place(row, ROW)
		end
	end
	y = y + 6
end

local function CounterRow(label, value, mark, limit)
	local row = pools.counter:Get()
	ns.Text(row.name, label)
	if type(value) == "number" then
		if mark == "of" and limit then
			local k = value * 1000003 + limit
			if row.value.shyKey ~= k then
				row.value.shyKey = k
				row.value:SetText(format("%d of %d", value, limit))
			end
		else
			ns.Num(row.value, value, value % 1 == 0 and "%d" or "%.2f", 100)
		end
	else
		ns.Text(row.value, tostring(value))
	end
	local flagged = mark == "idle" and M.idleFlags[addon] and M.idleFlags[addon][label]
	ns.Text(row.still, mark == "idle" and not flagged and "still" or "")
	ns.Text(row.flag, flagged and "moved while standing still" or "")
	Place(row, ROW)
end

local function Counters()
	for _, set in ipairs(Shy.CounterSets()) do
		if set.addon == addon then
			Section(set.title, "counters")
			local ok, err = pcall(set.rows, CounterRow)
			if not ok then geterrorhandler()(err) end
			y = y + 6
		end
	end
end

local function Errors()
	local E = Shy.Errors
	if not E then return end
	local n, times = 0, 0
	for _, entry in ipairs(E.List()) do
		if entry.addon == addon then n, times = n + 1, times + (entry.count or 1) end
	end
	if n == 0 then return end
	local sum = pools.section:Get()
	ns.Text(sum.text, "Errors")
	local k = n * 100000 + times
	if sum.em.shyKey ~= k then
		sum.em.shyKey = k
		sum.em:SetText(format("%d %s, %d times", n, n == 1 and "entry" or "entries", times))
	end
	Place(sum, SEC)
	y = y + 2
	local now = GetServerTime and GetServerTime() or 0
	for _, entry in ipairs(E.Sorted()) do
		if entry.addon == addon then
			local row = pools.error:Get()
			row.key = entry.key
			ns.Text(row.name, tostring(entry.message or ""):match("^[^\n]*"))
			ns.Num(row.count, entry.count or 1, "\195\151%d", 1)
			local ago = entry.last and max(0, now - entry.last) or 0
			local k2 = math.floor(ago / 60)
			if row.ago.shyKey ~= k2 then
				row.ago.shyKey = k2
				row.ago:SetText(Ago(ago))
			end
			ns.Text(row.flag, "")
			Place(row, ROW)
		end
	end
end

function view.build(frame)
	card = CreateFrame("Frame", nil, frame)
	UI.Skin(card, C.bg, C.border)
	card:SetPoint("TOPLEFT")
	card:SetPoint("TOPRIGHT")
	card:SetHeight(cardHeight)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(34, 34)
	card.name = UI.Text(card, "", 20, true)
	card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 4)
	card.version = UI.Text(card, "", 11, false, C.dim)
	card.version:SetPoint("BOTTOMLEFT", card.name, "BOTTOMRIGHT", 8, 2)
	card.line = UI.Text(card, "", 11, false, C.dim)
	card.line:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 10, -2)
	card.line:SetWordWrap(false)
	-- Under the name, where the stats take a row of their own.
	card.rule = card:CreateTexture(nil, "ARTWORK")
	card.rule:SetHeight(1)
	UI.Paint(card.rule, C.border, 0.8)
	card.stats = {}
	for i = 1, STATS do
		local st = CreateFrame("Frame", nil, card)
		st:SetSize(STAT_W, STAT_H)
		st.rule = st:CreateTexture(nil, "ARTWORK")
		st.rule:SetPoint("TOPLEFT", 0, 2)
		st.rule:SetPoint("BOTTOMLEFT", 0, -2)
		st.rule:SetWidth(1)
		UI.Paint(st.rule, C.border, 0.8)
		st.k = st:CreateFontString(nil, "OVERLAY")
		st.k:SetFontObject(UI.NameFont(10))
		UI.Ink(st.k, C.dim)
		st.k:SetPoint("TOPLEFT", STAT_IN, 0)
		st.v = st:CreateFontString(nil, "OVERLAY")
		st.v:SetFontObject(UI.NameFont(15))
		UI.Ink(st.v, C.text)
		st.v:SetPoint("TOPLEFT", STAT_IN, -15)
		st.v:SetJustifyH("LEFT")
		st.v:SetWordWrap(false)
		st.w = st:CreateFontString(nil, "OVERLAY")
		st.w:SetFontObject(UI.NameFont(10))
		UI.Ink(st.w, C.dim)
		st.w:SetPoint("TOPLEFT", STAT_IN, -35)
		st.w:SetJustifyH("LEFT")
		st.w:SetWordWrap(false)
		card.stats[i] = st
	end
	for i, k in ipairs({ "SHARE", "FRAME", "OVER 5 MS", "MEMORY", "CHURN" }) do card.stats[i].k:SetText(k) end

	scroll = UI.ScrollArea(frame, 100, 100)
	scroll:SetPoint("TOPLEFT", 0, -cardHeight - 8)
	content = scroll.content
	-- The addon over time: its frame share the last two minutes, its memory the last ten.
	lines = { ms = ns.Spark(content, BARS, Theme.Accent, "Milliseconds a frame, the last two minutes"),
		mem = ns.Spark(content, BARS, C.dim, "Memory in use, the last ten minutes") }
	empty = UI.Text(content, "", 12, false, C.dim)
	empty:SetWordWrap(true)
	empty:SetJustifyH("LEFT")
	pools.section = Pool(MakeSection)
	pools.group = Pool(MakeGroup)
	pools.clock = Pool(MakeClock)
	pools.memory = Pool(MakeMemory)
	pools.counter = Pool(MakeCounter)
	pools.error = Pool(MakeError)
end

-- The stats stand in one row: right of the name where all five fit at STAT_W, else across the card under
-- it. Each is ruled off at its left (but the first under the name), its words in line with the rest.
function view.lay(w, h)
	local beside = (w - NAME_W - IN) / STATS
	local wide = beside >= STAT_W
	local x0, top, sw
	if wide then
		x0, top, sw = NAME_W, -13, beside
		card.icon:SetPoint("TOPLEFT", IN, -19)
		cardHeight = 13 + STAT_H + 13
	else
		x0, top, sw = IN - STAT_IN, -71, (w - IN * 2 + STAT_IN) / STATS
		card.icon:SetPoint("TOPLEFT", IN, -13)
		card.rule:SetPoint("TOPLEFT", IN, -59)
		card.rule:SetPoint("TOPRIGHT", -IN, -59)
		cardHeight = 71 + STAT_H + 12
	end
	card.rule:SetShown(not wide)
	card.line:SetWidth((wide and NAME_W or w) - IN - 34 - 10 - IN)
	for i, st in ipairs(card.stats) do
		st:ClearAllPoints()
		st:SetPoint("TOPLEFT", x0 + (i - 1) * sw, top)
		st:SetSize(sw, STAT_H)
		st.rule:SetShown(wide or i > 1)
		st.v:SetWidth(sw - STAT_IN - 6)
		st.w:SetWidth(sw - STAT_IN - 6)
	end
	card:SetHeight(cardHeight)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", 0, -cardHeight - 8)
	scroll:SetSize(w, h - cardHeight - 8)
	content:SetWidth(w - 14)
	local half = (w - 14 - 8) / 2
	lines.ms:Lay(half, LINES)
	lines.mem:Lay(half, LINES)
	empty:SetWidth(w - 40)
end

function view.show(name)
	addon = name
	local a
	for _, each in ipairs(Shy.order) do if each.name == name then a = each end end
	Theme.Icon(card.icon, ns.IconOf(name, true))
	card.icon:Show()
	if a then
		UI.Themed(card.name, function() return B.Name(a.suffix) end)
		card.version:SetText(a.version and ("v" .. a.version) or "")
		card.line:SetText(a.tagline or "")
	else
		local suffix = name:match("^Shy(.*)$") or name
		UI.Themed(card.name, function() return B.Name(suffix) end)
		card.version:SetText(C_AddOns.GetAddOnMetadata(name, "Version") and ("v" .. C_AddOns.GetAddOnMetadata(name, "Version")) or "")
		local s = S.by[name]
		card.line:SetText(s and s.data and "data, loaded while you are there" or "")
	end
	for _, st in ipairs(card.stats) do
		st.v.shyKey, st.w.shyText, st.v.shyText = nil, nil, nil
	end
end

local function Card(seconds)
	local a = S.by[addon]
	if not a then return end
	local st = card.stats
	if a.data or S.off then
		for i = 1, 3 do
			ns.Text(st[i].v, i == 1 and (S.off and "off" or "data") or "")
			ns.Text(st[i].w, "")
		end
	else
		ns.Num(st[1].v, a.share, "%.1f%%", 10)
		ns.Text(st[1].w, "of the frame now")
		ns.Num(st[2].v, a.now, "%.2f ms", 100)
		local k = math.floor(a.avg * 100) * 10000 + math.floor(a.peak)
		if st[2].w.shyKey ~= k then
			st[2].w.shyKey = k
			st[2].w:SetText(format("avg %.2f, peak %.0f", a.avg, a.peak))
		end
		ns.Num(st[3].v, a.over5, "%d frames", 1)
		local k3 = a.over50 * 10000 + a.over100
		if st[3].w.shyKey ~= k3 then
			st[3].w.shyKey = k3
			st[3].w:SetText(a.over100 > 0 and format("%d over 50, %d over 100", a.over50, a.over100) or format("%d over 50 ms", a.over50))
		end
	end
	local held = M.kept[addon]
	ns.Num(st[4].v, a.inUse / 1024, "%.1f MB", 10)
	-- Words or a number in one place: each way forgets what the other last wrote.
	local caption = st[4].w
	if held and not M.flags[addon] then
		caption.shyText = nil
		ns.Num(caption, held / 1024, "%.1f MB held", 10)
	else
		caption.shyKey = nil
		ns.Text(caption, M.flags[addon] or "in use")
	end
	local churn = M.churnBy[addon]
	if churn then
		ns.Num(st[5].v, churn, "%.0f KB/s", 1)
		ns.Text(st[5].w, "over ten seconds")
	else
		local kb = 0
		for _, clock in pairs(Shy.Clocks()) do
			if clock.addon == addon then kb = kb + clock.kb end
		end
		ns.Num(st[5].v, kb / seconds, "%.0f KB/s", 1)
		ns.Text(st[5].w, "from its clocks")
	end
end

-- The addon over time, at the top of the body: two lines side by side.
local function OverTime()
	local a = S.by[addon]
	if not a then return end
	local row = pools.section:Get()
	ns.Text(row.text, "Over time")
	ns.Text(row.em, "")
	Place(row, SEC)
	y = y + 4
	ns.At(lines.ms, 0, y)
	ns.At(lines.mem, lines.ms:GetWidth() + 8, y)
	ns.Shown(lines.ms, true)
	ns.Shown(lines.mem, true)
	lines.ms:Draw(a.msRing, 2)
	ns.Num(lines.ms.note, a.msRing:Max(), "up to %.2f ms", 100)
	lines.mem:Draw(a.memRing, 2)
	ns.Num(lines.mem.note, a.memRing:Max() / 1024, "up to %.1f MB", 10)
	y = y + LINES + 8
end

local seconds = 1
function view.refresh()
	if not addon then return end
	seconds = max(1, GetTime() - Shy.ClocksSince())
	Card(seconds)
	y = 0
	for _, pool in pairs(pools) do pool.used = 0 end
	OverTime()
	local before = y
	Work(seconds)
	Memory()
	Counters()
	Errors()
	-- Nothing registered: say so, where the sections would be.
	local none = y == before
	ns.Shown(empty, none)
	if none then
		ns.At(empty, 2, y + 6)
		local a = S.by[addon]
		ns.Text(empty, a and a.data and "A data addon: it does no work of its own."
			or "No clocks, counters or caches registered: its cost is the game's count above.")
		y = y + 44
	end
	for _, pool in pairs(pools) do pool:Trim() end
	if ns.Height(content, y + 4) then scroll:Update() end
end

function view.title(name)
	return name or "Addon"
end

-- Its crumb's caret: the addon's clocks, by name.
function view.kids(name)
	local kids = {}
	for key, clock in pairs(Shy.Clocks()) do
		if clock.addon == name then kids[#kids + 1] = { text = key, view = "clock", key = key } end
	end
	table.sort(kids, function(a, b) return a.text < b.text end)
	return kids
end

function view.copy()
	return ns.Copy.Addon(addon)
end

-- For the tests: the card and the row pools.
function view.Pieces()
	return card, pools, addon
end

W.View("addon", view)
