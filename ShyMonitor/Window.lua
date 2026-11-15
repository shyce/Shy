-- The window: the family's main head, crumbs under its line, one view at a time in the body. It refreshes
-- itself twice a second while shown through its own OnUpdate (hidden, nothing runs) and gives a region a
-- value only when the value changed. It flows from 760 x 420 up.
--
--   W.View(name, def)       a view: { title = fn(key) -> text, build = fn(body), lay = fn(w, h),
--                           show = fn(key), refresh = fn(), copy = fn() -> title, text, reset = fn(),
--                           under = fn(key) -> view, key, kids = fn(key) -> { { text, view, key } } }
--                           (kids: what its crumb's caret lists)
--   W.Open(view, key)       opens at a view (made on the first open); the crumbs lead back
--   W.Close(), W.Toggle(), W.IsOpen()
--   W.Box()                 the window and its pieces, for the tests

local _, ns = ...
local T = ns.T
local UI, C = Shy.UI, Shy.UI.colors
local W = {}
ns.Window = W

W.WIDTH, W.HEIGHT = 940, 580
W.MIN_W, W.MIN_H = 760, 420
W.PAD = 12
W.TOP = UI.HEAD.main.line + UI.LINE   -- the head, down to its line's foot
W.CRUMBS = 24
local CRUMB_FONT, CRUMB_TALL = 12, 20
local CRUMB_INSET = 9   -- a crumb's words this far in from its edge: the row starts that far left of the body
local SLASH = 12        -- room for the slash between two crumbs
local REFRESH = 0.5

local views = {}
local box, body, crumbs
local open, current, currentKey = false, nil, nil
local trail = {}   -- the crumbs: { view, key }, home first
local crumbPool = {}
local since = 0

function W.View(name, def)
	views[name] = def
	def.name = name
end
function W.Views() return views end

-- A line of bars standing on their foot, the tallest the ring's largest value: bare (in a gauge), or on
-- a plate of its own with a title at its top left and a note at its right.
--   local s = ns.Spark(parent, bars, color[, title]);  s:Lay(w, h);  s:Draw(ring[, every])
local Theme = Shy.Theme
function ns.Spark(parent, n, color, title)
	local s = CreateFrame("Frame", nil, parent)
	local inset = title and 10 or 0
	if title then
		UI.Skin(s, C.bg, C.border)
		s.title = UI.Text(s, title, 11, true, C.head)
		s.title:SetPoint("TOPLEFT", 10, -7)
		s.note = s:CreateFontString(nil, "OVERLAY")
		s.note:SetFontObject(UI.NameFont(11))
		UI.Ink(s.note, C.dim)
		s.note:SetPoint("TOPRIGHT", -10, -7)
	end
	s.bars = {}
	for i = 1, n do
		local t = s:CreateTexture(nil, "ARTWORK")
		UI.Paint(t, color, 0.8)
		s.bars[i] = t
	end
	function s:Lay(w, h)
		self:SetSize(w, h)
		local step = (w - inset * 2) / n
		for i, t in ipairs(self.bars) do
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset + (i - 1) * step, inset)
			t:SetWidth(math.max(1, step - 1))
		end
		self.h = h - (title and 36 or 0) - inset
	end
	function s:Draw(ring, every)
		every = every or 1
		local most = ring:Max()
		for i = 1, n do
			local at = ring.count - (n - i) * every
			local v = at >= 1 and ring:Get(at) or 0
			ns.Height(self.bars[i], most > 0 and math.max(1, v / most * self.h) or 1)
		end
	end
	return s
end
ns.SparkColor = Theme.Accent

local function Lay(_, width, height)
	local w, h = width - W.PAD * 2, height - W.TOP - W.CRUMBS - W.PAD * 2
	body:SetSize(w, h)
	for _, view in pairs(views) do
		if view.frame and view.lay then view.lay(w, h) end
	end
	if open and current and current.refresh then current.refresh() end
end

