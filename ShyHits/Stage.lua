-- The numbers: pooled texts animated in lanes (anchor points; Where.lua places them).
-- A number moves by what it tells of: a hit is knocked off the plate into a row of its own and is still
-- while it is read, a critical strike slams in with a burst and trembles, a heal swells and floats up,
-- harm to you falls away, the blow that killed is struck again (S.Final), and what you gain rises
-- with a gleam.
-- Nothing here measures text: regions anchored to nameplates are restricted, so line
-- height comes from font size. Amounts may be secret: S.Add passes them to SetFormattedText unread.

local ADDON, ns = ...
local UI, B, Theme = Shy.UI, Shy.Brand, Shy.Theme
local Burst = ns.Burst   -- the light of a hard blow (Burst.lua)
local max, min, floor, ceil, exp, cos, sin = math.max, math.min, math.floor, math.ceil, math.exp, math.cos, math.sin
local TURN = 2 * math.pi

local S = {}
ns.Stage = S

S.SIZE = 18           -- font size of a plain hit at 100%
-- size: relative to a hit, none under 0.9 (the least is still easily read); life: seconds; pop: the scale it arrives at, sprung down to its own (`tau`:
-- seconds for the spring to die down, `hz`: its swing); flash: seconds cooling from white, with a light
-- behind it of `glow` alpha; hold: seconds still before rising; shake: how far it trembles as it lands,
-- in font sizes; slam: it lands where it stands, with a burst.
S.KIND = {
	hit    = { size = 1,    life = 1.25, pop = 1.70, tau = 0.030, hz = 6, flash = 0.12, glow = 0.30 },
	crit   = { size = 2.0,  life = 2.00, pop = 2.60, tau = 0.040, hz = 5, flash = 0.40, glow = 0.60, hold = 0.50, shake = 0.11, slam = true },
	glance = { size = 0.90, life = 1.00, pop = 1.30, tau = 0.028, hz = 6 },
	word   = { size = 0.90, life = 0.95, pop = 1.25, tau = 0.028, hz = 6 },
	-- What you gain: it swells from `pop`, lit a moment, and rises `rise` as it goes. Experience (`gain`)
	-- and the lesser ones (`note`: coin, reputation, a skill, honor) are the least size there is, the lesser lit less;
	-- they are seen for standing over every blow, clear of where a crit lands (S.Landing).
	gain   = { size = 0.90, life = 1.40, pop = 0.60, tau = 0.05, hz = 3.5, flash = 0.30, glow = 0.45, rise = 26, gain = true },
	note   = { size = 0.90, life = 1.40, pop = 0.60, tau = 0.05, hz = 3.5, flash = 0.30, glow = 0.35, rise = 26, gain = true },
}
-- Calm motion: crit size, and the share of the arrival pop kept.
local CALM = { crit = 1.55, pop = 0.35 }

local LINE = 1.1      -- line height, in font sizes
local IN = 0.04       -- fade-in seconds of a number that doesn't strike
local OUT = 0.35      -- share of life spent fading out
local SETTLE = 5.5    -- a spring is at rest after this many of its `tau`
local FOLLOW = 28     -- how fast a stacked number moves to its new slot
local MOST = 6        -- numbers per lane; past that the oldest fades in HURRY seconds
local HURRY = 0.18
local TAIL = 0.72     -- healer name size, relative to its number
local TAIL_GAP = 4
local THICK = 26      -- from this font size the outline is the thick one
-- A number is placed in steps of 1 / FINE of a unit (a sixth of a screen pixel): it is given a new place
-- only when it has moved one, so a number that stands, or creeps, asks nothing of the game.
local FINE = 8

