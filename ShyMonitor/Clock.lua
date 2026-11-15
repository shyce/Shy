-- One clock: the number as a sentence, its last minute as two lines (ms a second, KB a second), and
-- Measure: its next twenty runs through the game's own exact measure (time, bytes made and freed per run,
-- a clean-up inside a run can't fool it). Then what the game charged the addon with, beside it.

local _, ns = ...
local UI, C, Theme = Shy.UI, Shy.UI.colors, Shy.Theme
local S, W, Ring = ns.Samples, ns.Window, ns.Ring
local format, max, min = string.format, math.max, math.min

local RUNS = 20     -- runs a measure takes
local BARS = 60     -- a line's bars: the last minute, a second each
local FACTS = 6

local view = {}
local name, clock
local sentence, where, facts, lines, measured, charged
local ring = { ms = Ring.New(BARS), kb = Ring.New(BARS) }
local lastMs, lastKb, lastAt = 0, 0, 0
local results = {}

local function Spark(parent, title, color)
	return ns.Spark(parent, BARS, color, title)
end

local function Fact(parent, i)
	local f = CreateFrame("Frame", nil, parent)
	f:SetPoint("TOPLEFT", 2 + 150 * (i - 1), -36)
	f:SetSize(146, 36)
	f.v = f:CreateFontString(nil, "OVERLAY")
	f.v:SetFontObject(UI.NameFont(15))
	UI.Ink(f.v, C.text)
	f.v:SetPoint("TOPLEFT")
	f.k = UI.Text(f, "", 10, false, C.dim)
	f.k:SetPoint("TOPLEFT", 0, -20)
	f.k:SetWidth(146)
	f.k:SetWordWrap(false)
	return f
end

local function Line(parent, i, label)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(20)
	row:SetPoint("TOPLEFT", 0, -22 - 20 * (i - 1))
	row:SetPoint("RIGHT")
	row.edge = row:CreateTexture(nil, "BACKGROUND")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetPoint("BOTTOMRIGHT")
	row.edge:SetHeight(1)
	UI.Paint(row.edge, C.rowEdge, 0.55)
	row.name = UI.Text(row, label, 11, false, C.text)
	row.name:SetPoint("LEFT", 10, 0)
	row.cells = {}
	for j = 1, 3 do
		local fs = row:CreateFontString(nil, "OVERLAY")
		fs:SetFontObject(UI.NameFont(11))
		UI.Ink(fs, C.text)
		fs:SetPoint("RIGHT", row, "LEFT", 160 + 100 * j, 0)
		fs:SetWidth(100)
		fs:SetJustifyH("RIGHT")
		row.cells[j] = fs
	end
	return row
end

