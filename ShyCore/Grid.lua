-- Shy.Grid: the grid under what you move or size. Faint lines in the accent, a stronger one every fourth, and the
-- screen's middle lines lit with a soft glow and a ruler's ticks along them. Near the mouse the lines come up
-- brighter. It lies under every window and piece and over the world. It shows while something is dragged or sized,
-- in layout mode, and for a moment after its spacing changes. What is moved goes a little see-through, so the grid
-- shows behind it. A dragged box snaps its edges and its middle to a line it comes near (HUD.lua, Grip.lua). With
-- Shift held nothing snaps, and the grid dims to say so.
--
--   Shy.Grid.Show(key)   Shy.Grid.Hide(key)   -- "layout", "drag", "preview": it shows while any key holds it
--   local step, x, y = Shy.Grid.Lines()       -- its spacing and its middle, in UIParent units: lines at x + k * step
--   Shy.Grid.Snaps()                          -- what is moved snaps to it now: the setting, and no Shift held
--   Shy.Grid.See(frame, on)                   -- a frame goes see-through while it is moved, and comes back
--
-- Built the first time it shows, and laid again only when its spacing or the screen changes. While it shows, one
-- clock moves the bright patch to the mouse and runs the fades; hidden, nothing runs.
local Shy = Shy
local UI, Theme, B = Shy.UI, Shy.Theme, Shy.Brand
local core = Shy.core
local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

local Grid = {}
Shy.Grid = Grid

local G = {
	MAJOR = 4,                  -- every fourth line from the middle is a strong one
	MINOR_A = 0.06, MAJOR_A = 0.13,   -- the lines' strength
	NEAR = 2.6,                 -- how much brighter they are by the mouse
	LENS = 560,                 -- how wide that brighter patch is
	MIDDLE_A = 0.85,            -- the middle lines: one crisp pixel each
	TICK = 5, TICK_MAJOR = 9, TICK_A = 0.5,   -- the ruler's ticks along them
	PULL = 0.3,                 -- how near a line pulls what is moved, as a share of the spacing
	LEAST_PULL = 8,             -- and never less
	FREE = 0.35,                -- how bright it stays while Shift is held
	IN = 0.12, OUT = 0.25,      -- seconds fading in and out
	SEE = 0.85,                 -- a moved window's alpha, of its own
	PREVIEW = 1.6,              -- seconds it shows after its spacing changes
	LEAST = 16, MOST = 128,     -- the spacing it may have
	MOVING = { drag = true },   -- what "Grid while moving" holds back
}

local holds = {}       -- key -> true while it holds the grid up
local root             -- the grid, once built
local lines, lens, ticks = {}, {}, {}
local laid             -- "step width height" it was laid at
local level, target = 0, 0
local seen = {}        -- frame -> { base = its alpha, level, target, set = the alpha we gave it }
local preview          -- the last preview asked for
local driver = CreateFrame("Frame")

local function Db() return core.db and core.db.grid end

local function Spacing()
	local d = Db()
	local step = d and tonumber(d.step) or 32
	return max(G.LEAST, min(G.MOST, step))
end

function Grid.Lines()
	return Spacing(), UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
end

-- How near a line has to come for what is moved to land on it.
function Grid.Reach()
	return max(G.LEAST_PULL, Spacing() * G.PULL)
end

function Grid.Snaps()
	local d = Db()
	return d ~= nil and d.snap ~= false and not IsShiftKeyDown()
end