-- A lane that fans gives each blow's number a row of its own to stand in, so no two cover each other:
-- rows a `pitch` apart (font sizes of a hit) up from the lane's foot, `out` from it by row (a centered
-- lane `mid` more), the lowest free one taken. A row is free again once its number is `free` of
-- the way through its fading. With more than `busy` numbers up in a lane the older ones leave within
-- `hurry` seconds, so a flurry stays a short ladder; with every row taken, the one a newcomer is given
-- is cleared within `bump`.
local ROWS = { most = 4, pitch = 1.3, mid = 12, free = 0.8, busy = 3, hurry = 0.3, bump = 0.1,
	out = { 24, 34, 28, 38 } }
-- A blow's number is knocked out along its row from the lane's foot (from `start` of the way), most of
-- the way in the first tenth of a second (`quick`), and is still while it is read; fading, it sinks, and
-- harm to you falls away.
local FLY = { start = 0.3, quick = 16, sink = 6, fall = 18, there = 0.45 }   -- `there`: seconds until it has arrived
-- What doesn't strike (a heal, a gain): it fades in, swelling from under its size (`deep`: a critical
-- heal), is seen a moment longer, and floats up `rise` over its life, in a column: the newest at the
-- lane's foot, the older stepped up over it, so a later one never rises into an earlier.
-- A heal is lit `flash` seconds from white, with a light of `glow` behind it.
local FLOAT = { rise = 15, pop = 0.72, deep = 0.55, tau = 0.05, hz = 3.5, fadeIn = 0.09, life = 1.25, flash = 0.35, glow = 0.45 }
-- Stacking: how far a number climbs over its life.
local RISE, SLAM_RISE = 26, 18
-- The tremble of a landing: seconds to die down, its swing across and up and down, the share of it up and
-- down, the least worth drawing; harm to you trembles too (`hurt`, in font sizes), a crushing blow more.
local SHAKE = { tau = 0.07, hz = 19, hzUp = 27, up = 0.5, least = 0.25, hurt = 0.14, more = 1.3 }
-- The light behind a number: its size in font sizes, and how it spreads as it fades.
local GLOW = { w = 4.4, h = 2.6, from = 0.55, grows = 0.75 }
-- The blow that killed: one that landed within `within` seconds is struck again: it leaps (`pop`) and
-- stays larger (`grow`; `slam`: one that is large already), white-hot for `flash` seconds with a light
-- of `glow`, trembling (`shake`, font sizes), and stays `stay` seconds more.
local KILL = { within = 0.6, pop = 1.75, grow = 1.7, slam = 1.25, tau = 0.045, hz = 4.5, flash = 0.5, glow = 0.7, shake = 0.2, stay = 1.5 }
-- How much longer or shorter a number lives for being larger or smaller than usual.
local WEIGH = { least = 0.9, most = 1.15 }
-- How far over its parent a number is drawn: what you gain over every blow, so a crit never covers it.
local LAYER = { blow = 1, gain = 20 }

local FOOT = { LEFT = "BOTTOMLEFT", RIGHT = "BOTTOMRIGHT", CENTER = "BOTTOM" }

-- Default parent for numbers: above the world and nameplates, below windows.
local stage = CreateFrame("Frame", nil, UIParent)
stage:SetAllPoints()
stage:SetFrameStrata("LOW")
S.frame = stage
-- Never hidden, so OnUpdate always runs.
local driver = CreateFrame("Frame")
S.driver = driver

local pool = {}
local lanes = {}      -- lanes with live numbers
S.lanes = lanes

-- The font of each size in each lettering, asked of the kit once; a text already in it is left as it is.
-- Numbers and the game's words wear the theme's lettering where that is wanted; a name a player wrote never does.
local fonts = {}

local function FontOf(size, plain)
	local shown = (not plain and ns.T.db.lettering) and Theme.FontShown() or "plain"
	local set = fonts[shown]
	if not set then
		set = {}
		fonts[shown] = set
	end
	local font = set[size]
	if not font then
		local flags = size >= THICK and "THICKOUTLINE" or "OUTLINE"
		if shown == "plain" then
			font = UI.NameFont(size, flags)
		else
			local files, face = Theme.FontFiles(shown, size)
			font = UI.NameFont(size, flags, files, face)
		end
		set[size] = font
	end
	return font
