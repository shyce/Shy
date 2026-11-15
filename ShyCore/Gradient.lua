-- Shy.UI.GradientRamp and Shy.UI.GradientEditor: the accent's ramp drawn, and made (Theme.lua, "The gradient").
--
--   local ramp = UI.GradientRamp(parent, width, height, opts)   -- a ramp on a dark backing in a hairline of the
--       border's color (opts.out: how far out the hairline stands, 1 or 2); ramp:SetRamp(g) shows a ramp (one of
--       Theme.Stops()' shape: a single stop is one color); ramp:SetRim(color) recolors its hairline
--   local editor = UI.GradientEditor(parent, width, opts)       -- opts.get() -> the ramp being worn or planned,
--       nil for one color; opts.set(g): the ramp made (nil: one color), called as it changes (the owner applies it:
--       Theme.SetGradientSoon, or a plan). editor:Refresh() reads opts.get() again; it is EDITOR_H tall.
--
-- The editor, top to bottom: the ramps offered as chips (one color first), the name of the one picked and its
-- sentence; the ramp in a sunk well, its stops under it as pins pointing up into it and the picked stop's two
-- midpoints as diamonds between them; a line on how to use it; then the picked stop's color on the slider's make
-- (hue, saturation, lightness: any color, white and black too), and where it stands, the spread, the flow, and
-- Reverse and Remove. A click on the ramp or under it adds a stop there in the color the ramp has there (and may
-- be dragged on at once); a pin dragged moves its stop, past its neighbours too; dragged well off the ramp it lifts
-- (dimmed) and is taken out when let go, never below two stops; a diamond dragged leans its midpoint. The editor
-- draws its own ramp at every step; what is on screen takes it once the drag rests (the owner's Soon).

local Shy = Shy
local Theme, UI = Shy.Theme, Shy.UI
local C, S = UI.colors, Theme.skin
local Grad = Theme.Grad

local floor, max, min = math.floor, math.max, math.min

local MEDIA = Shy.MEDIA
local PIN_ART, MID_ART, MID_DOT_ART = MEDIA .. "GradientPin", MEDIA .. "GradientMid", MEDIA .. "GradientMidDot"
-- The art's measures (units): the pin's picture, the square in it where the stop's color shows (left, top, right,
-- bottom), the diamond's picture.
local PIN_W, PIN_H, PIN_HOLE, MID_W = 16, 21, { 3, 7, 13, 17 }, 11

-- The editor's measures (units).
local CHIP_H, CHIP_GAP = 18, 6            -- the ramps offered, and between them
local NAME_GAP, NAME_H = 8, 16            -- under the chips: the name picked
local RAMP_GAP, RAMP_H = 10, 26           -- the ramp
local LANE_H = 24                         -- the stops under it
local HINT_GAP, HINT_H = 4, 12            -- the line on how to use it
local COLS_GAP, ROW, COL_GAP = 18, 56, 40 -- the controls: two columns, a row each
local PULL = 26                           -- how far off the ramp and its lane a stop is dragged to lift it
local SETTLE = 0.6                        -- after a change here, how long the owner's ramp may still be the old one
UI.GRADIENT_EDITOR_H = CHIP_H + NAME_GAP + NAME_H + RAMP_GAP + RAMP_H + LANE_H + HINT_GAP + HINT_H + COLS_GAP + 3 * ROW + 24

local BACK = { 0.02, 0.02, 0.025, 1 }