-- The crumbs, as the map's: the home, then the way down to the view shown, each a split button. Its words
-- go back there; its caret lists what lies under it (a view's kids), the one on the way lit.
local function Crumb(i)
	local c = crumbPool[i]
	if c then return c end
	c = {}
	local b
	b = UI.SplitButton(crumbs, { font = UI.NameFont(CRUMB_FONT), height = CRUMB_TALL, inset = CRUMB_INSET, caretY = 1,
		write = function(root)
			local step, below = trail[i], trail[i + 1]
			local view = step and views[step.view]
			for _, kid in ipairs(view and view.kids and view.kids(step.key) or {}) do
				root:CreateRadio(kid.text, function() return below ~= nil and below.view == kid.view and below.key == kid.key end,
					function() W.Open(kid.view, kid.key) end)
			end
		end })
	-- The view shown bright, those above it dim, the hover color while a click on the words would go there.
	local look = b.OnLook
	function b:OnLook(s)
		look(self, s)
		local color = self.rest or C.dim
		if s.on then
			color = C.text
		elseif s.over and not (s.tail and self.act) then
			color = C.hot
		end
		UI.Ink(self.text, color)
	end
	c.button = b
	if i > 1 then
		c.slash = crumbs:CreateFontString(nil, "OVERLAY")
		c.slash:SetFontObject(UI.NameFont(CRUMB_FONT))
		c.slash:SetText("/")
		UI.Ink(c.slash, Shy.Skin.colors.idle)
	end
	crumbPool[i] = c
	return c
end
local function LayCrumbs()
	local x = 0
	for i, step in ipairs(trail) do
		local c = Crumb(i)
		local view = views[step.view]
		local here = i == #trail
		local b = c.button
		b.rest = here and C.text or C.dim
		b:SetAction(not here and function() W.Open(step.view, step.key) end or nil)
		local kids = view.kids and view.kids(step.key)
		b:SetChoices(kids ~= nil and #kids > 0)
		b:SetLabel(view.title and view.title(step.key) or view.name)
		b:OnLook(b.shyPress)
		if c.slash then
			c.slash:ClearAllPoints()
			c.slash:SetPoint("CENTER", crumbs, "LEFT", x + SLASH / 2 + 1, 0)
			c.slash:Show()
			x = x + SLASH
		end
		b:ClearAllPoints()
		b:SetPoint("LEFT", crumbs, "LEFT", x, 0)
		b:Show()
		x = x + b:GetWidth()
	end
	for i = #trail + 1, #crumbPool do
		crumbPool[i].button:Hide()
		if crumbPool[i].slash then crumbPool[i].slash:Hide() end
	end
end

local function Refresh()
	if not (open and current and current.refresh) then return end
	local now = GetTime()
	ns.Samples.Tick(now)
	if ns.Memory then ns.Memory.Tick(now) end
	current.refresh()
end

-- The Measure menu: what costs something, each saying what, none in a fight.
local function MeasureItems()
	local M = ns.Memory
	local fight = InCombatLockdown()
	local why = fight and "After the fight" or nil
	local items = {
		{ text = "Collect", sub = "One full clean-up now; a short hitch", disabled = fight, tip = why,
			click = function() M.Collect(GetTime()) Refresh() end },
		{ text = "Watch", sub = "A clean-up every " .. tostring(T.db and T.db.watch or 30) .. " s while open; stand still", on = M.watch,
			click = function() M.SetWatch(not M.watch) Refresh() end },
		{ text = "Measure churn", sub = "Holds off clean-up for ten seconds; memory climbs meanwhile", disabled = fight or M.churn.running, tip = why,
			click = function() M.StartChurn() Refresh() end },
	}
	if Shy.Errors then
		local E = Shy.Errors
		items[#items + 1] = { divider = true }
		items[#items + 1] = { text = "Show the game's error window", on = E.Popup(), click = function() E.SetPopup(not E.Popup()) end }
	end
	return items
end

local function Copy()
	if not (current and current.copy) then return end
	local title, text = current.copy()
	UI.ShowCopyBox(title, text)
end

local function Reset()
	Shy.ResetClocks()
	for _, set in ipairs(Shy.CounterSets()) do
		if set.reset then
			local ok, err = pcall(set.reset)
			if not ok then geterrorhandler()(err) end
		end
	end
	ns.Samples.Reset()
	if ns.Memory then ns.Memory.Reset() end
	for _, view in pairs(views) do
		if view.reset then view.reset() end
	end
	Refresh()
end

local function Create()
	box = UI.Window({
		id = "shymonitor", name = "ShyMonitorWindow", title = "Task manager",
		width = W.WIDTH, height = W.HEIGHT,
		point = { "CENTER", "CENTER", 0, 30 },
		shown = function() return open end,
		grip = { flow = Lay, min = { W.MIN_W, W.MIN_H } },
		strata = "HIGH",
		onClose = function() W.Close() end,
		head = { brand = T.suffix, icon = T.icon,
			buttons = { { "Reset", 64, Reset }, { "Copy", 64, Copy } } },
	})
	UI.Help(box.head.buttons[1], "Reset", "Starts every clock and counter again from now.")
	UI.Help(box.head.buttons[2], "Copy", "Copies this view as text: to-do, the last minute of frame and memory samples, then clocks.")
	local marks = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "LOOT_OPENED", "LOOT_CLOSED" }) do
		marks:RegisterEvent(event)
	end
	local MARK = { PLAYER_REGEN_DISABLED = "combat", PLAYER_REGEN_ENABLED = "combat end", LOOT_OPENED = "loot", LOOT_CLOSED = "loot end" }
	marks:SetScript("OnEvent", function(_, event)
		if open and MARK[event] then ns.Samples.Mark(MARK[event]) end
	end)
	local measure = UI.MenuButton(box.head, { items = MeasureItems, width = 84, height = 22, plate = true, tip = "Measurements that cost a little: a clean-up, a watch, the churn" })
	measure:SetLabel("Measure")
	measure:SetPoint("RIGHT", box.head.buttons[2], "LEFT", -8, 0)
	box.head.measure = measure

	crumbs = CreateFrame("Frame", nil, box)
	crumbs:SetPoint("TOPLEFT", W.PAD - CRUMB_INSET, -W.TOP - 4)
	crumbs:SetPoint("TOPRIGHT", -W.PAD, -W.TOP - 4)
	crumbs:SetHeight(W.CRUMBS - 4)

	body = CreateFrame("Frame", nil, box)
	body:SetPoint("TOPLEFT", W.PAD, -W.TOP - W.CRUMBS - W.PAD + 4)
	body:SetSize(W.WIDTH - W.PAD * 2, W.HEIGHT - W.TOP - W.CRUMBS - W.PAD * 2)

	-- The refresh: the window's own frame, so a hidden window runs nothing.
	box:SetScript("OnUpdate", Shy.Clocked("monitor: refresh", function(_, dt)
		since = since + dt
		if since < REFRESH then return end
		since = 0
		Refresh()
	end))
	Shy:On("SHY_THEME", function() if open and current and current.refresh then current.refresh() end end)
end

local function Build(view)
	if view.frame then return end
	view.frame = CreateFrame("Frame", nil, body)
	view.frame:SetAllPoints()
	view.build(view.frame)
	if view.lay then view.lay(body:GetWidth(), body:GetHeight()) end
end

-- The way down to a view: the home, then the addon a clock or counter set belongs to, then the view.
local function Trail(view, key)
	for i = #trail, 1, -1 do trail[i] = nil end
	trail[1] = { view = "addons" }
	if view ~= "addons" then
		local def = views[view]
		if def.under then
			local under, underKey = def.under(key)
			if under then trail[#trail + 1] = { view = under, key = underKey } end
		end
		trail[#trail + 1] = { view = view, key = key }
	end
end

function W.Open(view, key)
	local def = views[view] or views.addons
	if not box then Create() end
	Build(def)
	open = true
	for _, each in pairs(views) do
		if each.frame and each ~= def then each.frame:Hide() end
	end
	current, currentKey = def, key
	Trail(def.name, key)
	ns.Samples.Names()
	LayCrumbs()
	if def.show then def.show(key) end
	def.frame:Show()
	Shy.ClockDetail(true)
	Shy.HUD.Update(box)
	box:Raise()
	since = 0
	Refresh()
end

function W.Close()
	open = false
	Shy.ClockDetail(false)
	if ns.Memory then ns.Memory.SetWatch(false) end
	if box then Shy.HUD.Update(box) end
end

function W.Toggle()
	if open then W.Close() else W.Open("addons") end
end

function W.IsOpen() return open end

function W.Box()
	return box, body, crumbs, current, currentKey
end