end

-- Sets a text in the numbers' font at a size; `plain`: never the theme's lettering.
function S.Face(fontString, size, plain)
	local font = FontOf(size, plain)
	if fontString.shyFont == font then return end
	fontString.shyFont = font
	fontString:SetFontObject(font)
	local deep = size >= THICK and 2 or 1
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(deep, -deep)
end
local Face = S.Face

local function NewEntry()
	local e = CreateFrame("Frame", nil, stage)
	e:SetSize(1, 1)
	e.text = e:CreateFontString(nil, "OVERLAY")
	e.text:SetWordWrap(false)
	e.tail = e:CreateFontString(nil, "OVERLAY")
	e.tail:SetWordWrap(false)
	e.glow = e:CreateTexture(nil, "BACKGROUND")
	e.glow:SetTexture(B.GLOW)
	e.glow:SetBlendMode("ADD")
	e.glow:SetPoint("CENTER", e.text, "CENTER", 0, 0)
	e.glow:Hide()
	return e
end

local function Release(e)
	if Burst then Burst.Stop(e) end
	e.lane = nil
	e:Hide()
	e:ClearAllPoints()
	pool[#pool + 1] = e
end

-- Made before the first fight needs them, so its first hits make nothing: numbers waiting in the pool,
-- the lights of a few bursts, and the font of every size a number takes at each of the sizes given (each
-- kind, calm or not, and a healer's name after it).
local READY, BURSTS = 14, 5
function S.Warm(...)
	for _ = #pool + 1, READY do Release(NewEntry()) end
	if Burst and ns.T.db.motion ~= "calm" then Burst.Warm(BURSTS) end   -- (kept calm, nothing bursts)
	for i = 1, select("#", ...) do
		local grow = select(i, ...)
		if type(grow) == "number" and grow > 0 then
			for _, def in pairs(S.KIND) do
				for calm = 0, 1 do
					local size = max(6, floor(S.SIZE * ((calm == 1 and def.slam) and CALM.crit or def.size) * grow + 0.5))
					FontOf(size)
					FontOf(max(6, floor(size * TAIL + 0.5)), true)
				end
			end
		end
	end
end

-- A scale sprung from `pop` to 1: over it at once, a little under, then its own.
local function Spring(pop, tau, hz, t)
	return 1 + (pop - 1) * exp(-t / tau) * cos(TURN * hz * t)
end

-- Where a number that has a row stands from its lane's foot, `t` seconds in.
local function Flight(e, t)
	local x, y = e.sx, e.sy
	if e.move == "fly" and t < FLY.there then x = x * (FLY.start + (1 - FLY.start) * (1 - exp(-FLY.quick * t))) end
	if t > e.sinks then
		local w = (t - e.sinks) / e.fade
		y = y - e.drop * w * w * w
	end
	return x, y
end

-- The lowest rows of a lane's side that are free, `need` of them together; if none are, the ones free
-- soonest. Returns the first row, the side's rows (row -> when it is free), and whether they were taken.
local function Row(lane, side, need, now)
	local taken = side < 0 and lane.left or lane.right
	if not taken then
		taken = {}
		if side < 0 then lane.left = taken else lane.right = taken end
	end
	local best, soonest
	for r = 1, ROWS.most - need + 1 do
		local latest = 0
		for k = r, r + need - 1 do
			local t = taken[k]
			if t and t > latest then latest = t end
		end
		if latest <= now then return r, taken end
		if not soonest or latest < soonest then best, soonest = r, latest end
	end
	return best, taken, true
end

-- A number keeps its rows until it has mostly faded (said again after its life is changed).
local function Hold(e)
	if not e.rows then return end
	local frees = e.born + e.life - e.fade * (1 - ROWS.free)
	for k = e.row, e.row + e.need - 1 do e.rows[k] = frees end
end

-- A number is made to leave within `within` seconds (the blow that killed stays its time).
local function Leave(e, now, within)
	local t = now - e.born
	if e.final or e.life <= t + within then return end
	e.life, e.fade = t + within, within
	e.sinks = e.life - within
	Hold(e)
end

-- The light behind a number, as it is at the instant.
local function Lit(e, bright)
	e.lit, e.bright = true, bright
	e.wide = e.size * e.rest
	e.glow:SetSize(e.wide * GLOW.w * GLOW.from, e.wide * GLOW.h * GLOW.from)
	e.glow:SetVertexColor(e.r, e.g, e.b)
	e.glow:SetAlpha(bright)
	e.glow:Show()
end

-- A number's scale, color and light while it is still arriving (or struck again as the blow that killed).
local function Arrive(e, t, now)
	local done = t >= e.snap
	local s = done and 1 or Spring(e.pop, e.tau, e.hz, t)
	if e.again then
		local u = now - e.again
		if u < KILL.tau * SETTLE then
			s = s * Spring(KILL.pop, KILL.tau, KILL.hz, u)
			done = false
		else
			e.again = nil
		end
	end
	s = s * e.rest
	if s ~= e.scale then
		e.scale = s
		e.text:SetTextScale(s)
	end
	if e.flash then
		local f = (now - e.hot) / e.flash
		if f >= 1 then
			e.flash = nil
			e.text:SetTextColor(e.r, e.g, e.b)
			if e.lit then
				e.lit = false
				e.glow:Hide()
			end
		else
			done = false
			e.text:SetTextColor(1 + (e.r - 1) * f, 1 + (e.g - 1) * f, 1 + (e.b - 1) * f)
			if e.lit then
				local q = 1 - f
				local wide = GLOW.from + GLOW.grows * (1 - q * q)
				e.glow:SetAlpha(e.bright * q * q)
				e.glow:SetSize(e.wide * GLOW.w * wide, e.wide * GLOW.h * wide)
			end
		end
	end
	e.settled = done
end

local function Step(_, dt)
	local now = GetTime()
	local follow = min(1, dt * FOLLOW)
	for i = #lanes, 1, -1 do
		local lane = lanes[i]
		local list = lane.list
		local to, rel, lx, ly = lane.to, lane.rel, lane.x, lane.y
		local over   -- top of the stacked number below this one
		for j = #list, 1, -1 do   -- newest first
			local e = list[j]
			local t = now - e.born
			if t >= e.life then
				table.remove(list, j)
				Release(e)
			else
				local x, y = 0, nil
				if e.move then
					x, y = Flight(e, t)
				else
					local v = t > e.hold and min(1, (t - e.hold) / (e.span - e.hold)) or 0
					local want = e.rise * (1 - (1 - v) * (1 - v))
					if over and want < over then want = over end
					y = e.y
					if e.fresh then
						y, e.fresh = want, false
					elseif y ~= want then
						y = y + (want - y) * follow
					end
					over = want + e.height
					e.y = y
				end
				if e.shake then
					local u = t - e.lands
					if u >= 0 then
						local far = e.shake * exp(-u / SHAKE.tau)
						if far < SHAKE.least then
							e.shake = nil
						else
							x = x + far * sin(TURN * SHAKE.hz * u)
							y = y + far * SHAKE.up * sin(TURN * SHAKE.hzUp * u + 1)
						end
					end
				end
				e.ox, e.oy = x, y
				-- Its one point is given again (which replaces it) only where it has moved, and its alpha as it changes.
				x, y = floor((lx + x) * FINE + 0.5) / FINE, floor((ly + y) * FINE + 0.5) / FINE
				if e.px ~= x or e.py ~= y or e.to ~= to or e.rel ~= rel then
					e.px, e.py, e.to, e.rel = x, y, to, rel
					e:SetPoint("CENTER", to, rel, x, y)
				end
				local alpha = (e.life - t) / e.fade
				if e.fadeIn then
					local coming = t / e.fadeIn
					if coming < alpha then alpha = coming end
				end
				if alpha > 1 then alpha = 1 elseif alpha < 0 then alpha = 0 end
				if alpha ~= e.alpha then
					e.alpha = alpha
					e:SetAlpha(alpha)
				end
				if not e.settled then Arrive(e, t, now) end
				if e.bursts and not Burst.Step(e, now) then e.bursts = false end
			end
		end
		if #list == 0 then
			lane.live = false
			table.remove(lanes, i)
		end
	end
	if #lanes == 0 then driver:SetScript("OnUpdate", nil) end
end
local Stepped = Shy.Clocked("hits: the numbers, a frame", Step)

-- Lane fields, set by its owner at any time: to, rel, x, y (anchor); justify ("LEFT" |
-- "RIGHT" | "CENTER"); fan (-1 its rows stand to the left, 1 to the right, 0 to either side turn
-- about, nil one column stepping up; what doesn't strike is always a column); tone ("deal" | "hurt" | "heal" | "gain": what its numbers tell
-- of, default "deal"); parent (default: the stage); scale (multiplies the size setting).
function S.Lane(tone)
	return { list = {}, x = 0, y = 0, justify = "CENTER", scale = 1, turn = 0, tone = tone }
end

-- Adds a number. kind: a key of S.KIND; grow: how large beside others of its kind (nil: as they
-- are); pattern and values as for string.format.
-- Returns the entry (for S.Tail), or nil when the lane has no anchor.
function S.Add(lane, kind, grow, r, g, b, pattern, ...)
	if not lane.to then return nil end
	local def = S.KIND[kind]
	local calm = ns.T.db.motion == "calm"
	local scale = ns.T.db.size * lane.scale
	local size = max(6, floor(S.SIZE * ((calm and def.slam) and CALM.crit or def.size) * scale + 0.5))
	local rest = grow or 1
	local tone = lane.tone or "deal"
	local heal = tone == "heal" or tone == "gain"   -- what doesn't strike: it comes in softly and floats
	local now = GetTime()
	local e = table.remove(pool) or NewEntry()
	local parent = lane.parent or stage
	e:SetParent(parent)
	e:SetFrameLevel(parent:GetFrameLevel() + (tone == "gain" and LAYER.gain or LAYER.blow))
	e.lane, e.def, e.kind, e.size, e.rest = lane, def, kind, size, rest
	e.height = size * LINE * rest
	e.r, e.g, e.b = r, g, b
	e.y, e.ox, e.oy, e.fresh, e.settled, e.again, e.final = 0, 0, 0, true, false, nil, false
	e.pop, e.tau, e.hz = def.pop, def.tau, def.hz
	e.flash, e.hot = def.flash, now
	e.hold, e.shake, e.fadeIn, e.move, e.rows, e.bursts = 0, nil, nil, nil, nil, false
	local life = def.life * max(WEIGH.least, min(WEIGH.most, rest))

	local rows = not calm and lane.fan ~= nil
	if calm then
		e.pop, e.fadeIn = 1 + (def.pop - 1) * CALM.pop, IN
		if not def.slam then e.flash = nil end
	elseif heal then
		e.fadeIn = FLOAT.fadeIn
		if tone == "heal" and not def.slam then e.flash = FLOAT.flash end
		e.pop, e.tau, e.hz = def.slam and FLOAT.deep or def.gain and def.pop or FLOAT.pop, FLOAT.tau, FLOAT.hz
		life = life * FLOAT.life
	elseif rows and not def.slam then
		e.move = "fly"
		if tone == "hurt" and kind ~= "word" then e.shake = SHAKE.hurt * size end
	else
		if rows then e.move = "land" else e.hold = def.hold or 0 end
		if def.shake then e.shake = def.shake * size * (tone == "hurt" and SHAKE.more or 1) end
	end
	e.born, e.life, e.span, e.fade = now, life, life, life * OUT
	e.sinks = life - e.fade
	e.snap, e.lands = e.tau * SETTLE, 1 / (4 * e.hz)

	if e.move then
		lane.turn = lane.turn + 1
		local side = lane.fan
		if side == 0 then side = lane.turn % 2 == 0 and 1 or -1 end
		local pitch = S.SIZE * ROWS.pitch * scale
		e.need = max(1, min(ROWS.most, ceil(e.height / pitch - 0.15)))
		local crowded
		e.row, e.rows, crowded = Row(lane, side, e.need, now)
		if crowded then
			-- Whatever still stands in its rows makes way.
			for _, other in ipairs(lane.list) do
				if other.rows == e.rows and other.row < e.row + e.need and other.row + other.need > e.row then Leave(other, now, ROWS.bump) end
			end
		end
		local out = ROWS.out[e.row] + (lane.justify == "CENTER" and ROWS.mid or 0)
		e.sx, e.sy = side * out * scale, (e.row - 1) * pitch
		e.drop = (tone == "hurt" and FLY.fall or FLY.sink) * scale
		Hold(e)
		e.ox, e.oy = e.move == "fly" and e.sx * FLY.start or e.sx, e.sy
	elseif heal and not calm then
		e.rise = (def.rise or FLOAT.rise) * scale
	else
		e.rise = ((def.slam and not calm) and SLAM_RISE or RISE) * scale
	end

	local text = e.text
	Face(text, size)
	if e.justify ~= lane.justify then
		e.justify = lane.justify
		text:ClearAllPoints()
		text:SetPoint(FOOT[lane.justify], e, "CENTER", 0, 0)
	end
	text:SetFormattedText(pattern, ...)
	if e.flash then text:SetTextColor(1, 1, 1) else text:SetTextColor(r, g, b) end
	e.scale = rest * e.pop
	text:SetTextScale(e.scale)
	e.tail:Hide()
	if e.flash and not calm then
		local mends = tone == "heal"
		Lit(e, (mends and not def.slam) and FLOAT.glow or def.glow)
		-- A slam bursts as it lands; a critical heal blooms, with a pillar of light; a heal as large as
		-- your usual one or larger sends up motes.
		if Burst and def.slam then
			Burst.Play(e, heal and "bloom" or "crit", r, g, b, heal and 0 or e.lands)
			e.bursts = true
		elseif Burst and mends and rest >= 1 then
			Burst.Play(e, "mend", r, g, b)
			e.bursts = true
		end
	else
		e.lit = false
		e.glow:Hide()
	end
	e.px, e.py = floor((lane.x + e.ox) * FINE + 0.5) / FINE, floor((lane.y + e.oy) * FINE + 0.5) / FINE
	e.to, e.rel = lane.to, lane.rel
	e:SetPoint("CENTER", e.to, e.rel, e.px, e.py)
	-- A blow is there the instant it lands; only what doesn't strike comes in softly.
	e.alpha = e.fadeIn and 0 or 1
	e:SetAlpha(e.alpha)
	e:Show()

	local list = lane.list
	list[#list + 1] = e
	-- Too many up: the oldest of them leaves (the blow that killed stays).
	local old = list[#list - (e.move and ROWS.busy or MOST)]
	if old then Leave(old, now, e.move and ROWS.hurry or HURRY) end
	if not lane.live then
		lane.live = true
		lanes[#lanes + 1] = lane
	end
	driver:SetScript("OnUpdate", Stepped)
	return e
end

-- How tall the blow that killed stands where a crit lands, at a size setting: what is gained there rises over it.
function S.Landing(scale)
	return S.SIZE * S.KIND.crit.size * KILL.slam * scale
end

-- Smaller text after a number (the healer's name); before it in a right-justified lane.
function S.Tail(e, r, g, b, pattern, ...)
	if not e or not e.lane then return end   -- already released
	local tail = e.tail
	Face(tail, max(6, floor(e.size * TAIL + 0.5)), true)
	tail:ClearAllPoints()
	if e.lane.justify == "RIGHT" then
		tail:SetPoint("BOTTOMRIGHT", e.text, "BOTTOMLEFT", -TAIL_GAP, 1)
	else
		tail:SetPoint("BOTTOMLEFT", e.text, "BOTTOMRIGHT", TAIL_GAP, 1)
	end
	tail:SetFormattedText(pattern, ...)
	tail:SetTextColor(r, g, b)
	tail:Show()
end

-- The blow that killed: of the lanes given, the newest number, if it has only just landed, is struck
-- again: it leaps and stays larger, white-hot, a cut of light through it, a shock and bits thrown from
-- it, and it stays to be seen. Returns it, or nil.
function S.Final(...)
	if ns.T.db.motion == "calm" then return nil end
	local now, e = GetTime(), nil
	for i = 1, select("#", ...) do
		local lane = select(i, ...)
		local list = lane and lane.list
		-- Its newest number that is a blow (a dodge after it is not).
		for j = list and #list or 0, 1, -1 do
			local one = list[j]
			if now - one.born > KILL.within or one.final then break end
			if one.kind ~= "word" then
				if not e or one.born > e.born then e = one end
				break
			end
		end
	end
	if not e then return nil end
	local t = now - e.born
	local grow = e.def.slam and KILL.slam or KILL.grow
	e.again, e.settled, e.final = now, false, true
	e.rest = e.rest * grow
	e.flash, e.hot = KILL.flash, now
	e.shake, e.lands = KILL.shake * e.size * grow, t
	e.life = max(e.life, t + KILL.stay)
	e.span, e.sinks = e.life, e.life - e.fade
	if e.rows then
		e.height = e.height * grow
		e.need = max(e.need, min(ROWS.most - e.row + 1, ceil(e.height / (S.SIZE * ROWS.pitch * ns.T.db.size * e.lane.scale) - 0.15)))
		Hold(e)
	end
	e.text:SetTextColor(1, 1, 1)
	Lit(e, KILL.glow)
	if Burst then
		Burst.Play(e, e.def.slam and "slain" or "kill", e.r, e.g, e.b, 0, e.size * grow)
		e.bursts = true
	end
	Arrive(e, t, now)   -- in the frame its unit died, not the next
	return e
end

-- The lane's anchor frame is going away (a nameplate losing its unit): live numbers
-- carry on. Re-anchors to the screen if the newest number can be measured (on a
-- nameplate it usually can't), else to the fallback `to`, `rel`, x, y when given.
function S.Detach(lane, to, rel, x, y)
	local newest = lane.list[#lane.list]
	if not newest then
		-- Nothing up in it yet: it stands on the fallback, for what is still to come (a kill's gains).
		if to then lane.to, lane.rel, lane.x, lane.y = to, rel, x, y end
		return
	end
	local ok, cx, cy = pcall(newest.GetCenter, newest)
	if ok and cx ~= nil and cy ~= nil and not issecretvalue(cx) and not issecretvalue(cy) then
		-- The lane's anchor is the number's position less how far it has travelled.
		lane.to, lane.rel, lane.x, lane.y = UIParent, "BOTTOMLEFT", cx - newest.ox, cy - newest.oy
	elseif to then
		lane.to, lane.rel, lane.x, lane.y = to, rel, x, y
	end
end

function S.Clear()
	for i = #lanes, 1, -1 do
		local lane = lanes[i]
		for j = #lane.list, 1, -1 do Release(table.remove(lane.list, j)) end
		lane.left, lane.right = nil, nil
		lane.live = false
		lanes[i] = nil
	end
	driver:SetScript("OnUpdate", nil)
end

function S.Count()
	local n = 0
	for _, lane in ipairs(lanes) do n = n + #lane.list end
	return n
end
