-- The salvage look: a near-black, oily plate with olive plates painted over it and bolted on, all of it through the
-- wars. The paint is worn in clusters where a plate is handled, rust gathers at the corners, under the bolts and
-- along the foot, and the content sits in an oil-dark well, wiped clean.
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors
local MEDIA = Shy.MEDIA
local Blend = UI.LookBlend
local floor, max, min = math.floor, math.max, math.min

local ART = {
	grime = MEDIA .. "SalvageGrime", scratch = MEDIA .. "SalvageScratch", scuff = MEDIA .. "SalvageScuff",
	bolt = MEDIA .. "SalvageBolt", streak = MEDIA .. "SalvageStreak", foot = MEDIA .. "SalvageFoot",
	corners = MEDIA .. "SalvageWearCorners", top = MEDIA .. "SalvageWearTop", bottom = MEDIA .. "SalvageWearBottom",
	left = MEDIA .. "SalvageWearLeft", right = MEDIA .. "SalvageWearRight",
	paint = MEDIA .. "SalvagePaint", paintEnd = MEDIA .. "SalvagePaintEnd",
	bare = MEDIA .. "SalvagePaintBare", bareEnd = MEDIA .. "SalvagePaintBareEnd",
}
-- The plate under (its fill leans to it), the plates bolted over it (olive paint), the steel under the trim's paint,
-- and how far a placed content's rim leans back to the plate (it frames the buttons, never competes with them).
local BODY, TONE, PAINT, LINE, RIM = { 0.075, 0.080, 0.072 }, 0.85, { 0.150, 0.158, 0.120 }, { 0.20, 0.205, 0.20 }, 0.45
-- The art's measures, in units, as the files are drawn: the face's sheets a side; the edge's corners a
-- side and each side's run; the wear beside a bolt; a bolt on a head or a foot and round a rim; the bolt's cells (a cell
-- for each size in pixels, left to right a texel apart: the file w x h); a run of rust; the rust along a foot; the
-- trim's run and its ends.
local GRIME, SCRATCH = 128, 128
local WEAR, RUN = 8, 256
local SCUFF, BOLT, BOLT_RIM = 16, 8, 7
local BOLTS = { least = 4, most = 24, w = 314, h = 24 }
local STREAK_W, STREAK_H = 5, 48
local FOOT_W, FOOT_H = 256, 16
local TRIM, TRIM_END = 512, 32
-- The face's strengths: the grime, the scratches (tinted this steel), the rust along a foot, the runs from a head's top
-- edge (one about every RUNS_EVERY units); a plate's lit top and its seam.
local GRIME_A, SCRATCH_A, SCRATCH_TINT, FOOT_A, RUNS_A, RUNS_EVERY = 0.75, 0.30, { 0.75, 0.76, 0.70 }, 0.8, 0.55, 70
-- How worn (the Wear option): the edge's chips, the grime, the scratches, the runs from the head's top edge (times
-- how many), and the wear beside the bolts.
local WORN = {
	light = { wear = 0.45, grime = 0.6, scratch = 0.5, runs = 0, scuffs = false },
	worn = { wear = 1, grime = 1, scratch = 1, runs = 1, scuffs = true },
	battered = { wear = 1, grime = 1.3, scratch = 1.6, runs = 2, scuffs = true },
}
-- A placed content's rim, calm: the wear, the bolts' grey, the grime, the scratches and the rust along the foot.
local CALM = { wear = 0.35, bolt = 0.6, grime = 0.7, scratch = 0.6, foot = 0.35 }

-- On screen the face fades with the fill (the world through it is never filmed over); a window keeps it whole.
local function Through(h) return h.solid and 1 or Theme.Strength() ^ 0.5 end
local function StripAlpha(h) return h.solid and 1 or UI.LookAlpha("salvage", C.hudStrip[4]) end

-- A region laid `l`, `t`, `r`, `b` units in from the plate's edges.
local function Place(t, g, l, top, r, b)
	local to, inset = g.to, g.inset
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + l, -inset[2] - top)
	t:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] - r, inset[4] + b)
end