function view.build(frame)
	sentence = UI.Text(frame, "", 17, true)
	sentence:SetPoint("TOPLEFT", 2, -4)
	sentence:SetWordWrap(false)
	where = UI.Text(frame, "", 11, false, C.dim)
	where:SetPoint("BOTTOMLEFT", sentence, "BOTTOMRIGHT", 10, 1)
	where:SetWordWrap(false)
	facts = {}
	for i = 1, FACTS do facts[i] = Fact(frame, i) end
	for i, k in ipairs({ "runs", "a second", "a run", "worst", "made a run", "clean-ups seen" }) do facts[i].k:SetText(k) end
	lines = { ms = Spark(frame, "Milliseconds a second", Theme.Accent), kb = Spark(frame, "KB made a second", C.dim) }
	lines.ms:SetPoint("TOPLEFT", 0, -84)
	lines.kb:SetPoint("TOPRIGHT", 0, -84)

	measured = CreateFrame("Frame", nil, frame)
	measured:SetPoint("TOPLEFT", 0, -208)
	measured:SetPoint("RIGHT")
	measured:SetHeight(140)
	measured.title = UI.Text(measured, "Measured, the last 20 runs", 13, true, C.head)
	measured.title:SetPoint("TOPLEFT", 0, -4)
	measured.em = measured:CreateFontString(nil, "OVERLAY")
	measured.em:SetFontObject(UI.NameFont(11))
	UI.Ink(measured.em, C.dim)
	measured.em:SetPoint("RIGHT", measured, "TOPRIGHT", -96, -12)
	measured.line = measured:CreateTexture(nil, "ARTWORK")
	measured.line:SetPoint("TOPLEFT", 0, -22)
	measured.line:SetPoint("TOPRIGHT", 0, -22)
	measured.line:SetHeight(1)
	UI.Paint(measured.line, C.border, 0.9)
	measured.button = UI.Button(measured, "Measure", 84, function()
		if InCombatLockdown() then return end
		for i = #results, 1, -1 do results[i] = nil end
		measured.running = Shy.ClockMeasure(name, RUNS, function(list)
			for i, r in ipairs(list) do results[i] = r end
			measured.running = false
			view.refresh()
		end)
		view.refresh()
	end)
	measured.button:SetHeight(22)
	measured.button:SetPoint("TOPRIGHT", 0, -1)
	UI.Help(measured.button, "Measure", "Times its next twenty runs exactly with the game's own profiler: time, memory made and freed.")
	measured.head = {}
	for j, k in ipairs({ "LEAST", "MEAN", "WORST" }) do
		local fs = UI.Text(measured, k, 10, false, C.dim)
		fs:SetPoint("RIGHT", measured, "TOPLEFT", 160 + 100 * j, -34)
		measured.head[j] = fs
	end
	measured.rows = { Line(measured, 2, "Time a run"), Line(measured, 3, "Memory made a run"), Line(measured, 4, "Memory freed a run") }
	measured.note = UI.Text(measured, "", 11, false, C.dim)
	measured.note:SetPoint("TOPLEFT", 2, -106)
	measured.note:SetPoint("RIGHT")
	measured.note:SetWordWrap(true)

	charged = CreateFrame("Frame", nil, frame)
	charged:SetPoint("TOPLEFT", 0, -356)
	charged:SetPoint("RIGHT")
	charged:SetHeight(50)
	charged.title = UI.Text(charged, "Charged", 13, true, C.head)
	charged.title:SetPoint("TOPLEFT", 0, -4)
	charged.em = UI.Text(charged, "where the game put it", 11, false, C.dim)
	charged.em:SetPoint("TOPRIGHT", -4, -6)
	charged.line = charged:CreateTexture(nil, "ARTWORK")
	charged.line:SetPoint("TOPLEFT", 0, -22)
	charged.line:SetPoint("TOPRIGHT", 0, -22)
	charged.line:SetHeight(1)
	UI.Paint(charged.line, C.border, 0.9)
	charged.text = UI.Text(charged, "", 11, false, C.text)
	charged.text:SetPoint("TOPLEFT", 10, -28)
	charged.text:SetPoint("RIGHT")
	charged.text:SetWordWrap(false)
end

function view.lay(w)
	local half = (w - 8) / 2
	lines.ms:Lay(half, 112)
	lines.kb:Lay(half, 112)
end

function view.show(key)
	name = key
	clock = Shy.Clocks()[key]
	for i = #results, 1, -1 do results[i] = nil end
	ring.ms:Clear()
	ring.kb:Clear()
	lastMs, lastKb, lastAt = clock and clock.ms or 0, clock and clock.kb or 0, GetTime()
	sentence:SetText(key)
	where:SetText(clock and format("%s%s · %s%s", clock.addon, clock.where and ("/" .. clock.where) or "", clock.group,
		key:find("\226\134\146", 1, true) and " · entered by ShyCore" or "") or "")
	measured.note.shyText = nil
	measured.button:SetUsable(Shy.ClockMeasurable(key), "This one is timed by hand, so there's nothing to measure run by run.")
end

local function Stats(key)
	local least, most, sum, n = math.huge, 0, 0, #results
	for _, r in ipairs(results) do
		local v = r[key] or 0
		least, most, sum = min(least, v), max(most, v), sum + v
	end
	if n == 0 then return 0, 0, 0 end
	return least, sum / n, most
end

