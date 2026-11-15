-- The light of a blow that lands hard: a flash at the instant, a shock spreading from it, bits thrown
-- off, and through the number of the blow that killed, a cut. And the light of a heal, which is no blow:
-- motes that drift up from it, and for a critical one a soft ring and a pillar of light. Drawn on the
-- number's own frame under its letters, added over the world, in its color. Stage.lua plays and steps it.
-- A burst is a set of textures kept apart from the numbers (few numbers burst): made before a fight
-- (X.Warm), moved onto a number as it bursts, and put back when its last light has gone.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyHits\\Media\\"
local exp, sin, cos, random = math.exp, math.sin, math.cos, math.random
local TURN = 2 * math.pi

local X = {}
ns.Burst = X

-- What each kind throws, in the number's font sizes: the flash and the shock across, how many bits, the
-- cut's length. A heal's: how many motes, a slow soft shock (`soft`), the pillar's height.
X.KIND = {
	crit  = { spark = 3.4, ring = 4.8, shards = 6 },
	mend  = { motes = 4 },                                        -- a heal as large as your usual one, or larger
	bloom = { ring = 4.6, soft = true, motes = 8, pillar = 7.5 },   -- a critical heal
	kill  = { spark = 4.6, ring = 6.6, shards = 10, slash = 8.5 },
	slain = { spark = 5.6, ring = 7.8, shards = 13, slash = 10.5 },   -- killed by a critical strike
}
X.MOST = 13   -- bits a number can throw

-- The flash: seconds, the share of its size it starts at.
local SPARK = { life = 0.13, from = 0.45 }
-- The shock: seconds, its first size, how strong; and the same for a soft one.
local RING = { life = 0.42, from = 0.22, alpha = 0.65, softLife = 0.75, softAlpha = 0.5 }
-- The cut: seconds, of them to its full length, its first length, its height beside its length, its lean
-- (from..to by chance, to either side).
local SLASH = { life = 0.30, grow = 0.06, from = 0.2, tall = 0.11, tilt = { 0.12, 0.34 } }
-- A bit: seconds, speed and length (font sizes), each from..to by chance; its thickness beside its length;
-- how the air slows it; how it falls; how much more of them go up than down.
local SHARD = { life = { 0.32, 0.66 }, speed = { 7, 16 }, long = { 1.0, 2.0 }, thick = 0.3, drag = 3.6, fall = 17, up = 0.35 }