-- Every other piece is laid from the edge or the corner it belongs to, at its own size there, so it stays where it is
-- and as big as it is whatever the housing's size until it is fitted again.
-- A region `w` x `h` units standing `x` and `y` in from one corner of the plate.
local function Stick(t, g, corner, x, y, w, h)
	local to, inset = g.to, g.inset
	local right, bottom = corner:find("RIGHT") ~= nil, corner:find("BOTTOM") ~= nil
	t:ClearAllPoints()
	t:SetPoint(corner, to, corner, right and -inset[3] - x or inset[1] + x, bottom and inset[4] + y or -inset[2] - y)
	t:SetSize(w, h)
end

-- A band `thick` units along one side of the plate ("TOP", "BOTTOM", "LEFT", "RIGHT"), `off` in from it, running from
-- `from` in from the side's first end (its left, or its top) to `upto` in from its other.
local function Band(t, g, side, off, thick, from, upto)
	local to, inset = g.to, g.inset
	t:ClearAllPoints()
	if side == "TOP" or side == "BOTTOM" then
		local y = side == "TOP" and -inset[2] - off or inset[4] + off
		t:SetPoint(side .. "LEFT", to, side .. "LEFT", inset[1] + from, y)
		t:SetPoint(side .. "RIGHT", to, side .. "RIGHT", -inset[3] - upto, y)
		t:SetHeight(thick)
	else
		local x = side == "LEFT" and inset[1] + off or -inset[3] - off
		t:SetPoint("TOP" .. side, to, "TOP" .. side, x, -inset[2] - from)
		t:SetPoint("BOTTOM" .. side, to, "BOTTOM" .. side, x, inset[4] + upto)
		t:SetWidth(thick)
	end
end

-- A tiling sheet `size` units a side over a band, from the housing's own place in it (so no two pieces are stamped from
-- the same place, and the pieces of one housing meet where they touch). The band as a rect in from the plate's edges.
-- `wide`: when the band runs wider than `size`, one period is stretched across it (the head's grime, so a title bar
-- does not tile the same fleck every 128 units).
local function Sheet(t, g, side, off, thick, from, upto, size, u, v, wide)
	Band(t, g, side, off, thick, from, upto)
	local w, tall = g.w, g.tall
	local l, top, r, b
	if side == "TOP" then l, top, r, b = from, off, w - upto, off + thick
	elseif side == "BOTTOM" then l, top, r, b = from, tall - off - thick, w - upto, tall - off
	elseif side == "LEFT" then l, top, r, b = off, from, off + thick, tall - upto
	else l, top, r, b = w - off - thick, from, w - off, tall - upto end
	local hSize = wide and max(size, wide) or size
	t:SetTexCoord(u + l / hSize, u + r / hSize, v + top / size, v + b / size)
end

local function Option(key)
	return Theme.LookOption("salvage", key)
end

-- The trim: dark steel under clean paint in your color, worn most at its ends (each end its own piece, the right one
-- turned), the run between from the line's own place; what shows where the paint has gone laid over the paint.
local function Lay(line, parts, u)
	local wide = line:GetWidth()
	if not wide or issecretvalue(wide) or wide <= 0 then return end
	local e = min(TRIM_END, wide / 2)
	for _, pair in ipairs({ { parts.paintLeft, parts.paintRight, parts.paint }, { parts.bareLeft, parts.bareRight, parts.bare } }) do
		local left, right, run = pair[1], pair[2], pair[3]
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", line, "TOPLEFT")
		left:SetPoint("BOTTOMRIGHT", line, "BOTTOMLEFT", e, 0)
		left:SetTexCoord(0, e / TRIM_END, 0, 1)
		right:ClearAllPoints()
		right:SetPoint("TOPRIGHT", line, "TOPRIGHT")
		right:SetPoint("BOTTOMLEFT", line, "BOTTOMRIGHT", -e, 0)
		right:SetTexCoord(e / TRIM_END, 0, 0, 1)
		run:ClearAllPoints()
		run:SetPoint("TOPLEFT", line, "TOPLEFT", e, 0)
		run:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -e, 0)
		run:SetTexCoord(u, u + (wide - 2 * e) / TRIM, 0, 1)
	end
end