-- Four hairlines round a frame, `out` units outside it.
local function Rim(f, out, layer)
	local lines = {}
	for i = 1, 4 do
		lines[i] = f:CreateTexture(nil, layer or "BORDER")
		lines[i]:SetSnapToPixelGrid(false)
		lines[i]:SetTexelSnappingBias(0)
	end
	lines[1]:SetPoint("TOPLEFT", -out, out)
	lines[1]:SetPoint("TOPRIGHT", out, out)
	lines[1]:SetHeight(1)
	lines[2]:SetPoint("BOTTOMLEFT", -out, -out)
	lines[2]:SetPoint("BOTTOMRIGHT", out, -out)
	lines[2]:SetHeight(1)
	lines[3]:SetPoint("TOPLEFT", -out, out - 1)
	lines[3]:SetPoint("BOTTOMLEFT", -out, -out + 1)
	lines[3]:SetWidth(1)
	lines[4]:SetPoint("TOPRIGHT", out, out - 1)
	lines[4]:SetPoint("BOTTOMRIGHT", out, -out + 1)
	lines[4]:SetWidth(1)
	return lines
end

-- The ramp: a texture for each straight piece between where it bends, each blended between its two ends (as
-- every flat stripe on screen is cut), each from where the one before it ends, so no seam opens between them.
function UI.GradientRamp(parent, width, height, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	local back = f:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(BACK[1], BACK[2], BACK[3], BACK[4])
	f.rim = Rim(f, opts.out or 1)
	local pieces = {}
	f.pieces = pieces
	function f:SetRim(color, alpha)
		for _, t in ipairs(self.rim) do Theme.Paint(t, color, alpha) end
	end
	function f:SetRamp(g)
		local cuts = { 0 }
		for _, at in ipairs(Grad.Bends(g)) do
			if at > cuts[#cuts] + 1e-4 and at < 1 - 1e-4 then cuts[#cuts + 1] = at end
		end
		cuts[#cuts + 1] = 1
		for i = 1, #cuts - 1 do
			local t = pieces[i]
			if not t then
				t = f:CreateTexture(nil, "ARTWORK")
				pieces[i] = t
			end
			t:ClearAllPoints()
			if i == 1 then t:SetPoint("TOPLEFT") else t:SetPoint("TOPLEFT", pieces[i - 1], "TOPRIGHT") end
			if i == #cuts - 1 then t:SetPoint("BOTTOMRIGHT") else t:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", cuts[i + 1] * width, 0) end
			t:SetColorTexture(1, 1, 1, 1)
			local r0, g0, b0 = Grad.Sample(g, cuts[i])
			local r1, g1, b1 = Grad.Sample(g, cuts[i + 1])
			t:SetGradient("HORIZONTAL", CreateColor(r0, g0, b0, 1), CreateColor(r1, g1, b1, 1))
			t:Show()
		end
		for i = #cuts, #pieces do pieces[i]:Hide() end
	end
	f:SetRim(C.border)
	return f
end

-- One color as a ramp: the accent alone.
local function Solid()
	local h, s, l = Theme.ToHSL(Theme.Accent())
	return { stops = { { at = 0, h = h, s = s, l = l } }, mids = {} }
end

-- A stop's color as a mark: lifted to show on graphite (a black stop's slider is a dark grey, not none).
local function Shown(stop)
	local r, g, b = Grad.Color(stop)
	local p = C.panel
	return Theme.Readable(r, g, b, p[1], p[2], p[3], Theme.LC_MARK)
end

function UI.GradientEditor(parent, width, opts)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, UI.GRADIENT_EDITOR_H)
	local g, picked = Grad.Clean(opts.get()), 1   -- the ramp being made (nil: one color), its picked stop
	local touched = -SETTLE                        -- when it was last changed here
	local drag                                     -- { kind = "stop" | "mid", seg, off }
	local Draw

	local function Commit()
		touched = GetTime()
		opts.set(g and Grad.Clean(g) or nil)
	end
	local function Picked() return g and g.stops[picked] end

	-- The ramps offered: one color, then Theme.GRADIENTS. A click puts it on; the one worn is ringed in light.
	local offered = { { name = "One color", desc = "Your accent color alone, no gradient." } }
	for _, item in ipairs(Theme.GRADIENTS) do offered[#offered + 1] = item end
	local chipW = (width - (#offered - 1) * CHIP_GAP) / #offered
	local chips = {}
	for i, item in ipairs(offered) do
		local chip = CreateFrame("Button", nil, f)
		chip:SetSize(chipW, CHIP_H)
		chip:SetPoint("TOPLEFT", (i - 1) * (chipW + CHIP_GAP), 0)
		chip.ramp = UI.GradientRamp(chip, chipW - 2, CHIP_H - 2)
		chip.ramp:SetPoint("CENTER")
		if item.ramp then chip.ramp:SetRamp(item.ramp) end
		chip.lit = Rim(chip, 2, "OVERLAY")
		for _, t in ipairs(chip.lit) do Theme.Paint(t, Theme.light) end
		chip.item = item
		chip:SetScript("OnClick", function()
			g = item.ramp and Grad.Clean(item.ramp) or nil
			picked = 1
			Commit()
			Draw()
		end)
		chip:SetScript("OnEnter", function(self)
			self.over = true
			Draw()
			UI.Tip(self, item.name, item.desc)
		end)
		chip:SetScript("OnLeave", function(self)
			self.over = false
			Draw()
			UI.TipHide(self)
		end)
		chips[i] = chip
	end
	local y = CHIP_H + NAME_GAP
	local name = UI.Text(f, "", 13, true, C.head)
	name:SetPoint("TOPLEFT", 0, -y)
	local said = UI.Text(f, "", 12, false, C.dim)
	said:SetPoint("LEFT", name, "LEFT", 110, 0)
	said:SetWidth(width - 110)
	said:SetWordWrap(false)
	y = y + NAME_H + RAMP_GAP

	-- The ramp in its well, and the lane of stops under it. Under both, what catches a click to add a stop.
	local ramp = UI.GradientRamp(f, width, RAMP_H, { out = 2 })
	ramp:SetPoint("TOPLEFT", 0, -y)
	local catch = CreateFrame("Button", nil, f)
	catch:SetPoint("TOPLEFT", ramp, "TOPLEFT")
	catch:SetPoint("BOTTOMRIGHT", ramp, "BOTTOMRIGHT", 0, -LANE_H)
	catch:EnableMouse(true)

	-- Where the cursor stands: its share of the ramp's width, and its height (the ramp's units).
	local function Cursor()
		local scale = ramp:GetEffectiveScale()
		local x, cy = GetCursorPosition()
		local left, right = ramp:GetLeft(), ramp:GetRight()
		if not (left and right and right > left) then return 0, 0 end
		return (x / scale - left) / (right - left), cy / scale
	end

	-- A stop added at the cursor (one color first becomes a ramp of it at both ends), picked and held.
	catch:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then return end
		local at = max(0, min(1, (Cursor())))
		if not g then
			local one = Solid().stops[1]
			g = Grad.Clean({ stops = { { at = 0, h = one.h, s = one.s, l = one.l }, { at = 1, h = one.h, s = one.s, l = one.l } } })
		end
		local i = Grad.Add(g, at)
		if i then
			picked = i
			drag = { kind = "stop", at = at }
		end
		Commit()
		Draw()
	end)

	-- The stops: a pin each (made as needed), its color in the square, its rim steel, lit when picked or under the
	-- mouse, a soft light round the picked one.
	local pins = {}
	local function Pin(i)
		if pins[i] then return pins[i] end
		local pin = CreateFrame("Button", nil, f)
		pin:SetSize(PIN_W, PIN_H)
		pin:SetFrameLevel(catch:GetFrameLevel() + 2)
		pin.glow = pin:CreateTexture(nil, "BACKGROUND")
		pin.glow:SetTexture(MEDIA .. "Glow")
		pin.glow:SetBlendMode("ADD")
		pin.glow:SetSize(32, 32)
		pin.glow:SetPoint("CENTER", pin, "TOPLEFT", PIN_W / 2, -(PIN_HOLE[2] + PIN_HOLE[4]) / 2)
		Theme.Tint(pin.glow, Theme.light, 0.55)
		pin.swatch = pin:CreateTexture(nil, "BORDER")
		pin.swatch:SetPoint("TOPLEFT", PIN_HOLE[1], -PIN_HOLE[2])
		pin.swatch:SetPoint("BOTTOMRIGHT", pin, "TOPLEFT", PIN_HOLE[3], -PIN_HOLE[4])
		pin.art = pin:CreateTexture(nil, "ARTWORK")
		pin.art:SetTexture(PIN_ART)
		pin.art:SetAllPoints()
		pin:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" then return end
			picked = self.index
			drag = { kind = "stop", at = g.stops[picked].at }
			Draw()
		end)
		pin:SetScript("OnEnter", function(self) self.over = true; Draw() end)
		pin:SetScript("OnLeave", function(self) self.over = false; Draw() end)
		pins[i] = pin
		return pin
	end

	-- The picked stop's midpoints: a diamond in each segment beside it, its middle lit under the mouse or held.
	local mids = {}
	for k = 1, 2 do
		local mid = CreateFrame("Button", nil, f)
		mid:SetSize(MID_W, MID_W)
		mid:SetFrameLevel(catch:GetFrameLevel() + 1)
		mid.art = mid:CreateTexture(nil, "ARTWORK")
		mid.art:SetTexture(MID_ART)
		mid.art:SetAllPoints()
		mid.dot = mid:CreateTexture(nil, "OVERLAY")
		mid.dot:SetTexture(MID_DOT_ART)
		mid.dot:SetAllPoints()
		Theme.Tint(mid.dot, Theme.light, 1)
		mid:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" or not self.seg then return end
			drag = { kind = "mid", seg = self.seg }
			Draw()
		end)
		mid:SetScript("OnEnter", function(self) self.over = true; Draw() end)
		mid:SetScript("OnLeave", function(self) self.over = false; Draw() end)
		mids[k] = mid
	end

	-- A drag, followed as the cursor moves and ended when the button is let go (wherever it is).
	local function EndDrag()
		if drag and drag.kind == "stop" and drag.off and Grad.Remove(g, picked) then
			picked = min(picked, #g.stops)
		end
		drag = nil
		Commit()
		Draw()
	end
	f:SetScript("OnUpdate", function()
		if not drag then return end
		if not IsMouseButtonDown("LeftButton") then return EndDrag() end
		local at, cy = Cursor()
		at = max(0, min(1, at))
		if drag.kind == "stop" then
			local top, bottom = ramp:GetTop(), ramp:GetBottom()
			local off = (top and bottom and (cy > top + PULL or cy < bottom - LANE_H - PULL) and #g.stops > Grad.MIN) or false
			if at == drag.at and off == drag.off then return end
			drag.at, drag.off = at, off
			picked = Grad.Move(g, picked, at)
		else
			local i = drag.seg
			local a, b = g.stops[i].at, g.stops[i + 1].at
			if b - a < 1e-3 then return end
			local m = max(Grad.MID[1], min(Grad.MID[2], (at - a) / (b - a)))
			if m == g.mids[i] then return end
			g.mids[i] = m
		end
		Commit()
		Draw()
	end)
	f:SetScript("OnHide", function() if drag then EndDrag() end end)
	y = y + RAMP_H + LANE_H + HINT_GAP
	local hint = UI.Text(f, "", 11, false, C.dim)
	hint:SetPoint("TOPLEFT", 0, -y)
	y = y + HINT_H + COLS_GAP

	-- The picked stop's color and place, the spread, the flow; dimmed while there is no ramp.
	local col = floor((width - COL_GAP) / 2)
	local function Has() return g ~= nil end
	local function Color() if g then return Shown(Picked()) end return Theme.Accent() end
	local function Percent(v) return v .. "%" end
	local function Edit(fn)
		return function(v)
			if not g then return end
			fn(v, Picked())
			Commit()
			Draw()
		end
	end
	local hue = UI.Slider(f, "Hue", 0, 359, 1, function() return g and floor(Picked().h + 0.5) % 360 or 0 end,
		Edit(function(v, stop) stop.h = v end),
		{ width = col, color = Color, enabled = Has, format = function(v) return v .. "\194\176" end, desc = "The hue of the picked color." })
	hue:SetPoint("TOPLEFT", 0, -y)
	-- Under the hue, every hue at a strength and lightness that shows it (a grey or a black stop's too).
	local strip = CreateFrame("Frame", nil, f)
	strip:SetSize(col, 5)
	strip:SetPoint("TOPLEFT", hue, "BOTTOMLEFT", 0, -2)
	local HUES = 36
	strip.cells = {}
	for i = 1, HUES do
		local t = strip:CreateTexture(nil, "ARTWORK")
		t:SetSize(col / HUES + 0.5, 5)
		t:SetPoint("LEFT", (i - 1) * col / HUES, 0)
		strip.cells[i] = t
	end
	local sat = UI.Slider(f, "Saturation", 0, 100, 1, function() return g and floor(Picked().s * 100 + 0.5) or 0 end,
		Edit(function(v, stop) stop.s = v / 100 end),
		{ width = col, color = Color, enabled = Has, format = Percent, desc = "How strong the picked color is: all the way down is grey." })
	sat:SetPoint("TOPLEFT", 0, -y - ROW)
	local light = UI.Slider(f, "Lightness", 0, 100, 1, function() return g and floor(Picked().l * 100 + 0.5) or 0 end,
		Edit(function(v, stop) stop.l = v / 100 end),
		{ width = col, color = Color, enabled = Has, format = Percent, desc = "How light the picked color is: all the way down is black, all the way up white." })
	light:SetPoint("TOPLEFT", 0, -y - 2 * ROW)
	local x = col + COL_GAP
	local location = UI.Slider(f, "Location", 0, 100, 1, function() return g and floor(Picked().at * 100 + 0.5) or 0 end,
		Edit(function(v) picked = Grad.Move(g, picked, v / 100) end),
		{ width = col, enabled = Has, format = Percent, desc = "Where the picked color stands along the bar." })
	location:SetPoint("TOPLEFT", x, -y)
	local spread = UI.Dropdown(f, "Spread", { { value = "across", text = "Across the screen" }, { value = "along", text = "Along each piece" } },
		function() return g and g.spread or "across" end,
		Edit(function(v) g.spread = v end),
		{ width = col, enabled = Has, desc = "Across the screen makes your whole UI one gradient; along each piece runs it across every window and bar." })
	spread:SetPoint("TOPLEFT", x, -y - ROW + 8)
	local flow = UI.Slider(f, "Flow", 0, Grad.FLOW, 1, function() return g and g.flow or 0 end,
		Edit(function(v) g.flow = v end),
		{ width = col, enabled = Has, format = function(v) return v == 0 and "Off" or tostring(v) end,
			desc = "How fast the colors drift slowly along; off holds them still." })
	flow:SetPoint("TOPLEFT", x, -y - 2 * ROW)
	local reverse = UI.Button(f, "Reverse", 90, function()
		if not g then return end
		Grad.Reverse(g)
		picked = #g.stops - picked + 1
		Commit()
		Draw()
	end)
	reverse:SetPoint("TOPLEFT", x, -y - 3 * ROW)
	UI.Help(reverse, "Reverse", "Turn the gradient end for end.")
	local remove = UI.Button(f, "Remove", 90, function()
		if g and Grad.Remove(g, picked) then
			picked = min(picked, #g.stops)
			Commit()
			Draw()
		end
	end)
	remove:SetPoint("LEFT", reverse, "RIGHT", 10, 0)
	UI.Help(remove, "Remove", "Take the picked color out of the gradient.")

	-- Everything drawn again from the ramp being made.
	function Draw()
		if g then picked = max(1, min(picked, #g.stops)) end
		local key = g and Theme.GradientKey(g) or nil
		for i, chip in ipairs(chips) do
			local worn = (i == 1 and not g) or (chip.item.key ~= nil and chip.item.key == key)
			for _, t in ipairs(chip.lit) do t:SetShown(worn) end
			chip.ramp:SetRim(chip.over and S.metal or C.border)
			if i == 1 then chip.ramp:SetRamp(Solid()) end
		end
		local shown = offered[1]
		if key and key ~= "own" then
			for _, item in ipairs(Theme.GRADIENTS) do
				if item.key == key then shown = item end
			end
		end
		if key == "own" then
			name:SetText("Your own")
			said:SetText("A gradient you made. Pick a chip to start again from one of ours.")
		else
			name:SetText(shown.name)
			said:SetText(shown.desc)
		end
		ramp:SetRamp(g or Solid())
		-- The pins, each at its stop.
		local count = g and #g.stops or 0
		for i = 1, count do
			local stop, pin = g.stops[i], Pin(i)
			pin.index = i
			pin:ClearAllPoints()
			pin:SetPoint("TOP", ramp, "BOTTOMLEFT", stop.at * width, -1)
			local r, gg, b = Grad.Color(stop)
			pin.swatch:SetColorTexture(r, gg, b, 1)
			local on = i == picked
			Theme.Tint(pin.art, (on or pin.over) and S.lit or S.metal, 1)
			pin.glow:SetShown(on)
			pin:SetAlpha((on and drag and drag.off) and 0.35 or 1)
			pin:Show()
		end
		for i = count + 1, #pins do pins[i]:Hide() end
		-- The picked stop's midpoints: in the segment before it and the one after.
		for k, mid in ipairs(mids) do
			local seg = g and (k == 1 and picked - 1 or picked) or nil
			if seg and seg >= 1 and seg < count then
				local a, b = g.stops[seg].at, g.stops[seg + 1].at
				mid.seg = seg
				mid:ClearAllPoints()
				mid:SetPoint("CENTER", ramp, "BOTTOMLEFT", (a + (b - a) * g.mids[seg]) * width, -1 - (PIN_HOLE[2] + PIN_HOLE[4]) / 2)
				local held = drag and drag.kind == "mid" and drag.seg == seg
				Theme.Tint(mid.art, (held or mid.over) and S.lit or S.metal, 1)
				mid.dot:SetShown((held or mid.over) and true or false)
				mid:SetShown(b - a > 0.04)
			else
				mid.seg = nil
				mid:Hide()
			end
		end
		hint:SetText(g and "Click the bar to add a color, or drag one off it to take it out."
			or "Pick a gradient above, or click the bar to make your own.")
		-- The controls: the hue's strip at the picked stop's strength and lightness (held to show its hues).
		local stop = Picked()
		local s, l = stop and max(0.6, stop.s) or 0.6, stop and max(0.45, min(0.7, stop.l)) or 0.6
		for i, t in ipairs(strip.cells) do t:SetColorTexture(Theme.FromHSL((i - 0.5) * 360 / HUES, s, l)) end
		strip:SetAlpha(g and 1 or 0.4)
		for _, control in ipairs({ hue, sat, light, location, spread, flow }) do control:Refresh() end
		reverse:SetUsable(g ~= nil)
		remove:SetUsable(g ~= nil and #g.stops > Grad.MIN, g and "A gradient keeps at least two colors." or nil)
	end

	-- From the owner again, unless a change made here may not have reached it yet (or a drag is on).
	function f:Refresh()
		if not drag and GetTime() - touched > SETTLE then
			local now = Grad.Clean(opts.get())
			if Grad.Sign(now) ~= Grad.Sign(g) then picked = 1 end   -- the same ramp keeps its picked stop
			g = now
		end
		Draw()
	end
	Shy:On("SHY_THEME", function()
		if f:IsVisible() then f:Refresh() end
	end)
	f.chips, f.ramp, f.catch, f.pins, f.mids, f.hint, f.name, f.said = chips, ramp, catch, pins, mids, hint, name, said
	f.hue, f.sat, f.light, f.location, f.spread, f.flow, f.reverse, f.remove = hue, sat, light, location, spread, flow, reverse, remove
	function f:Working() return g, picked end
	Draw()
	return f
end