local function Measured()
	local n = #results
	if measured.running then
		ns.Text(measured.em, "measuring")
	elseif n > 0 then
		ns.Num(measured.em, n, "%d runs, exact", 1)
	else
		ns.Text(measured.em, "nothing measured yet")
	end
	for j = 1, 3 do ns.Shown(measured.head[j], n > 0) end
	for _, row in ipairs(measured.rows) do ns.Shown(row, n > 0) end
	if n == 0 then
		ns.Text(measured.note, "")
		return
	end
	local a, b, c = Stats("elapsedMilliseconds")
	ns.Num(measured.rows[1].cells[1], a, "%.2f ms", 100)
	ns.Num(measured.rows[1].cells[2], b, "%.2f ms", 100)
	ns.Num(measured.rows[1].cells[3], c, "%.2f ms", 100)
	local d, e, f = Stats("allocatedBytes")
	ns.Num(measured.rows[2].cells[1], d, "%.0f bytes", 1)
	ns.Num(measured.rows[2].cells[2], e, "%.0f bytes", 1)
	ns.Num(measured.rows[2].cells[3], f, "%.0f bytes", 1)
	local g, h, i = Stats("deallocatedBytes")
	ns.Num(measured.rows[3].cells[1], g, "%.0f bytes", 1)
	ns.Num(measured.rows[3].cells[2], h, "%.0f bytes", 1)
	ns.Num(measured.rows[3].cells[3], i, "%.0f bytes", 1)
	local calls = clock and clock.calls or 0
	local seconds = max(1, GetTime() - Shy.ClocksSince())
	local perSecond = calls / seconds
	local key = math.floor(e) * 1000 + math.floor(perSecond)
	if measured.note.shyKey ~= key then
		measured.note.shyKey = key
		if e < 64 then
			measured.note:SetText("A run makes next to nothing: whatever it builds is reused.")
		elseif d == f and d > 0 then
			measured.note:SetText(format("Every run makes the same %.0f bytes: something is built new each time, not reused. At %.0f runs a second that is %.1f MB a minute for the game's clean-up to take back.",
				d, perSecond, d * perSecond * 60 / 1048576))
		else
			measured.note:SetText(format("A run makes about %.0f bytes. At %.0f runs a second that is %.1f MB a minute for the game's clean-up to take back.",
				e, perSecond, e * perSecond * 60 / 1048576))
		end
	end
end

function view.refresh()
	if not clock then return end
	local now = GetTime()
	local seconds = max(1, now - Shy.ClocksSince())
	if now - lastAt >= 1 then
		ring.ms:Push((clock.ms - lastMs) / (now - lastAt))
		ring.kb:Push((clock.kb - lastKb) / (now - lastAt))
		lastMs, lastKb, lastAt = clock.ms, clock.kb, now
	end
	ns.Num(facts[1].v, clock.calls, "%d", 1)
	ns.Num(facts[2].v, clock.calls / seconds, "%.1f", 10)
	ns.Num(facts[3].v, clock.calls > 0 and clock.ms / clock.calls or 0, "%.2f ms", 100)
	ns.Num(facts[4].v, clock.most, "%.1f ms", 10)
	local ago = clock.mostAt > 0 and (now - clock.mostAt) or nil
	local k = ago and math.floor(ago / 30) or -1
	if facts[4].k.shyKey ~= k then
		facts[4].k.shyKey = k
		facts[4].k:SetText(ago and (ago < 60 and format("worst, %.0f s ago", ago) or format("worst, %.0f min ago", ago / 60)) or "worst")
	end
	local runs = clock.calls - clock.collected
	ns.Num(facts[5].v, runs > 0 and clock.kb / runs or 0, "%.1f KB", 10)
	ns.Num(facts[6].v, clock.collected, "%d", 1)
	lines.ms:Draw(ring.ms)
	ns.Num(lines.ms.note, clock.ms / seconds, "%.2f ms/s over all", 100)
	lines.kb:Draw(ring.kb)
	local kbs = clock.kb / seconds
	ns.Num(lines.kb.note, kbs, "%.0f KB/s", 1)
	Measured()
	local a = S.by[clock.addon]
	local fps = GetFramerate and GetFramerate() or 60
	local perFrame = fps > 0 and (clock.ms / seconds) / fps or 0
	local key = math.floor(perFrame * 1000) * 1000 + math.floor((a and a.now or 0) * 100)
	if charged.text.shyKey ~= key then
		charged.text.shyKey = key
		charged.text:SetText(a and not a.data and format("%s, a frame now: %.2f ms. This clock is %.3f ms of every frame.", clock.addon, a.now, perFrame)
			or format("This clock is %.3f ms of every frame.", perFrame))
	end
end

function view.under(key)
	local c = Shy.Clocks()[key]
	return "addon", c and c.addon or nil
end

function view.title(key)
	return key or "Clock"
end

function view.copy()
	return ns.Copy.Clock(name, results)
end

-- For the tests.
function view.Pieces()
	return facts, measured, results, charged, lines
end

W.View("clock", view)