local function Build()
	root = CreateFrame("Frame", nil, UIParent)
	root:SetAllPoints()
	root:SetFrameStrata("BACKGROUND")
	root:SetFrameLevel(2)
	root:SetAlpha(0)
	root:Hide()
	-- The brighter patch by the mouse: a second set of lines seen through a soft round.
	root.lens = root:CreateMaskTexture()
	root.lens:SetTexture(B.GLOW, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	root.lens:SetSize(G.LENS, G.LENS)
	root.lens:SetPoint("CENTER")
	-- The middle lines: one crisp pixel each, brighter than the rest.
	root.midV, root.midH = root:CreateTexture(nil, "OVERLAY"), root:CreateTexture(nil, "OVERLAY")
	Theme.Paint(root.midV, Theme.AccentSolid, G.MIDDLE_A)
	Theme.Paint(root.midH, Theme.AccentSolid, G.MIDDLE_A)
end

local function Take(pool, i, layer, masked)
	local t = pool[i]
	if not t then
		t = root:CreateTexture(nil, layer)
		if masked then t:AddMaskTexture(root.lens) end
		pool[i] = t
	end
	t:ClearAllPoints()
	t:Show()
	return t
end

-- Lines out from the middle each way, so the middle is always a line and the grid is the same on both sides.
local function Lay()
	local step, w, h = Spacing(), UIParent:GetWidth(), UIParent:GetHeight()
	local at = step .. " " .. floor(w) .. " " .. floor(h)
	if laid == at then return end
	laid = at
	-- Every line on whole screen pixels: one laid across half a pixel is drawn blurred over two.
	local scale = UIParent:GetEffectiveScale()
	local px = PixelUtil.GetNearestPixelSize(1, scale, 1)
	local function Pixel(v) return PixelUtil.GetNearestPixelSize(v, scale) end
	local cx, cy = w / 2, h / 2
	root.midV:SetSize(px, h)
	root.midV:ClearAllPoints()
	root.midV:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", Pixel(cx), 0)
	root.midH:SetSize(w, px)
	root.midH:ClearAllPoints()
	root.midH:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, Pixel(cy))
	local n, m = 0, 0
	local function Put(vertical, along, strong)
		n = n + 1
		local alpha = strong and G.MAJOR_A or G.MINOR_A
		along = Pixel(along)
		for pass = 1, 2 do
			local t = pass == 1 and Take(lines, n, "ARTWORK") or Take(lens, n, "ARTWORK", true)
			if vertical then
				t:SetSize(px, h)
				t:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", along, 0)
			else
				t:SetSize(w, px)
				t:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, along)
			end
			Theme.Paint(t, Theme.AccentSolid, pass == 1 and alpha or min(1, alpha * G.NEAR))
		end
		-- Its tick on the middle line it crosses.
		m = m + 1
		local tick = Take(ticks, m, "OVERLAY")
		local long = strong and G.TICK_MAJOR or G.TICK
		if vertical then
			tick:SetSize(px, long)
			tick:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", along, Pixel(cy - long / 2))
		else
			tick:SetSize(long, px)
			tick:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", Pixel(cx - long / 2), along)
		end
		Theme.Paint(tick, Theme.AccentSolid, G.TICK_A)
	end
	for k = 1, ceil(cx / step) do
		local strong = k % G.MAJOR == 0
		if cx - k * step >= 0 then Put(true, cx - k * step, strong) end
		if cx + k * step <= w then Put(true, cx + k * step, strong) end
	end
	for k = 1, ceil(cy / step) do
		local strong = k % G.MAJOR == 0
		if cy - k * step >= 0 then Put(false, cy - k * step, strong) end
		if cy + k * step <= h then Put(false, cy + k * step, strong) end
	end
	for i = n + 1, #lines do
		lines[i]:Hide()
		lens[i]:Hide()
	end
	for i = m + 1, #ticks do ticks[i]:Hide() end
end

-- Toward `to` from `from`, by the fade's seconds.
local function Toward(from, to, elapsed)
	if from < to then return min(to, from + elapsed / G.IN) end
	return max(to, from - elapsed / G.OUT)
end

-- Under what is moved: what Shift does, and that it is held. Anchored to the frame, so it goes with it.
local tell
local Run

local function Say()
	if not (tell and tell:IsShown()) then return end
	local free = IsShiftKeyDown()
	if tell.free == free then return end
	tell.free = free
	tell.words:SetText(free and "Placing it freely" or "Hold Shift to place it freely")
	Theme.Ink(tell.words, free and Theme.AccentSolid or UI.colors.dim)
end

function Grid.Tell(frame)
	if not frame then
		if tell then tell:Hide() end
		return
	end
	if not tell then
		tell = CreateFrame("Frame", nil, UIParent)
		tell:SetFrameStrata("TOOLTIP")
		tell:SetSize(220, 22)
		tell:SetClampedToScreen(true)
		local pool = tell:CreateTexture(nil, "BACKGROUND")
		pool:SetTexture(B.GLOW)
		pool:SetPoint("CENTER")
		pool:SetSize(300, 54)
		Theme.Tint(pool, 0, 0, 0, 0.7)
		tell.words = UI.Words(tell, UI.TitleFont(12), UI.colors.dim, { justify = "CENTER", wrap = false })
		tell.words:SetPoint("CENTER")
	end
	tell:ClearAllPoints()
	tell:SetPoint("TOP", frame, "BOTTOM", 0, -10)
	tell.free = nil
	tell:Show()
	Say()
	Run()
