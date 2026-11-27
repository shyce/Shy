-- The game's mirror timers (breath under water, fatigue too far out, feign death) as the column's own bars,
-- first in the drawer under the head at the top's middle: nothing up there is more urgent. Each is a cell of
-- the column's tray (Shy.Top.Make.Cell), a quest objective's make: its sign on its tab, the cell itself the
-- meter, its weave draining as it runs out, its name and the time left, every one the same length so the
-- drain reads at a glance. The game's bars still run; their pieces are faded.
--
--   ns.Timers.Sample(parent)   -- the piece as a picture (layout mode, the screen's preview)
--   ns.Timers.Live()           -- what is up: { { timer, label, share, left, paused }, ... } in the order shown

local ADDON, ns = ...
local UI, Theme, HUD = Shy.UI, Shy.Theme, Shy.HUD
local C = UI.colors
local MEDIA = Shy.MEDIA

local Tm = {}
ns.Timers = Tm

local WIDTH = 230               -- the narrowest its cells stand
local CLOCK = 30                -- room kept at a cell's right for the time left, whatever it counts
local CELL = Shy.Top.Make.CELL
local ROW, RULE = CELL.ROW, CELL.RULE
-- Each timer's place, color and sign: a picture of ours (`file`, 24 texels) or one of the hover's glyphs.
local KINDS = {
	BREATH = { order = 1, color = { 0.50, 0.82, 1.00 }, file = MEDIA .. "GlyphBreath" },
	EXHAUSTION = { order = 2, color = { 1.00, 0.70, 0.30 }, glyph = "clock" },
	FEIGNDEATH = { order = 3, color = { 0.62, 0.90, 0.72 }, glyph = "note" },
	DEATH = { order = 4, color = { 0.80, 0.82, 0.88 }, glyph = "home" },
}
local OTHER = { order = 5, color = { 0.80, 0.82, 0.88 }, glyph = "clock" }
local SAMPLE = { { "BREATH", "Breath", 0.62, 37 }, { "EXHAUSTION", "Fatigue", 0.24, 14 } }

local box, tray
local active = {}       -- timer -> { label, max, paused, spell }
local rows = {}         -- the bars, made as needed
local live = {}         -- the timers shown, in order
local failed

local function Plain(v)
	if v == nil or issecretvalue(v) then return nil end
	return v
end

local function Clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- A bar: a cell whose meter drains in the timer's color. Returns the width its words need.
local function Dress(r, timer, label)
	local kind = KINDS[timer] or OTHER
	r.drawn = nil   -- (dressed anew: drawn whole the next time)
	return r:Set({ sign = kind.glyph, file = kind.file, color = kind.color, name = label or "", right = r.clock or "",
		room = CLOCK, fill = kind.color }) or WIDTH
end

-- A bar as it stands now. It is drawn at every frame: its meter is told when it has moved a STEPS share of the
-- bar (under a pixel), its clock when the second changes, its pause when it changes.
local STEPS = 4096
local function Draw(r, share, left, paused)
	r.share = math.max(0, math.min(1, share))
	local drawn = r.drawn
	if not drawn then
		drawn = {}
		r.drawn = drawn
	end
	local step = math.floor(r.share * STEPS + 0.5)
	if step ~= drawn.step then
		drawn.step = step
		r:Share(r.share)
	end
	local seconds = left and math.max(0, math.ceil(left)) or -1
	if seconds ~= drawn.seconds then
		drawn.seconds = seconds
		r.clock = left and Clock(left) or ""
		r.right:SetText(r.clock)
	end
	paused = paused and true or false
	if paused ~= drawn.paused then
		drawn.paused = paused
		r:Dim(paused)
	end
end

function Tm.Sample(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(WIDTH, #SAMPLE * ROW + (#SAMPLE - 1) * RULE)
	f:EnableMouse(false)
	if not Shy.Top.Make then return f end
	local cells = {}
	for i, s in ipairs(SAMPLE) do
		local r = Shy.Top.Make.Cell(f)
		Dress(r, s[1], s[2])
		Draw(r, s[3], s[4])
		cells[i] = r
	end
	return Shy.Top.Make.Still(f, WIDTH, cells)
end

-- The bars on screen

local function Slot(i) return (i - 1) * (ROW + RULE) end

-- The bars stood in the tray: each the tray's width, one right on the next. Every one wears the hairline along its
-- top but the first of a tray standing by itself, which stands under its own border.
local need = WIDTH      -- the width the bars' words need
local function Lay()
	local n = #live
	local width, inset = tray:Fit(need, n > 0 and Slot(n) + ROW or 0)
	local hung = Shy.Top.Hung(box)
	for i, r in ipairs(rows) do
		if i <= n then
			r:SetWidth(width)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -(inset + Slot(i)))
			r:Rule(hung or i > 1)
			r:SetAlpha(1)
			r:Show()
		else
			r:Hide()
		end
	end
end

-- The timers up, in their order, a bar each; the box hugs them, and the column closes up under it.
-- One the alert takes up (Shy.Alarm.Covers: it says it now, in the head or under your character) goes as the
-- head becomes the alert: it fades where it stands, FOLD seconds, and the rest close up.
local FOLD = 0.2
local folding = {}      -- a bar the alert took -> { at }
local function Arrange()
	local was = {}
	for i, timer in ipairs(live) do was[timer] = i end
	wipe(live)
	for timer in pairs(active) do
		if not Shy.Alarm.Covers(timer) then live[#live + 1] = timer end
	end
	table.sort(live, function(a, b) return (KINDS[a] or OTHER).order < (KINDS[b] or OTHER).order end)
	-- Layout mode with nothing running: what it would show, so the drawer stands there as it does in play.
	local sample = #live == 0 and HUD.IsUnlocked()
	if sample then
		for _, s in ipairs(SAMPLE) do live[#live + 1] = s[1] end
	end
	-- (A bar the alert took is taken out of the rows while it fades, and back among them once it has.)
	for timer, i in pairs(was) do
		if Shy.Alarm.Covers(timer) and active[timer] then
			folding[rows[i]] = { at = GetTime() }
			rows[i] = false
		end
	end
	for i = #rows, 1, -1 do
		if rows[i] == false then table.remove(rows, i) end
	end
	need = WIDTH
	for i, timer in ipairs(live) do
		local r = rows[i]
		if not r then
			r = Shy.Top.Make.Cell(box)
			rows[i] = r
		end
		local s = sample and SAMPLE[i]
		need = math.max(need, Dress(r, timer, s and s[2] or active[timer].label))
		if s then Draw(r, s[3], s[4]) end
		r.timer = timer
	end
	Lay()
	HUD.Update(box)
	Shy.Top.Apply()
end

-- The bars the alert took: fading, then put back among the rows, unseen.
local function Fold()
	local now = GetTime()
	for r, f in pairs(folding) do
		local u = math.min(1, (now - f.at) / FOLD)
		r:SetAlpha(1 - u)
		if u >= 1 then
			folding[r] = nil
			r:Hide()
			rows[#rows + 1] = r
			HUD.Update(box)
			Shy.Top.Apply()   -- (the last of them gone: the piece takes no room now)
		end
	end
end

local function Tick()
	Fold()
	for i, timer in ipairs(live) do
		local a, r = active[timer], rows[i]
		local progress = a and Plain(GetMirrorTimerProgress(timer))
		if progress and a.max and a.max > 0 then
			Draw(r, progress / a.max, progress / 1000, a.paused)
		end
	end
end

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not failed then
		failed = tostring(err)
		geterrorhandler()(err)
	end
end

local function Start(timer, value, max, paused, label, spell)
	timer = Plain(timer)
	if not timer or timer == "UNKNOWN" then return end
	active[timer] = { label = Plain(label), max = Plain(max), paused = Plain(paused) == 1 or Plain(paused) == true, spell = Plain(spell) }
	if Tm.on then Arrange() end
end

local function Event(_, event, ...)
	if event == "MIRROR_TIMER_START" then
		local timer, value, max, _, paused, label, spell = ...
		Start(timer, value, max, paused, label, spell)
	elseif event == "MIRROR_TIMER_STOP" then
		local timer = Plain((...))
		if timer and active[timer] then
			active[timer] = nil
			if Tm.on then Arrange() end
		end
	elseif event == "MIRROR_TIMER_PAUSE" then
		local timer, paused = ...
		timer = Plain(timer)
		if timer and active[timer] then active[timer].paused = Plain(paused) == 1 or Plain(paused) == true end
	else
		wipe(active)
		for i = 1, 3 do
			local timer, value, max, _, paused, label, spell = GetMirrorTimerInfo(i)
			Start(timer, value, max, paused, label, spell)
		end
		if Tm.on then Arrange() end
	end
end

function Tm.Live()
	local list = {}
	for i, timer in ipairs(live) do
		local r, a = rows[i], active[timer]
		-- (A sample, in layout mode: its words as drawn.)
		list[#list + 1] = { timer = timer, label = a and a.label or r.name:GetText(), share = r.share, left = r.right:GetText(),
			paused = a and a.paused, row = r, sample = a == nil or nil }
	end
	return list
end

local function Build()
	if box then return end
	box = HUD.Create({
		id = "shyskin.timers", title = "Breath and fatigue",
		width = WIDTH, height = ROW,
		point = { "TOP", "TOP", 0, -34 },
		shown = function() return Tm.on == true and (#live > 0 or next(folding) ~= nil or HUD.IsUnlocked()) end,
		away = function() return Tm.on ~= true end,
		-- First in the drawer under the head: nothing at the top is more urgent.
		top = { order = 7, sample = Tm.Sample, passing = true, wrap = true,
			-- (A bar still fading keeps its room: it goes where it stands, in the drawer.)
			empty = function() return #live == 0 and next(folding) == nil and not HUD.IsUnlocked() end },
	})
	box:SetFrameStrata("DIALOG")
	box:EnableMouse(false)
	box:SetScript("OnUpdate", function() Safe(Tick) end)
	-- The column lays the bars again as its width, who hangs in the drawer or the look changes.
	tray = Shy.Top.Tray(box, { least = WIDTH, lay = function()
		if Tm.on then Safe(Lay) end
	end })
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "MIRROR_TIMER_PAUSE", "PLAYER_ENTERING_WORLD" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(...) Safe(Event, ...) end)
	-- (A sign's light and a tab's wash are the theme's to color.)
	Shy:On("SHY_THEME", function()
		if Tm.on and #live > 0 then Safe(Arrange) end
	end)
	-- The alert took a timer up, or let it go.
	Shy:On("SHY_ALARM", function()
		if Tm.on then Safe(Arrange) end
	end)
	-- Layout mode opened or closed: the samples come or go.
	Shy:On("SHY_HUD_LAYOUT", function()
		if Tm.on then Safe(Arrange) end
	end)
end

ns.Module({
	id = "timers",
	title = "Breath and fatigue",
	desc = "Your breath, fatigue and feign death bars show at the top of your screen.",
	group = "screen",
	words = "drowning timer",

	Ready = function()
		return MirrorTimerContainer ~= nil and MirrorTimerContainer.mirrorTimers ~= nil and Shy.Top ~= nil and Shy.Top.Make ~= nil
	end,

	Hook = function() Build() end,

	Paint = function(m, kit)
		for _, timer in ipairs(MirrorTimerContainer.mirrorTimers) do
			kit:HideRegions(timer)
			kit:Hide(timer.Text)
			kit:Hide(timer.StatusBar)
		end
		local was = Tm.on
		Tm.on = true
		if not was then Safe(Event, nil, "PLAYER_ENTERING_WORLD") end
	end,

	Clear = function(m)
		if m.on then return end
		Tm.on = false
		for _, r in ipairs(rows) do r:Hide() end
		wipe(live)
		if box then
			HUD.Update(box)
			if Shy.Top then Shy.Top.Apply() end
		end
	end,
})
