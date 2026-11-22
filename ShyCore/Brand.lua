-- Shy.Brand: branded text, titles, emblems, lines and the login splash.
--
--   B.Name("Tip")                     -> "Shy" in the accent ramp + white suffix (escape codes)
--   B.Name()                          -> the family's own name, ShyUI ("UI" stands in for the suffix)
--   B.Plain("Tip"), B.Plain()         -> the same names as plain words
--   B.FAMILY, B.STEM, B.OLD           -> "ShyUI", "Shy", and the family's name before
--   B.Gradient(text)                  -> any text in the accent ramp, deep to light
--   B.Ramp(u)                         -> r, g, b along the accent: 0 deep, 0.5 accent, 1 light
--   B.Cycle(t)                        -> the ramp up and back as t counts cycles
--   B.Icon(path, size)                -> inline icon markup, tinted with the accent
--   B.Chat(text)                      -> a line an addon says in chat by itself: "<ShyUI> text"
--   B.GetFont()                      -> the display font (Lilita One)
--   B.CreateTitle(parent, "Tip", 32)  -> per-letter animated title
--   B.CreateEmblem(parent, icon, 64)  -> icon over a pulsing glow, with a periodic sheen
--   B.CreateLine(parent, w, h)        -> accent line with a glimmer; anchor both ends to stretch it
--   B.ShowSplash()                    -> the login splash
--
-- Animated pieces redraw every frame and follow an accent change.
-- Text from B.Name keeps its color: rewrite it on "SHY_THEME" (see UI.Themed).

local B = {}
Shy.Brand = B
local Theme = Shy.Theme

B.GLOW = Shy.MEDIA .. "Glow"      -- soft round glow, white: tint it
B.SHEEN = Shy.MEDIA .. "Sheen"    -- slanted band of light, white

B.titles, B.emblems, B.lines = {}, {}, {}

local floor, abs, sin, pi, max, min = math.floor, math.abs, math.sin, math.pi, math.max, math.min
local format, concat = string.format, table.concat
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

local ICE = Theme.light   -- white of a light at full power
local Ramp = Theme.Ramp
B.Ramp = Ramp

function B.Cycle(t)
	local u = t % 1
	return Ramp(u < 0.5 and u * 2 or (1 - u) * 2)
end

local function Hex(r, g, b)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- Text helpers