end

local function Step(_, elapsed)
	if root and root:IsShown() then
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		root.lens:SetPoint("CENTER", root, "BOTTOMLEFT", x / s, y / s)
		if level ~= target then
			level = Toward(level, target, elapsed)
			root:SetAlpha(level)
		end
		-- (Out, though it may never have come up: let go of in the frame it was taken.)
		if level == 0 and target == 0 then root:Hide() end
	end
	for frame, w in pairs(seen) do
		local now = frame:GetAlpha()
		if issecretvalue(now) or abs(now - w.set) > 0.01 then
			seen[frame] = nil   -- something else sets its alpha now: it is theirs
		else
			w.level = Toward(w.level, w.target, elapsed)
			if w.level == 0 and w.target == 0 then
				frame:SetAlpha(w.base)
				seen[frame] = nil
			else
				w.set = w.base * (1 - (1 - G.SEE) * w.level)
				frame:SetAlpha(w.set)
			end
		end
	end
	Run()
end
local clocked = Shy.Clocked("grid: fading and following the mouse", Step)

-- What the grid aims for now, and whether anything needs the clock.
function Run()
	local up = next(holds) ~= nil
	target = up and (IsShiftKeyDown() and G.FREE or 1) or 0
	local busy = next(seen) ~= nil or (root ~= nil and root:IsShown())
	if busy then
		if not driver.on then
			driver.on = true
			driver:SetScript("OnUpdate", clocked)
		end
	elseif driver.on then
		driver.on = nil
		driver:SetScript("OnUpdate", nil)
	end
	local listen = up or (tell ~= nil and tell:IsShown())
	if listen ~= driver.listening then
		driver.listening = listen
		if listen then driver:RegisterEvent("MODIFIER_STATE_CHANGED") else driver:UnregisterEvent("MODIFIER_STATE_CHANGED") end
	end
end

function Grid.Show(key)
	local d = Db()
	if G.MOVING[key] and d and d.shown == false then return end
	holds[key] = true
	if not root then Build() end
	Lay()
	root:Show()
	Run()
end

function Grid.Hide(key)
	if key == "drag" and tell then tell:Hide() end
	if not holds[key] then
		Run()
		return
	end
	holds[key] = nil
	Run()
end

function Grid.See(frame, on)
	if not frame then return end
	local w = seen[frame]
	if on then
		local d = Db()
		if d and d.see == false then return end
		if w then
			w.target = 1
		else
			if frame:IsForbidden() or (InCombatLockdown() and frame:IsProtected()) then return end
			local alpha = frame:GetAlpha()
			if issecretvalue(alpha) then return end
			seen[frame] = { base = alpha, level = 0, target = 1, set = alpha }
		end
	elseif w then
		w.target = 0
	end
	Run()
end

-- A moment of the grid, to see a new spacing on the screen.
local function Preview()
	local mine = {}
	preview = mine
	Grid.Show("preview")
	C_Timer.After(G.PREVIEW, function()
		if preview == mine then Grid.Hide("preview") end
	end)
end

driver:SetScript("OnEvent", function(_, event)
	if event == "MODIFIER_STATE_CHANGED" then
		Run()
		Say()
	else
		laid = nil
		if root and root:IsShown() then Lay() end
	end
end)
driver:RegisterEvent("UI_SCALE_CHANGED")
driver:RegisterEvent("DISPLAY_SIZE_CHANGED")

core:Settings({
	{ section = "Moving and sizing" },
	{ key = "grid.shown", label = "Grid while moving", words = "align snap lines drag layout ruler",
		apply = function() if Db().shown then Preview() end end,
		desc = "A grid shows under what you move or size, so you can line things up." },
	{ key = "grid.step", label = "Grid spacing", min = G.LEAST, max = 96, step = 8, sub = true, words = "grid size gap",
		apply = Preview,
		desc = "How far apart its lines are. Its middle lines stay on the middle of your screen." },
	{ key = "grid.snap", label = "Snap to the grid", words = "align magnet lines",
		desc = "What you move lands on a line when it comes close. Hold Shift to place it freely." },
	{ key = "grid.see", label = "See-through while moving", words = "transparent fade alpha window",
		desc = "A window goes a little see-through while you move or size it." },
})