local lined = 0
local function Line(owner, line)
	local parts = {}
	local function Make(name, file, sublevel, color)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, sublevel)
		t:SetAllPoints(line)   -- on the line from the start: laid by its width once it has one
		if file then UI.LookWear(t, file, "REPEAT", "CLAMP") end
		if color then Theme.Tint(t, color, 1) end
		parts[name] = t
		return t
	end
	local base = owner:CreateTexture(nil, "ARTWORK", nil, -2)
	base:SetAllPoints(line)
	Theme.Paint(base, LINE, 1)
	local accent = UI.LookAccent(owner)
	Make("paint", ART.paint, -1, accent)
	Make("paintLeft", ART.paintEnd, -1, accent)
	Make("paintRight", ART.paintEnd, -1, accent)
	Make("bare", ART.bare, 0)
	Make("bareLeft", ART.bareEnd, 0)
	Make("bareRight", ART.bareEnd, 0)
	lined = lined + 1
	local u = (lined * 0.618) % 1
	local function Again() Lay(line, parts, u) end
	line.salvageLay = Again   -- laid again with the housing (its art given back, its texcoords with it)
	if owner.HookScript and owner:HasScript("OnSizeChanged") then owner:HookScript("OnSizeChanged", Again) end
	Again()
	C_Timer.After(0, Again)   -- laid again once the line has a width (a piece made before it is placed)
	return { base, parts.paint, parts.paintLeft, parts.paintRight, parts.bare, parts.bareLeft, parts.bareRight }
end

local function Build(h, kit)
	local owner = kit.owner
	local function Tex(name, layer, sublevel, file, wrapX, wrapY)
		local t = kit.Reg(name, owner:CreateTexture(nil, layer, nil, sublevel))
		if file then UI.LookWear(t, file, wrapX or "CLAMP", wrapY or "CLAMP") else t:SetColorTexture(1, 1, 1, 1) end
		t:Hide()   -- until it is laid by size (a housing with no size yet shows none of it)
		return t
	end
	-- The plates bolted over the fill: a placed content's rim (four bands round its well) and the kick plate along a
	-- foot band, where a header's strip stands; a plate's lit top, the kick plate's seam.
	h.salvageRims = {}
	for i = 1, 4 do h.salvageRims[i] = Tex("salvageRim" .. i, "BACKGROUND", -2) end
	Tex("salvageKick", "BACKGROUND", -2)
	Tex("salvageKickSeam", "BACKGROUND", -1)
	Tex("salvageKickLit", "BACKGROUND", -1)
	Tex("salvageLip", "BACKGROUND", -1)
	-- The face's grime and scratches over the plates (over a header's strip too), laid round the well and never in it:
	-- four bands each.
	h.salvageGrime, h.salvageScratch = {}, {}
	for i = 1, 4 do
		h.salvageGrime[i] = Tex("salvageGrime" .. i, "BACKGROUND", -1, ART.grime, "REPEAT", "REPEAT")
		h.salvageScratch[i] = Tex("salvageScratch" .. i, "BACKGROUND", -1, ART.scratch, "REPEAT", "REPEAT")
	end
	Tex("salvageFoot", "BACKGROUND", -1, ART.foot, "REPEAT", "CLAMP")
	-- The edge's wear: four corners, four runs repeating along their sides.
	h.salvageCorners = {}
	for i = 1, 4 do h.salvageCorners[i] = Tex("salvageCorner" .. i, "BORDER", -1, ART.corners) end
	h.salvageTop = Tex("salvageWearTop", "BORDER", -1, ART.top, "REPEAT", "CLAMP")
	h.salvageBottom = Tex("salvageWearBottom", "BORDER", -1, ART.bottom, "REPEAT", "CLAMP")
	h.salvageLeft = Tex("salvageWearLeft", "BORDER", -1, ART.left, "CLAMP", "REPEAT")
	h.salvageRight = Tex("salvageWearRight", "BORDER", -1, ART.right, "CLAMP", "REPEAT")
end