-- The pillar (the cut's art stood on end, rising from the number): seconds, of them to its full height,
-- its first height, its width beside its height, how far up its middle stands (of its height), how strong.
local PILLAR = { life = 0.65, grow = 0.14, from = 0.25, wide = 0.2, lift = 0.3, alpha = 0.7 }
-- A mote: seconds, how fast it rises and how large it is (font sizes), each from..to by chance; how far to
-- either side of the number's middle it starts; its sway and how fast; how the air slows it; seconds
-- coming in; how strong.
local MOTE = { life = { 0.7, 1.2 }, rise = { 2.4, 5.0 }, size = { 0.9, 1.6 }, across = 1.5, sway = 0.22, swing = 5,
	slow = 1.6, fadeIn = 0.1, alpha = 0.85 }
local ART = { [false] = MEDIA .. "Shard", [true] = Shy.Brand.GLOW }   -- a bit's art: thrown, or a mote

local function Between(pair)
	return pair[1] + (pair[2] - pair[1]) * random()
end

-- Sets wait here, out of sight, until a number bursts.
local holder = CreateFrame("Frame")
holder:Hide()
local sets = {}

local function Light(file, layer)
	local t = holder:CreateTexture(nil, "BACKGROUND", nil, layer)
	t:SetTexture(MEDIA .. file)
	t:SetBlendMode("ADD")
	t:Hide()
	t.on = false
	return t
end

local function NewSet()
	local fx = { shards = {}, vx = {}, vy = {}, life = {}, long = {}, turn = {}, n = 0, on = false, motes = false }
	fx.ring = Light("Ring", 1)
	fx.slash = Light("Slash", 2)
	fx.spark = Light("Spark", 3)
	for i = 1, X.MOST do fx.shards[i] = Light("Shard", 0) end
	return fx
end

-- Sets made ahead, so a fight's first hard blows make nothing.
function X.Warm(n)
	for _ = #sets + 1, n do sets[#sets + 1] = NewSet() end
end

-- A light shown or put away only where that is a change.
local function Show(t)
	if not t.on then
		t.on = true
		t:Show()
	end
end
local function Hide(t)
	if t.on then
		t.on = false
		t:Hide()
	end
end

local function Move(t, e)
	t:SetParent(e)
	t:SetPoint("CENTER", e.text, "CENTER", 0, 0)
end

-- A set's lights moved onto a number, round its text's middle.
local function Onto(fx, e)
	Move(fx.ring, e)
	Move(fx.slash, e)
	Move(fx.spark, e)
	for i = 1, X.MOST do Move(fx.shards[i], e) end
	e.fx = fx
end

-- Plays a kind of X.KIND on a number, in a color, `wait` seconds from now (as its slam lands); `unit`:
-- the font size it is measured in (default: the number's own).
function X.Play(e, kind, r, g, b, wait, unit)
	local def = X.KIND[kind]
	local fx = e.fx
	if not fx then
		fx = table.remove(sets) or NewSet()
		Onto(fx, e)
	end
	unit = unit or e.size
	fx.def, fx.unit, fx.born, fx.on = def, unit, GetTime() + (wait or 0), true
	fx.r, fx.g, fx.b = r, g, b
	Hide(fx.spark)
	Hide(fx.slash)
	Hide(fx.ring)
	fx.ring:SetVertexColor(r, g, b)
	if def.spark then fx.spark:SetRotation(random() * TURN) end
	if def.slash then
		fx.slash:SetRotation(Between(SLASH.tilt) * (random() < 0.5 and -1 or 1))
		fx.slash:SetPoint("CENTER", e.text, "CENTER", 0, 0)
	elseif def.pillar then
		fx.slash:SetRotation(TURN / 4)
	end
	local n = def.shards or def.motes or 0
	local motes = def.motes ~= nil
	if fx.motes ~= motes then
		fx.motes = motes
		for i = 1, X.MOST do fx.shards[i]:SetTexture(ART[motes]) end
	end
	for i = 1, n do
		local s = fx.shards[i]
		if motes then
			-- From somewhere across the number, each at its own pace, swaying out of step with the rest.
			fx.vx[i], fx.vy[i] = (random() * 2 - 1) * MOTE.across * unit, Between(MOTE.rise) * unit
			fx.life[i], fx.long[i], fx.turn[i] = Between(MOTE.life), Between(MOTE.size) * unit, random() * TURN
			s:SetRotation(0)
			s.wide = nil
		else
			-- Round the whole way, each in its own slice of it, more of them thrown up than down.
			local angle = (i - 1 + random()) * TURN / n
			local speed = Between(SHARD.speed) * unit
			fx.vx[i], fx.vy[i] = cos(angle) * speed, (sin(angle) + SHARD.up) * speed
			fx.life[i], fx.long[i] = Between(SHARD.life), Between(SHARD.long) * unit
			s:SetRotation(angle)
		end
		-- Hot at the head of the burst: halfway from its color to white.
		s:SetVertexColor((r + 1) / 2, (g + 1) / 2, (b + 1) / 2)
		Hide(s)
	end
	for i = n + 1, fx.n do Hide(fx.shards[i]) end
	fx.n = n
end

-- A number's burst ended or its number gone: its set is put back for the next.
function X.Stop(e)
	local fx = e.fx
	if not fx then return end
	e.fx, fx.on = nil, false
	Hide(fx.spark)
	Hide(fx.ring)
	Hide(fx.slash)
	for i = 1, fx.n do Hide(fx.shards[i]) end
	sets[#sets + 1] = fx
end

-- A frame of a number's burst. Returns whether any of it is still to come; it puts itself away at its end.
function X.Step(e, now)
	local fx = e.fx
	if not fx then return false end
	local t = now - fx.born
	if t < 0 then return true end
	local def, unit = fx.def, fx.unit
	local live = false

	if def.spark then
		local p = t / SPARK.life
		if p < 1 then
			live = true
			local q = 1 - p
			local wide = def.spark * unit * (SPARK.from + (1 - SPARK.from) * (1 - q * q))
			fx.spark:SetSize(wide, wide)
			-- White at the instant, its color as it goes; fading with it.
			fx.spark:SetVertexColor(1 + (fx.r - 1) * p, 1 + (fx.g - 1) * p, 1 + (fx.b - 1) * p, q)
			Show(fx.spark)
		else
			Hide(fx.spark)
		end
	end

	local p
	if def.ring then
		p = t / (def.soft and RING.softLife or RING.life)
		if p < 1 then
			live = true
			local q = 1 - p
			local wide = def.ring * unit * (RING.from + (1 - RING.from) * (1 - q * q * q))
			fx.ring:SetSize(wide, wide)
			fx.ring:SetAlpha((def.soft and RING.softAlpha or RING.alpha) * q * q)
			Show(fx.ring)
		else
			Hide(fx.ring)
		end
	end

	if def.pillar then
		p = t / PILLAR.life
		if p < 1 then
			live = true
			local grown = t < PILLAR.grow and t / PILLAR.grow or 1
			local tall = def.pillar * unit * (PILLAR.from + (1 - PILLAR.from) * grown)
			-- (Stood on end, its length is its height.)
			fx.slash:SetSize(tall, tall * PILLAR.wide * (1 - 0.5 * p))
			fx.slash:SetPoint("CENTER", e.text, "CENTER", 0, tall * PILLAR.lift)
			fx.slash:SetAlpha(PILLAR.alpha * (1 - p) * (1 - p))
			Show(fx.slash)
		else
			Hide(fx.slash)
		end
	end

	if def.slash then
		p = t / SLASH.life
		if p < 1 then
			live = true
			local grown = t < SLASH.grow and t / SLASH.grow or 1
			local long = def.slash * unit * (SLASH.from + (1 - SLASH.from) * grown)
			fx.slash:SetSize(long, def.slash * unit * SLASH.tall * (1 - 0.6 * p))
			fx.slash:SetAlpha((1 - p) * (1 - p))
			Show(fx.slash)
		else
			Hide(fx.slash)
		end
	end

	local n = fx.n
	if n > 0 and fx.motes then
		local text = e.text
		local risen = (1 - exp(-MOTE.slow * t)) / MOTE.slow
		local sway = MOTE.sway * unit
		for i = 1, n do
			local s = fx.shards[i]
			p = t / fx.life[i]
			if p < 1 then
				live = true
				local q = 1 - p
				local wide = fx.long[i] * (0.6 + 0.4 * q)
				local strength = q * q * MOTE.alpha
				if t < MOTE.fadeIn then strength = strength * t / MOTE.fadeIn end
				s:SetPoint("CENTER", text, "CENTER", fx.vx[i] + sway * sin(MOTE.swing * t + fx.turn[i]), fx.vy[i] * risen)
				-- (It shrinks slowly: sized again only once that is a quarter of a unit.)
				if not s.wide or s.wide - wide >= 0.25 or wide > s.wide then
					s.wide = wide
					s:SetSize(wide, wide)
				end
				s:SetAlpha(strength)
				Show(s)
			else
				Hide(s)
			end
		end
	elseif n > 0 then
		local text = e.text
		local gone = (1 - exp(-SHARD.drag * t)) / SHARD.drag
		local fallen = 0.5 * SHARD.fall * unit * t * t
		for i = 1, n do
			local s = fx.shards[i]
			p = t / fx.life[i]
			if p < 1 then
				live = true
				local q = 1 - p
				local long = fx.long[i] * (0.4 + 0.6 * q)
				s:SetPoint("CENTER", text, "CENTER", fx.vx[i] * gone, fx.vy[i] * gone - fallen)
				s:SetSize(long, long * SHARD.thick)
				s:SetAlpha(q * q)
				Show(s)
			else
				Hide(s)
			end
		end
	end

	if not live then X.Stop(e) end
	return live
end