function B.Gradient(text)
	local chars = {}
	for ch in text:gmatch(UTF8_CHAR) do chars[#chars + 1] = ch end
	local out = {}
	for i, ch in ipairs(chars) do
		out[i] = "|cff" .. Hex(Ramp((i - 1) / max(1, #chars - 1))) .. ch .. "|r"
	end
	return concat(out)
end

-- Names. Every word of the brand is here; nothing else spells it out.
-- The family is ShyUI, easy to search for. An addon keeps its own name (ShyQuest).
B.STEM = "Shy"                 -- the lit part every name starts with
local FAMILY_SUFFIX = "UI"
B.FAMILY = B.STEM .. FAMILY_SUFFIX
B.OLD = B.STEM                 -- the family's name before: what it wrote into the game's lists then is still its own

-- What follows the stem: an addon's name, or the family's (with any words after it: " layout").
local function Suffix(suffix)
	if not suffix or suffix == "" or suffix:sub(1, 1) == " " then return FAMILY_SUFFIX .. (suffix or "") end
	return suffix
end

function B.Name(suffix)
	return B.Gradient(B.STEM) .. "|cffffffff" .. Suffix(suffix) .. "|r"
end

-- The same name as plain words, for text that carries no color (copy boxes, tooltips' titles, buttons).
function B.Plain(suffix)
	return B.STEM .. Suffix(suffix)
end

-- The house preset wears the family's name.
for _, preset in ipairs(Theme.PRESETS) do
	if preset.house then preset.name = B.FAMILY end
end

B.Icon = Theme.IconMarkup

-- A line an addon sends to other players by itself, marked as an addon's so nobody takes it for typed
-- words. Plain text: sent chat carries no color or icon.
B.CHAT = "<" .. B.FAMILY .. "> "
function B.Chat(text)
	return B.CHAT .. text
end

-- Preload the font so the first text measured with it has the right width.
local preload = UIParent:CreateFontString(nil, "BACKGROUND")
preload:SetFont(Shy.FONT, 14, "")
preload:SetText(B.FAMILY)
preload:Hide()

function B.GetFont()
	return Shy.FONT
end

-- Animated widgets
-- Each runs only while it is on screen: it wakes the driver as it shows and drops out as it hides (or is
-- found hidden), and the driver stops when none is left. Each is given its look at rest as it is made and
-- on an accent change, so one never animated still looks right. A color is set again only when it changes
-- by a step the screen shows.

local POWER_STEP, POWER_TIME = 0.07, 0.22   -- delay between letters lighting, and how long each takes
local SCAN_EVERY, SCAN_TIME = 6, 1.0        -- how often a gleam crosses the title, and how long it takes

local Watch   -- (below the updates)

local function Step(v)
	return floor(v * 255 + 0.5)
end

-- One FontString per letter: lit in sequence on show, then a gleam crosses periodically.
function B.CreateTitle(parent, suffix, size)
	local f = CreateFrame("Frame", nil, parent)
	local font = B.GetFont()
	f.letters, f.colors = {}, {}
	for ch in B.Plain(suffix):gmatch(UTF8_CHAR) do
		local fs = f:CreateFontString(nil, "OVERLAY")
		fs:SetFont(font, size, "OUTLINE")
		fs:SetShadowOffset(0, -2)
		fs:SetText(ch)
		local i = #f.letters + 1
		f.letters[i] = fs
		f.colors[i] = i <= #B.STEM and Theme.ramp[i] or ICE   -- theme tables by reference: they change in place
	end
	local function Layout()
		local x = 0
		for _, fs in ipairs(f.letters) do
			fs:SetPoint("LEFT", f, "LEFT", x, 0)
			x = x + fs:GetStringWidth()
		end
		f:SetSize(x, size * 1.4)
		f.born = GetTime()
	end
	Layout()
	f:HookScript("OnShow", Layout)
	B.titles[f] = true
	Watch(f, "title")
	return f
end

function B.CreateEmblem(parent, icon, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.glow = f:CreateTexture(nil, "BACKGROUND")
	f.glow:SetTexture(B.GLOW)
	f.glow:SetBlendMode("ADD")
	f.glow:SetPoint("CENTER")
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	Theme.Icon(f.icon, icon, size)
	f.sheen = f:CreateTexture(nil, "OVERLAY")
	f.sheen:SetTexture(B.SHEEN)
	f.sheen:SetBlendMode("ADD")
	f.sheen:SetAlpha(0)
	local mask = f:CreateMaskTexture()
	mask:SetTexture(icon, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(f.icon)
	f.sheen:AddMaskTexture(mask)
	-- Stagger the sheen so emblems on one screen don't flash together.
	local count = 0
	for _ in pairs(B.emblems) do count = count + 1 end
	f.delay = count * 0.18
	B.emblems[f] = true
	Watch(f, "emblem")
	return f
end

-- Tapered ends unless `solid`.
function B.CreateLine(parent, width, height, segments, solid)
	segments = segments or 32
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	f.segs, f.solid = {}, solid
	for i = 1, segments do
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(1, 1, 1, 1)
		f.segs[i] = t
	end
	-- Each segment the line's whole height, whatever it is given (a header's line is fitted to the pixel).
	local function Fit(self, w)
		local step = w / segments
		for i, t in ipairs(self.segs) do
			t:SetWidth(step + 0.5)
			t:SetPoint("TOPLEFT", (i - 1) * step, 0)
			t:SetPoint("BOTTOMLEFT", (i - 1) * step, 0)
		end
	end
	Fit(f, width)
	f:SetScript("OnSizeChanged", Fit)
	-- Stagger the glimmer so lines on one screen don't blink in step.
	local count = 0
	for _ in pairs(B.lines) do count = count + 1 end
	f.offset = count * 0.37
	B.lines[f] = true
	Watch(f, "line")
	return f
end

local function UpdateTitle(f, t)
	local n = #f.letters
	local age = t - f.born
	local deep = Theme.ramp[1]
	if f.shade ~= deep[1] + deep[2] + deep[3] then   -- accent changed, or first frame
		f.shade = deep[1] + deep[2] + deep[3]
		for _, fs in ipairs(f.letters) do fs:SetShadowColor(deep[1] * 0.8, deep[2] * 0.8, deep[3] * 0.8, 0.85) end
	end
	local scanning = age > 1.5 and ((age - 1.5) % SCAN_EVERY) / SCAN_TIME
	local scanAt = scanning and scanning <= 1 and scanning * (n + 3) - 1.5
	for i, fs in ipairs(f.letters) do
		local c = f.colors[i]
		local power = (age - (i - 1) * POWER_STEP) / POWER_TIME
		local r, g, b
		if power <= 0 then
			r, g, b = c[1] * 0.24, c[2] * 0.24, c[3] * 0.24
		else
			local light = power < 1 and 1 - power or 0
			if scanAt then light = max(light, 1 - abs(i - scanAt) / 1.5) end
			local breath = i <= 3 and 0.94 + 0.06 * sin(t * 1.6 - i * 0.7) or 1
			r, g, b = (c[1] + (ICE[1] - c[1]) * light) * breath, (c[2] + (ICE[2] - c[2]) * light) * breath, c[3] + (ICE[3] - c[3]) * light
		end
		local ink = (Step(r) * 256 + Step(g)) * 256 + Step(b)
		if fs.shyInk ~= ink then
			fs.shyInk = ink
			fs:SetTextColor(r, g, b)
		end
	end
end

local SHEEN_EVERY, SHEEN_TIME = 6, 0.9   -- how often a sheen crosses the icon, and how long it takes

local function UpdateEmblem(f, t)
	local size = f:GetWidth()
	if f.glowSize ~= size then
		f.glowSize = size
		f.glow:SetSize(size * 1.9, size * 1.9)
	end
	local r, g, b = Ramp(0.3)
	local a = 0.36 + 0.12 * sin(t * 1.2)
	local tint = ((Step(r) * 256 + Step(g)) * 256 + Step(b)) * 256 + Step(a)
	if f.tint ~= tint then
		f.tint = tint
		f.glow:SetVertexColor(r, g, b, a)
	end
	local sweep = ((t - f.delay) % SHEEN_EVERY) / SHEEN_TIME
	if sweep <= 1 then
		if f.sheenSize ~= size then
			f.sheenSize = size
			f.sheen:SetSize(size, size)
		end
		f.sheen:SetPoint("CENTER", f, "CENTER", (sweep * 2 - 1) * size, 0)
		f.sheenAlpha = sin(pi * sweep) * 0.4
		f.sheen:SetAlpha(f.sheenAlpha)
	elseif f.sheenAlpha ~= 0 then
		f.sheenAlpha = 0
		f.sheen:SetAlpha(0)
	end
end

local GLIMMER_EVERY, GLIMMER_WIDTH = 2.6, 0.3   -- in line lengths: spacing between glimmers, and their width

-- A line at rest: each segment its color along the ramp, its alpha by the taper; nothing lit.
local function PaintLine(f)
	local n = #f.segs
	f.base = f.base or {}
	for i, seg in ipairs(f.segs) do
		local u = (i - 0.5) / n
		local c = f.base[i] or {}
		f.base[i] = c
		c[1], c[2], c[3] = Ramp(u * 0.7)
		c[4] = f.solid and 1 or sin(pi * u) ^ 0.7
		seg:SetVertexColor(c[1], c[2], c[3], c[4])
	end
	f.lo, f.hi = n + 1, 0
end

-- Only the segments the glimmer is on now (lo to hi), or was on last frame, are colored again.
local function UpdateLine(f, t)
	local segs, base = f.segs, f.base
	local n = #segs
	local at = (t * 0.3 + f.offset) % GLIMMER_EVERY - GLIMMER_WIDTH
	local lo = max(1, math.ceil((at - GLIMMER_WIDTH) * n + 0.5))
	local hi = min(n, floor((at + GLIMMER_WIDTH) * n + 0.5))
	local from, to = lo, hi
	if f.lo <= f.hi then from, to = min(lo, f.lo), max(hi, f.hi) end
	for i = from, to do
		local c = base[i]
		local light = 0
		if i >= lo and i <= hi then light = max(0, 1 - abs((i - 0.5) / n - at) / GLIMMER_WIDTH) ^ 2 * 0.75 end
		segs[i]:SetVertexColor(c[1] + (ICE[1] - c[1]) * light, c[2] + (ICE[2] - c[2]) * light, c[3] + (ICE[3] - c[3]) * light, c[4])
	end
	f.lo, f.hi = lo, hi
end

local UPDATE = { title = UpdateTitle, emblem = UpdateEmblem, line = UpdateLine }
local REST = {
	title = function(f) UpdateTitle(f, GetTime()) end,
	emblem = function(f) UpdateEmblem(f, GetTime()) end,
	line = PaintLine,
}

local awake = {}   -- piece -> its update, while it shows
B.driver = CreateFrame("Frame")
B.driver:Hide()
B.driver:SetScript("OnUpdate", Shy.Clocked("brand: animation", function(self)
	local t = GetTime()
	for f, update in pairs(awake) do
		if f:IsVisible() then update(f, t) else awake[f] = nil end
	end
	if not next(awake) then self:Hide() end
end))

local function Wake(f)
	awake[f] = UPDATE[f.shyKind]
	B.driver:Show()
end

local function Sleep(f)
	awake[f] = nil
end

Watch = function(f, kind)
	f.shyKind = kind
	REST[kind](f)
	f:HookScript("OnShow", Wake)
	f:HookScript("OnHide", Sleep)
	if f:IsVisible() then Wake(f) end
end

-- An accent change: every piece at rest in the new colors (one showing goes on from there).
Shy:On("SHY_THEME", function()
	for _, set in ipairs({ B.titles, B.emblems, B.lines }) do
		for f in pairs(set) do REST[f.shyKind](f) end
	end
end)

-- Login splash

local SPLASH_IN, SPLASH_HOLD, SPLASH_OUT = 0.45, 3.6, 1.0

local function EaseOutBack(x)
	local c = 1.9
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

function B.ShowSplash()
	if B.splash then B.splash:Hide() end

	local ICON = 72
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("HIGH")
	f:SetSize(420, 220)
	f:SetPoint("TOP", 0, -130)
	B.splash = f

	local emblem = B.CreateEmblem(f, Shy.core.mark, ICON)
	emblem:SetPoint("CENTER", f, "TOP", 0, -ICON / 2 - 10)

	local flash = f:CreateTexture(nil, "OVERLAY")
	flash:SetTexture(B.GLOW)
	flash:SetBlendMode("ADD")
	flash:SetVertexColor(Ramp(1))
	flash:SetPoint("CENTER", f, "TOP", 0, -ICON / 2 - 10)
	flash:SetAlpha(0)

	local title = B.CreateTitle(f, "", 36)
	title:SetPoint("TOP", 0, -ICON - 34)

	local line = B.CreateLine(f, 300, 2)
	line:SetPoint("TOP", title, "BOTTOM", 0, -4)

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	sub:SetPoint("TOP", line, "BOTTOM", 0, -8)
	local core = Shy.core
	local text = core.tagline
	if not text then
		local n = 0
		for _, a in ipairs(Shy.order) do
			if not a.internal then n = n + 1 end
		end
		text = n == 1 and "1 addon loaded" or (n .. " addons loaded")
	end
	if core.version then text = text .. "  |cff888888v" .. core.version .. "|r" end
	sub:SetText(text)

	f:SetScript("OnHide", function()
		B.titles[title], B.lines[line], B.emblems[emblem] = nil, nil, nil
	end)

	local start = GetTime()
	f:SetAlpha(0)
	f:SetScript("OnUpdate", function(self)
		local e = GetTime() - start
		local pop
		if e < SPLASH_IN then
			self:SetAlpha(e / SPLASH_IN)
			pop = EaseOutBack(e / SPLASH_IN)
		elseif e < SPLASH_IN + SPLASH_HOLD then
			self:SetAlpha(1)
			pop = 1
		elseif e < SPLASH_IN + SPLASH_HOLD + SPLASH_OUT then
			local x = (e - SPLASH_IN - SPLASH_HOLD) / SPLASH_OUT
			self:SetAlpha(1 - x)
			self:SetPoint("TOP", 0, -130 + x * 30)
			pop = 1
		else
			self:Hide()
			return
		end
		emblem:SetSize(ICON * pop, ICON * pop)
		local fx = (e - SPLASH_IN * 0.6) / 0.7   -- a flash as the emblem lands
		if fx > 0 and fx < 1 then
			flash:SetSize(ICON * (1.5 + fx * 5), ICON * (1.5 + fx * 5))
			flash:SetAlpha(1 - fx)
		else
			flash:SetAlpha(0)
		end
	end)
	f:Show()
end