local function Dress(h)
	local function Face() return 1, 1, 1, Through(h) end
	for i = 1, 4 do
		Theme.Tint(h.salvageGrime[i], Face)
		Theme.Tint(h.salvageScratch[i], function() return SCRATCH_TINT[1], SCRATCH_TINT[2], SCRATCH_TINT[3], Through(h) end)
		Theme.Paint(h.salvageRims[i], function()
			local r, g, b = Blend(PAINT[1], PAINT[2], PAINT[3], BODY[1], BODY[2], BODY[3], RIM)
			return r, g, b, StripAlpha(h)
		end)
	end
	Theme.Tint(h.salvageFoot, Face)
	Theme.Paint(h.salvageKick, function() return PAINT[1], PAINT[2], PAINT[3], StripAlpha(h) end)
	Theme.Paint(h.salvageKickSeam, { 0, 0, 0, 0.75 })
	Theme.Paint(h.salvageKickLit, { 1, 1, 1, 0.10 })
	Theme.Paint(h.salvageLip, { 1, 1, 1, 0.10 })
end

-- A bolt's cell in the file for a size in pixels.
local function BoltCell(t, s)
	local u = (s - BOLTS.least) * (s + BOLTS.least + 1) / 2
	UI.LookWear(t, ART.bolt)
	t:SetTexCoord(u / BOLTS.w, (u + s) / BOLTS.w, 0, s / BOLTS.h)
end

local function Fit(h, g)
	local w, tall, per = g.w, g.tall, g.per
	if h.line and h.line.salvageLay then h.line.salvageLay() end
	local level = WORN[Option("wear")] or WORN.worn
	local rust = Option("rust") ~= false
	local head, foot, well = g.head or 0, g.foot or 0, g.well
	local calm = g.content ~= nil and head == 0 and well ~= nil
	local u, v = UI.LookSeed(h, "face")
	-- Where the plates show: round the well (a band above, below and beside it) or the whole plate.
	local grime = GRIME_A * level.grime * (calm and CALM.grime or 1)
	local scratch = SCRATCH_A * level.scratch * (calm and CALM.scratch or 1)
	local bands
	if well then
		local l, t, r, b = well[1], well[2], well[3], well[4]
		bands = { { "TOP", 1, t - 1, 1, 1 }, { "BOTTOM", 1, b - 1, 1, 1 }, { "LEFT", 1, l - 1, t, b }, { "RIGHT", 1, r - 1, t, b } }
	end
	for i = 1, 4 do
		local gt, st = h.salvageGrime[i], h.salvageScratch[i]
		local band = bands and bands[i]
		local on = (band == nil and i == 1) or (band ~= nil and band[3] > 0)
		if band and on then
			local side, from, upto = band[1], band[4], band[5]
			local headWide = head > 0 and side == "TOP" and (w - from - upto)
			Sheet(gt, g, side, band[2], band[3], from, upto, GRIME, u, v, headWide)
			Sheet(st, g, side, band[2], band[3], from, upto, SCRATCH, v, u, headWide)
		elseif on then
			for _, t in ipairs({ gt, st }) do Place(t, g, 1, 1, 1, 1) end
			gt:SetTexCoord(u, u + (w - 2) / GRIME, v, v + (tall - 2) / GRIME)
			st:SetTexCoord(v, v + (w - 2) / SCRATCH, u, u + (tall - 2) / SCRATCH)
		end
		local ga, sa = grime, scratch
		if band and band[1] == "TOP" and head > 0 then
			ga, sa = ga * 0.82, sa * 0.75   -- the head's olive plate: mottling, not a second wallpaper
		end
		gt:SetAlpha(min(1, ga))
		st:SetAlpha(min(1, sa))
		gt:SetShown(on)
		st:SetShown(on)
	end
	-- A placed content's rim: the plate painted over, round the well.
	for i, t in ipairs(h.salvageRims) do
		if calm then
			local l, top, r, b = well[1], well[2], well[3], well[4]
			local band = ({ { "TOP", 2, top - 2, 2, 2 }, { "BOTTOM", 2, b - 2, 2, 2 }, { "LEFT", 2, l - 2, top, b }, { "RIGHT", 2, r - 2, top, b } })[i]
			Band(t, g, band[1], band[2], max(0.01, band[3]), band[4], band[5])
		end
		t:SetShown(calm)
	end
	-- The kick plate along a foot band: the head's paint, a dark seam over it and a lit edge under that.
	local kicked = foot > 2
	if kicked then
		Band(h.salvageKick, g, "BOTTOM", 2, foot - 2, 2, 2)
		Band(h.salvageKickSeam, g, "BOTTOM", foot - 1, 1, 2, 2)
		Band(h.salvageKickLit, g, "BOTTOM", foot - 2, 1, 2, 2)
	end
	h.salvageKick:SetShown(kicked)
	h.salvageKickSeam:SetShown(kicked)
	h.salvageKickLit:SetShown(kicked)
	-- A plate's top catching the light (a head's, a rim's).
	local lipped = head > 0 or calm
	if lipped then Band(h.salvageLip, g, "TOP", 2, 1, 2, 2) end
	h.salvageLip:SetShown(lipped)
	-- Rust gathered along the foot, in clumps, under the well.
	local deep = min(FOOT_H, well and well[4] - 1 or tall - 2)
	local rusted = rust and deep > 0
	if rusted then
		Band(h.salvageFoot, g, "BOTTOM", 1, deep, 1, 1)
		h.salvageFoot:SetTexCoord(u, u + (w - 2) / FOOT_W, 1 - deep / FOOT_H, 1)
		h.salvageFoot:SetAlpha(FOOT_A * (calm and CALM.foot or 1))
	end
	h.salvageFoot:SetShown(rusted)
	-- The edge's wear, kept to the margin round the well: chips never cross into it.
	local ml, mt, mr, mb = WEAR, WEAR, WEAR, WEAR
	if well then ml, mt, mr, mb = min(WEAR, well[1]), min(WEAR, well[2]), min(WEAR, well[3]), min(WEAR, well[4]) end
	local wear = level.wear * (calm and CALM.wear or 1)
	local q = 0.25   -- a corner's share of the atlas across
	local cells = {
		{ "TOPLEFT", ml, mt, 0, ml / WEAR, 0, mt / WEAR },
		{ "TOPRIGHT", mr, mt, 1 - mr / WEAR, 1, 0, mt / WEAR },
		{ "BOTTOMLEFT", ml, mb, 0, ml / WEAR, 1 - mb / WEAR, 1 },
		{ "BOTTOMRIGHT", mr, mb, 1 - mr / WEAR, 1, 1 - mb / WEAR, 1 },
	}
	for i, t in ipairs(h.salvageCorners) do
		local c = cells[i]
		local on = c[2] > 0 and c[3] > 0
		if on then
			Stick(t, g, c[1], 0, 0, c[2], c[3])
			t:SetTexCoord((i - 1 + c[4]) * q, (i - 1 + c[5]) * q, c[6], c[7])
		end
		t:SetAlpha(wear)
		t:SetShown(on)
	end
	local a, b = UI.LookSeed(h, "edge")
	local across, down = w - 2 * WEAR, tall - 2 * WEAR
	if across > 0 and mt > 0 then Band(h.salvageTop, g, "TOP", 0, mt, WEAR, WEAR) end
	h.salvageTop:SetTexCoord(a, a + across / RUN, 0, mt / WEAR)
	if across > 0 and mb > 0 then Band(h.salvageBottom, g, "BOTTOM", 0, mb, WEAR, WEAR) end
	h.salvageBottom:SetTexCoord(b, b + across / RUN, 1 - mb / WEAR, 1)
	if down > 0 and ml > 0 then Band(h.salvageLeft, g, "LEFT", 0, ml, WEAR, WEAR) end
	h.salvageLeft:SetTexCoord(0, ml / WEAR, a, a + down / RUN)
	if down > 0 and mr > 0 then Band(h.salvageRight, g, "RIGHT", 0, mr, WEAR, WEAR) end
	h.salvageRight:SetTexCoord(1 - mr / WEAR, 1, b, b + down / RUN)
	for _, t in ipairs({ h.salvageTop, h.salvageBottom, h.salvageLeft, h.salvageRight }) do t:SetAlpha(wear) end
	h.salvageTop:SetShown(across > 0 and mt > 0)
	h.salvageBottom:SetShown(across > 0 and mb > 0)
	h.salvageLeft:SetShown(down > 0 and ml > 0)
	h.salvageRight:SetShown(down > 0 and mr > 0)
	-- The bolts, each the cell drawn for its size on screen, on whole pixels: one at each end of a head and of a kick
	-- plate (worn round where it was knocked, rust run down from it), a dark one at each corner of a placed content's rim.
	local bolts, scuffs, streaks = UI.LookPool(h, "salvageBolt", "BORDER", 2), UI.LookPool(h, "salvageScuff", "BORDER", 0),
		UI.LookPool(h, "salvageStreak", "BORDER", 1)
	local nb, ns, nr = 0, 0, 0
	-- A run of rust from `near` to `far` in from the top (or, `low`, the foot), its middle `cx` in from the left (or,
	-- `right`, the right), falling down the plate either way.
	local function Streak(cx, near, far, k, right, low)
		if far - near <= 1 then return end
		nr = nr + 1
		local t = streaks:Get(nr)
		UI.LookWear(t, ART.streak)
		Stick(t, g, (low and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT"), cx - STREAK_W / 2, near, STREAK_W, far - near)
		t:SetTexCoord(0, 1, 0, min(1, (far - near) / STREAK_H))
		Theme.Tint(t, function() return 1, 1, 1, k * Through(h) end)
		t:Show()
	end
	-- The wear beside a bolt `cx`, `cy` in from a corner, cropped to the plate (2 in from its side) and between `lo`
	-- and `hi` in from its top (or foot).
	local function Scuff(cx, cy, lo, hi, right, low)
		ns = ns + 1
		local t = scuffs:Get(ns)
		local pick, turn = UI.LookSeed(h, "scuff" .. ns)
		local j = floor(pick * 4)
		local x0, y0 = cx - SCUFF / 2, cy - SCUFF / 2
		local l, r, near, far = max(x0, 2), x0 + SCUFF, max(y0, lo), min(y0 + SCUFF, hi)
		if r <= l or far <= near then return end
		-- The stamp's coordinates, read the right way round from whichever corner it is laid.
		local s0, s1 = (l - x0) / SCUFF, (r - x0) / SCUFF
		if right then s0, s1 = 1 - s1, 1 - s0 end
		local t0, t1 = (near - y0) / SCUFF, (far - y0) / SCUFF
		if low then t0, t1 = 1 - t1, 1 - t0 end
		if turn < 0.5 then s0, s1 = 1 - s0, 1 - s1 end
		UI.LookWear(t, ART.scuff)
		Stick(t, g, (low and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT"), l, near, r - l, far - near)
		t:SetTexCoord((j + s0) / 4, (j + s1) / 4, t0, t1)
		t:Show()
	end
	local function Bolt(units, x, y, right, bottom, tone)
		local s = min(BOLTS.most, max(BOLTS.least, floor(units * per + 0.5)))
		nb = nb + 1
		local t = bolts:Get(nb)
		BoltCell(t, s)
		UI.LookStamp(h, t, floor(x * per - s / 2 + 0.5), floor(y * per - s / 2 + 0.5), s, per, right, bottom)
		t:SetVertexColor(tone, tone, tone, 1)
		t:Show()
	end
	if per and w >= 3 * WEAR and tall >= 2 * WEAR then
		if head > 0 then
			local cy = 2 + (head - 2) / 2
			for _, right in ipairs({ false, true }) do
				if level.scuffs then Scuff(8, cy, 2, head - 2, right) end
				if rust then Streak(8, cy + 2, head - 2, 1, right) end
				Bolt(BOLT, 8, cy, right, false, 1)
			end
			if rust then
				-- Spread from the housing's own place by the golden ratio, so no two runs fall together; only a few
				-- along a head (besides the bolts), so a wide title bar doesn't read as a fence of drips.
				local at = UI.LookSeed(h, "runs")
				local n = min(floor(w / RUNS_EVERY * level.runs), level.runs + 1)
				for i = 1, n do
					Streak(30 + ((at + i * 0.618) % 1) * (w - 50), 1, head - 2, RUNS_A)
				end
			end
		end
		if kicked then
			local cy = foot / 2   -- in from the foot
			for _, right in ipairs({ false, true }) do
				if level.scuffs then Scuff(8, cy, 2, foot - 2, right, true) end
				if rust then Streak(8, 2, cy - 2, 1, right, true) end
				Bolt(BOLT, 8, cy, right, true, 1)
			end
		end
		if calm then
			local x, y = well[1] / 2 + 0.5, well[2] / 2 + 0.5
			local xr, yb = well[3] / 2 + 0.5, well[4] / 2 + 0.5
			Bolt(BOLT_RIM, x, y, false, false, CALM.bolt)
			Bolt(BOLT_RIM, xr, y, true, false, CALM.bolt)
			Bolt(BOLT_RIM, x, yb, false, true, CALM.bolt)
			Bolt(BOLT_RIM, xr, yb, true, true, CALM.bolt)
		end
	end
	bolts:Done(nb)
	scuffs:Done(ns)
	streaks:Done(nr)
end

-- Buttons: a face of the plate's paint (the look's toneFill leans it there) under its grime, chipped at two opposite
-- corners where hands hit, a dark bolt in the other two on a button big enough (KEY_WIDE x KEY_TALL); the bolt's
-- middle KEY_IN in from both its edges, KEY_BOLT across, on whole pixels; a chip KEY_CHIP a side. A button wearing
-- another make has them put away by it; laid again by size only while this one is worn.
local KEY_BOLT, KEY_CHIP, KEY_IN, KEY_WIDE, KEY_TALL, KEY_FACE = 5, 6, 4.5, 40, 20, 1.5
local built = 0

local function KeyLay(f)
	local s = f.salvageKey
	if not s then return end
	local w, tall = f:GetSize()
	local on = f.shyKeyMake == UI.KEY_MAKES.salvage and f.shyPlate ~= false
		and w and tall and not issecretvalue(w) and not issecretvalue(tall) and w > 2 * KEY_CHIP and tall > 2 * KEY_FACE
	s.grime:SetShown(on)
	for _, t in ipairs(s.chips) do t:SetShown(on) end
	local scale = f:GetEffectiveScale()
	local per = scale and not issecretvalue(scale) and scale > 0 and scale / PixelUtil.GetPixelToUIUnitFactor() or nil
	local bolted = on and per and w >= KEY_WIDE and tall >= KEY_TALL
	for _, t in ipairs(s.bolts) do t:SetShown(bolted or false) end
	if not on then return end
	s.grime:SetTexCoord(s.u, s.u + (w - 2 * KEY_FACE) / GRIME, s.v, s.v + (tall - 2 * KEY_FACE) / GRIME)
	local c = KEY_CHIP / WEAR
	s.chips[1]:SetTexCoord(0, c * 0.25, 0, c)                      -- the top left corner's cell
	s.chips[2]:SetTexCoord(1 - c * 0.25, 1, 1 - c, 1)              -- the bottom right's
	if bolted then
		local px = min(BOLTS.most, max(BOLTS.least, floor(KEY_BOLT * per + 0.5)))
		local x = floor(KEY_IN * per - px / 2 + 0.5) / per
		for i, t in ipairs(s.bolts) do
			BoltCell(t, px)
			local corner = i == 1 and "TOPRIGHT" or "BOTTOMLEFT"
			t:ClearAllPoints()
			t:SetPoint(corner, f, corner, i == 1 and -x or x, i == 1 and -x or x)
			t:SetSize(px / per, px / per)
		end
	end
end

local function KeyBuild(f)
	local s = { chips = {}, bolts = {} }
	f.salvageKey = s
	built = built + 1
	s.u, s.v = (built * 0.618) % 1, (built * 0.382) % 1   -- each button its own place in the grime
	s.grime = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	UI.LookWear(s.grime, ART.grime, "REPEAT", "REPEAT")
	s.grime:SetPoint("TOPLEFT", KEY_FACE, -KEY_FACE)
	s.grime:SetPoint("BOTTOMRIGHT", -KEY_FACE, KEY_FACE)
	for i, corner in ipairs({ "TOPLEFT", "BOTTOMRIGHT" }) do
		local t = f:CreateTexture(nil, "BORDER", nil, 1)
		UI.LookWear(t, ART.corners)
		t:SetPoint(corner)
		t:SetSize(KEY_CHIP, KEY_CHIP)
		s.chips[i] = t
	end
	for i = 1, 2 do s.bolts[i] = f:CreateTexture(nil, "BORDER", nil, 2) end
	f:HookScript("OnSizeChanged", KeyLay)
	return { s.grime, s.chips[1], s.chips[2], s.bolts[1], s.bolts[2] }
end

-- A state: the grime lighter over the primary's accent; the bolts a little lighter while lit.
local function KeyMark(f, lit, _, primary)
	local s = f.salvageKey
	if not s then return end
	s.grime:SetVertexColor(1, 1, 1, primary and 0.3 or 0.6)
	local tone = lit and 0.8 or CALM.bolt
	for _, t in ipairs(s.bolts) do t:SetVertexColor(tone, tone, tone, 1) end
	KeyLay(f)
end

-- The face leans to the plates' olive paint; the primary is paint in your color over it (its chips show the steel);
-- under the mouse a wash of worn steel comes over it and the bolts lighten.
UI.KEY_MAKES.salvage = { edge = { UI.LookArt.METAL_EDGE, UI.LookArt.METAL_EDGE_SLICE }, rim = "dark", hot = true,
	lean = { PAINT[1], PAINT[2], PAINT[3], 0.4 }, prime = "dye", dye = 0.5,
	hover = { color = { 0.55, 0.56, 0.5 }, lift = 0.08, light = 0.3 },
	build = KeyBuild, mark = KeyMark }

UI.LookKind("salvage", {
	name = "Salvage",
	strength = 88,
	words = "Scrap steel plates bolted on, the paint chipped and streaked with rust.",
	short = "Bolted scrap steel",
	zones = { well = { color = { 0.024, 0.026, 0.024 }, alpha = 0.72, solid = 0.72, art = UI.LookArt.METAL_WELL, slice = UI.LookArt.WELL_SLICE, IN = 3, GAP = 1 } },
	options = {
		{ key = "wear", label = "Wear", kind = "choice", default = "worn", desc = "How chipped and scuffed the paint is.",
			choices = { { value = "light", text = "Light" }, { value = "worn", text = "Worn" }, { value = "battered", text = "Battered" } } },
		{ key = "rust", label = "Rust", kind = "switch", default = true, desc = "Rust runs down from the bolts and gathers along the bottom." },
	},
	alpha = function(a) return 1 - (1 - a) ^ 2 end,
	fill = function(r, g, b, a)
		r, g, b = Blend(r, g, b, BODY[1], BODY[2], BODY[3], TONE)
		return r, g, b, a
	end,
	strip = function(_, _, _, a) return PAINT[1], PAINT[2], PAINT[3], a, false end,
	toneFill = function(r, g, b) return Blend(r, g, b, PAINT[1], PAINT[2], PAINT[3], 0.5) end,
	shade = 0.75, inset = 1, border = 2, rims = false,
	surface = { file = ART.grime, alpha = 0.6 },   -- a plaque or a card: the paint's grime, as its buttons
	bar = "chipped", slot = "sunken", ground = "rust",
	build = Build,
	dress = Dress,
	fit = Fit,
	line = Line, lineAlpha = 0,
	face = { "salvageGrime1", "salvageGrime2", "salvageGrime3", "salvageGrime4",
		"salvageScratch1", "salvageScratch2", "salvageScratch3", "salvageScratch4", "salvageFoot", "salvageStreak" },
	-- A chat bubble's tail (UI.LookTail): the foot's worn paint running on round it, as worn as the rest, over the
	-- same grimy plate.
	tail = function()
		local level = WORN[Option("wear")] or WORN.worn
		return "Salvage", { { layer = "Edge", color = { 1, 1, 1 }, alpha = level.wear } },
			{ { fill = true }, { file = ART.grime, tile = GRIME, color = { 1, 1, 1 }, alpha = GRIME_A * level.grime } }
	end,
	edge = { "salvageRim1", "salvageRim2", "salvageRim3", "salvageRim4", "salvageKick", "salvageKickSeam", "salvageKickLit",
		"salvageLip", "salvageCorner1", "salvageCorner2", "salvageCorner3", "salvageCorner4", "salvageWearTop",
		"salvageWearBottom", "salvageWearLeft", "salvageWearRight", "salvageBolt", "salvageScuff" },
})
