-- Rare creatures on a zone's map (ShyQuest's word on them: Shy.addons.Quest:Rares(map)). Nothing is written on the
-- map: a rare is a mark, the game's silver rare sign on a soft shadow in a fine ring of the color its level is
-- against yours; marks that would overlap stand side by side. One that turns up in three places or more is one mark,
-- at the place nearest their middle, a pile behind it and how many places at its corner; one that walks a path is a
-- mark on its path. Places nearer than NEAR (a share of the map) are one. A zone's map only: from afar they'd be a
-- scatter.
--
-- Rested on a moment (DWELL, a light gathering behind it meanwhile) or clicked, a rare is looked at alone
-- (View.Focus): the view glides to show every place it turns up and you, and the creature itself stands turning
-- beside them, on whichever side of the map leaves them the most room, its name and what to know under it.
-- Everything else on the map fades. Copies of its mark fly out to each place it turns up and breathe a ring there;
-- its path is drawn in the kill color, its dashes flowing the way it walks; a fine line of dashes runs from you to
-- the nearest of them. A click or the mouse off the map lets it go: the copies gather and the view glides back to
-- where it was (the wheel lets it go too, and zooms from where it is).

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI

local Rares = {}
ns.Rares = Rares

local K = {
	ATLAS = "nameplates-icon-elite-silver",
	MARK = 18,              -- a mark, units on screen
	NEAR = 0.012,           -- places nearer than this share of the map are one
	SPREAD = 3,             -- places from which they gather into one mark
	DWELL = 0.35,           -- seconds a mark is rested on before its rare is looked at alone
	AGAIN = 0.6,            -- seconds after one is let go before another is
	FLY = 0.45,             -- seconds the copies take to fly out or back
	SHOW = 0.35,            -- seconds the creature takes to come in or go
	SLIDE = 28,             -- units it comes in from its side
	PULSE = 1.8,            -- seconds a place's ring takes to breathe out
	LEAST = 0.2,            -- what is shown, at least this share of the map each way
	MOST = 4,               -- ... at most this many times the whole map's size
	EDGE = 0.1,             -- share of the room left clear round what is shown
	MARGIN = 12,            -- units between the creature's side and the port's edges
	GAP = 16,               -- ... and between it and the room left for the map
	CORNER = 96,            -- units kept clear at the port's foot on the right: the corner plate (Controls.lua) stands there
	SIDE = { share = 0.3, least = 190, most = 280, tall = 1.55 },   -- standing at the left or right: its width
	LOW = { share = 0.34, least = 140, most = 200, wide = 2.6 },    -- ... at the top or bottom: its height
	SIDES = { "right", "left", "bottom", "top" },                    -- tried in this order; the first best is taken
	GLOW = Shy.MEDIA .. "Glow",
	RING = Shy.MEDIA .. "TalkRing",
	DASH = Shy.MEDIA .. "Dash",
	PERIOD = 14,            -- screen pixels a dash and its gap
	FLOW = 1.4,             -- dashes a second a lit path flows by
	TRAIL = 0.8,            -- ... and the line from you
	TRAIL_EVERY = 0.1,      -- seconds between looks at where you are, for the line from you
	BACK = 0.8,             -- seconds at most the view takes gliding back before all else comes back in
}

local marks, copies, lines = {}, {}, {}
local Stand                 -- (below: the marks stood at the zoom)
local usedMarks, usedCopies, usedLines = 0, 0, 0
local sheet                 -- the lit lines, on the lift
local beacon                -- the light round you, on the lift
local plate                 -- the creature, its name and what to know, over the map
local catch                 -- over the map while a rare is looked at: a click or the wheel lets it go
local rested                -- { mark, t }: the mark the mouse rests on
local held                  -- the mark looked at alone
local was                   -- the view before it: { map, x, y, zoom, following }
local after = 0             -- no rare is looked at before this time (one was just let go)
local fly = { t = 0, want = 0 }    -- the copies, how far out; `from`, the mark they fly from
local show = { t = 0, want = 0 }   -- the creature, how far in
local flow, pulse = 0, 0
local trail = { t = 0, on = false, pair = nil, next = 0 }   -- the line from you: its flow, shown, its lines, next look
local you                   -- { x, y }: where you stood when the line from you was laid
local glide                 -- where the view goes once all else is out of sight (Aim's), while it waits
local leaving               -- the view gliding back: until when all else waits to come back in
local stale = false         -- the marks weren't stood at the zoom (hidden in a focus): stood as it ends

-- The places a rare turns up, near ones as one: { x, y, ... } in shares of the map.
local function Spots(points)
	local out = {}
	for i = 1, #points - 1, 2 do
		local x, y = points[i] / 9999, points[i + 1] / 9999
		local near = false
		for j = 1, #out - 1, 2 do
			if (out[j] - x) ^ 2 + (out[j + 1] - y) ^ 2 < K.NEAR ^ 2 then
				near = true
				break
			end
		end
		if not near then out[#out + 1], out[#out + 2] = x, y end
	end
	return out
end

-- The place nearest the middle of them all.
local function Middle(spots)
	local mx, my, n = 0, 0, #spots / 2
	for i = 1, #spots - 1, 2 do mx, my = mx + spots[i], my + spots[i + 1] end
	mx, my = mx / n, my / n
	local best, bx, by = math.huge, spots[1], spots[2]
	for i = 1, #spots - 1, 2 do
		local d = (spots[i] - mx) ^ 2 + (spots[i + 1] - my) ^ 2
		if d < best then best, bx, by = d, spots[i], spots[i + 1] end
	end
	return bx, by
end

local function Ease(t) return t * t * (3 - 2 * t) end

local function Color(rare)
	local c = ns.LevelColor(rare.low or 0, rare.high or 0)
	return { c.r, c.g, c.b }
end

-- Each point a rare is found at (its places, or its path's), in shares: fn(x, y).
local function Each(mark, fn)
	if mark.path then
		for _, stretch in ipairs(mark.path) do
			for j = 1, #stretch - 1, 2 do fn(stretch[j] / 9999, stretch[j + 1] / 9999) end
		end
	else
		for i = 1, #mark.spots - 1, 2 do fn(mark.spots[i], mark.spots[i + 1]) end
	end
end

-- The point of it nearest x, y.
local function Nearest(mark, x, y)
	local best, bx, by = math.huge, nil, nil
	Each(mark, function(px, py)
		local d = (px - x) ^ 2 + (py - y) ^ 2
		if d < best then best, bx, by = d, px, py end
	end)
	return bx, by
end

local function Yards(map, ax, ay, bx, by)
	local wide, tall = C_Map.GetMapWorldSize(map)
	if not (wide and wide > 0 and tall and tall > 0) then return nil end
	return math.sqrt(((bx - ax) * wide) ^ 2 + ((by - ay) * tall) ^ 2)
end

-- Where the view goes

-- A middle held as the view holds it in a focus (View.Focus): the map over the whole of the room from a to b (port
-- units, of a port `size` that way; `span`, the map's size), or in the room's middle where the map is smaller.
local function Held(c, span, a, b, size)
	local lo = 0.5 - ((a + b) / 2 - size / 2) / span
	local hi = lo
	if span > b - a then lo, hi = (size / 2 - a) / span, 1 - (b - size / 2) / span end
	return math.max(lo, math.min(hi, c))
end

-- Where the creature stands on side `side` of a port pw by ph: { x, y, w, h } from its top left. Clear of the
-- corner plate at the foot of the right: at the right it hangs from the top, at the foot it stands to the left.
local function PlateRect(side, pw, ph)
	if side == "left" then
		local w = math.max(K.SIDE.least, math.min(K.SIDE.most, pw * K.SIDE.share))
		local h = math.min(ph - 2 * K.MARGIN, w * K.SIDE.tall)
		return { x = K.MARGIN, y = (ph - h) / 2, w = w, h = h }
	elseif side == "right" then
		local w = math.max(K.SIDE.least, math.min(K.SIDE.most, pw * K.SIDE.share))
		local h = math.min(ph - K.MARGIN - K.CORNER, w * K.SIDE.tall)
		return { x = pw - w - K.MARGIN, y = K.MARGIN, w = w, h = h }
	end
	local h = math.max(K.LOW.least, math.min(K.LOW.most, ph * K.LOW.share))
	local w = math.min(pw - 2 * K.MARGIN, h * K.LOW.wide)
	if side == "top" then return { x = (pw - w) / 2, y = K.MARGIN, w = w, h = h } end
	return { x = K.MARGIN, y = ph - h - K.MARGIN, w = math.min(w, pw - K.MARGIN - K.CORNER * 2), h = h }
end

-- How the rare is shown: { side, rect, room, k (the scale), x, y (the middle) }. Each side is tried: the zoom that
-- fits every place, the mark and you into the room the creature leaves (out as far as the whole map fits it), the
-- middle that stands them in the middle of it, and how many of them would then stand under the creature or off the
-- port. The fewest such, then the nearest zoom.
local function Aim(mark)
	local map = View.Map()
	local w, h = View.Size()
	local fit, deep = View.Fit(), View.Deep()
	local port = View.Port()
	local pw, ph = port:GetWidth(), port:GetHeight()
	if not (map and w and fit and pw > 0 and ph > 0) then return nil end
	local points = { mark.sx, mark.sy }
	Each(mark, function(x, y) points[#points + 1], points[#points + 2] = x, y end)
	local mx, my = View.PlayerAt(map)
	if mx then points[#points + 1], points[#points + 2] = mx, my end
	local x1, x2, y1, y2 = math.huge, -math.huge, math.huge, -math.huge
	for i = 1, #points - 1, 2 do
		x1, x2 = math.min(x1, points[i]), math.max(x2, points[i])
		y1, y2 = math.min(y1, points[i + 1]), math.max(y2, points[i + 1])
	end
	if x2 - x1 < K.LEAST then x1, x2 = (x1 + x2 - K.LEAST) / 2, (x1 + x2 + K.LEAST) / 2 end
	if y2 - y1 < K.LEAST then y1, y2 = (y1 + y2 - K.LEAST) / 2, (y1 + y2 + K.LEAST) / 2 end
	local best
	for _, side in ipairs(K.SIDES) do
		local rect = PlateRect(side, pw, ph)
		local left, top, right, bottom = 0, 0, pw, ph
		if side == "right" then right = rect.x - K.GAP
		elseif side == "left" then left = rect.x + rect.w + K.GAP
		elseif side == "bottom" then bottom = rect.y - K.GAP
		else top = rect.y + rect.h + K.GAP end
		local k = math.min((right - left) * (1 - 2 * K.EDGE) / ((x2 - x1) * w), (bottom - top) * (1 - 2 * K.EDGE) / ((y2 - y1) * h))
		local whole = math.min(fit, (right - left) / w, (bottom - top) / h)
		k = math.max(whole, math.min(fit * K.MOST, deep or fit * K.MOST, k))
		local cx = Held((x1 + x2) / 2 - ((left + right) / 2 - pw / 2) / (w * k), w * k, left, right, pw)
		local cy = Held((y1 + y2) / 2 - ((top + bottom) / 2 - ph / 2) / (h * k), h * k, top, bottom, ph)
		local astray = 0
		for i = 1, #points - 1, 2 do
			local px, py = pw / 2 + (points[i] - cx) * w * k, ph / 2 + (points[i + 1] - cy) * h * k
			local under = px > rect.x - K.GAP and px < rect.x + rect.w + K.GAP and py > rect.y - K.GAP and py < rect.y + rect.h + K.GAP
			if under or px < 0 or px > pw or py < 0 or py > ph then astray = astray + 1 end
		end
		if not best or astray < best.astray or (astray == best.astray and k > best.k * 1.02) then
			best = { side = side, rect = rect, room = { left = left, top = top, right = right, bottom = bottom }, k = k,
				x = cx, y = cy, astray = astray }
		end
	end
	return best
end

-- The lit lines: its path (laid at each zoom), the line from you (laid as you move, at most each TRAIL_EVERY)

local function Pair()
	local pair = { sheet:CreateLine(nil, "ARTWORK", nil, 1), sheet:CreateLine(nil, "ARTWORK", nil, 2) }
	for _, line in ipairs(pair) do line:SetTexture(K.DASH, "REPEAT", "CLAMP") end
	return pair
end

local function Line(i)
	local pair = lines[i]
	if pair then return pair end
	pair = Pair()
	lines[i] = pair
	return pair
end

local function Flow()
	for i = 1, usedLines do
		local pair = lines[i]
		for _, line in ipairs(pair) do line:SetTexCoord(-flow, pair.tiles - flow, 0, 1) end
	end
	local pair = trail.pair
	if pair and trail.on then
		for _, line in ipairs(pair) do line:SetTexCoord(-trail.t, pair.tiles - trail.t, 0, 1) end
	end
end

-- Lays `pair` from a to b (shares of the map).
local function Segment(pair, ax, ay, bx, by, color, thick, faint)
	local w, h = View.Size()
	local s = View.Scale()
	ax, ay, bx, by = ax * w, ay * h, bx * w, by * h
	for _, line in ipairs(pair) do
		line:SetStartPoint("TOPLEFT", sheet, ax, -ay)
		line:SetEndPoint("TOPLEFT", sheet, bx, -by)
		line:Show()
	end
	pair.tiles = math.max(1, math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) * s / K.PERIOD)
	pair[1]:SetVertexColor(0, 0, 0, faint and 0.5 or 0.65)
	pair[1]:SetThickness(thick * 2 / s)
	UI.Tint(pair[2], color, faint and 0.9 or 1)
	pair[2]:SetThickness(thick / s)
end

-- The words that say how far you are from it (nil: you aren't on this map).
local function Away(mark, yards)
	if not yards then return nil end
	if yards < 30 then return "You're there now" end
	local said = ("%d yd"):format(math.floor(yards / 10 + 0.5) * 10)
	if mark.path then return "Its path is " .. said .. " from you" end
	if #mark.spots > 2 then return "The nearest is " .. said .. " from you" end
	return said .. " from you"
end

local function Words(row, glyph, text)
	row.text:SetText(text or "")
	row:SetShown(text ~= nil)
	if glyph then Shy.Hover.Glyph(row.glyph, glyph, 13) end
end

-- The line from you to the nearest of it, and how far that is, said.
local function LayTrail()
	local map = View.Map()
	local x, y = View.PlayerAt(map)
	you = x and { x, y } or nil
	local nx, ny
	if held and x then nx, ny = Nearest(held, x, y) end
	local yards = nx and Yards(map, x, y, nx, ny)
	trail.on = yards ~= nil and yards >= 30 and View.Size() ~= nil
	if trail.on then
		trail.pair = trail.pair or Pair()
		Segment(trail.pair, x, y, nx, ny, Shy.Theme.light, 2, true)
	elseif trail.pair then
		trail.pair[1]:Hide()
		trail.pair[2]:Hide()
	end
	if held and plate then Words(plate.rows[2], "clock", Away(held, yards)) end
	Flow()
end

-- The lines at the zoom: the rare's path, and the line from you.
local function LayLines()
	usedLines = 0
	local w = View.Size()
	local s = View.Scale()
	if held and w and s and s > 0 then
		local kinds = rawget(Shy, "Kinds")
		local kill = kinds and kinds.kill and kinds.kill.color or UI.colors.bad
		for _, stretch in ipairs(held.path or {}) do
			for j = 3, #stretch - 1, 2 do
				usedLines = usedLines + 1
				Segment(Line(usedLines), stretch[j - 2] / 9999, stretch[j - 1] / 9999, stretch[j] / 9999, stretch[j + 1] / 9999, kill, 3.5)
			end
		end
	end
	for i = usedLines + 1, #lines do
		lines[i][1]:Hide()
		lines[i][2]:Hide()
	end
	LayTrail()
end

-- The creature

local function Plate()
	if plate then return plate end
	plate = CreateFrame("Frame", nil, View.Chrome())
	plate:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 30)
	plate:EnableMouse(false)
	-- (A soft dark it stands on, no box: the map shows round it. A light of its level's color behind it, a shadow at its feet.)
	plate.shade = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
	plate.shade:SetTexture(K.GLOW)
	plate.shade:SetVertexColor(0, 0, 0, 0.78)
	plate.light = plate:CreateTexture(nil, "BACKGROUND", nil, -6)
	plate.light:SetTexture(K.GLOW)
	plate.light:SetBlendMode("ADD")
	plate.floor = plate:CreateTexture(nil, "BACKGROUND", nil, -4)
	plate.floor:SetTexture(K.GLOW)
	plate.floor:SetVertexColor(0, 0, 0, 0.85)
	plate.stage = CreateFrame("Frame", nil, plate)
	plate.model = Shy.Model.New(plate.stage)
	plate.model:SetAllPoints()
	plate.model.turn = 0.35
	plate.words = CreateFrame("Frame", nil, plate)
	plate.name = plate.words:CreateFontString(nil, "OVERLAY")
	plate.name:SetFontObject(UI.NameFont(18, "OUTLINE"))
	plate.name:SetJustifyH("LEFT")
	plate.name:SetWordWrap(true)
	plate.name:SetShadowOffset(1, -1)
	plate.name:SetShadowColor(0, 0, 0, 1)
	plate.level = plate.words:CreateFontString(nil, "OVERLAY")
	plate.level:SetFontObject(UI.TextFont(11, "OUTLINE"))
	plate.level:SetJustifyH("LEFT")
	plate.rows = {}
	for i = 1, 2 do
		local row = CreateFrame("Frame", nil, plate.words)
		row:SetHeight(16)
		row.glyph = row:CreateTexture(nil, "OVERLAY")
		row.glyph:SetSize(13, 13)
		row.glyph:SetPoint("LEFT")
		row.text = row:CreateFontString(nil, "OVERLAY")
		row.text:SetFontObject(UI.TextFont(11, "OUTLINE"))
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(false)
		row.text:SetPoint("LEFT", row.glyph, "RIGHT", 5, 0)
		row.text:SetPoint("RIGHT")
		plate.rows[i] = row
	end
	plate.hint = plate.words:CreateFontString(nil, "OVERLAY")
	plate.hint:SetFontObject(UI.TextFont(10, "OUTLINE"))
	plate.hint:SetJustifyH("LEFT")
	plate.hint:SetText("Click to go back")
	plate:SetAlpha(0)
	plate:Hide()
	return plate
end

-- The words laid from the top of `plate.words`, `wide` across; how tall they stand.
local function LayWords(wide)
	local text, dim = UI.colors.text, UI.colors.dim
	local y = 0
	local function Put(region, tall, gap)
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", plate.words, "TOPLEFT", 0, -y)
		region:SetWidth(wide)
		y = y + tall + (gap or 0)
	end
	plate.name:SetWidth(wide)
	Put(plate.name, plate.name:GetStringHeight(), 1)
	Put(plate.level, 13, 7)
	plate.level:SetTextColor(dim[1], dim[2], dim[3])
	for _, row in ipairs(plate.rows) do
		if row:IsShown() then
			Put(row, 16, 1)
			row.text:SetTextColor(text[1], text[2], text[3])
			row.glyph:SetVertexColor(text[1], text[2], text[3])
		end
	end
	y = y + 5
	Put(plate.hint, 12)
	plate.hint:SetTextColor(dim[1], dim[2], dim[3])
	return y
end

local function LayPlate(mark, aim)
	local rare = mark.rare
	local color = Color(rare)
	Plate()
	plate.side, plate.rect = aim.side, aim.rect
	local rect = aim.rect
	plate:SetSize(rect.w, rect.h)
	plate.name:SetText(rare.name)
	plate.name:SetTextColor(color[1], color[2], color[3])
	plate.level:SetText(rare.level and (rare.level:gsub("^level", "Level")) or "Rare")
	local places = #mark.spots / 2
	Words(plate.rows[1], "go", mark.path and "Walks the path lit on the map"
		or places > 1 and ("Turns up in %d places"):format(places) or nil)
	Words(plate.rows[2], "clock", nil)
	LayLines()
	local stage = plate.stage
	stage:ClearAllPoints()
	plate.words:ClearAllPoints()
	local tall
	if aim.side == "left" or aim.side == "right" then
		-- (Standing at a side: the creature over its words.)
		local wide = rect.w - 24
		tall = LayWords(wide)
		plate.words:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", 12, 10)
		plate.words:SetSize(wide, tall)
		stage:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, 0)
		stage:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 0, tall + 16)
	else
		-- (At the top or bottom: the creature at the left, its words beside it.)
		local wide = rect.w - rect.h - 16
		tall = LayWords(wide)
		stage:SetPoint("TOPLEFT")
		stage:SetSize(rect.h, rect.h)
		plate.words:SetPoint("LEFT", plate, "LEFT", rect.h + 8, 0)
		plate.words:SetSize(wide, tall)
	end
	plate.shade:ClearAllPoints()
	plate.shade:SetPoint("CENTER")
	plate.shade:SetSize(rect.w * 1.45, rect.h * 1.3)
	local sw, sh = stage:GetWidth(), stage:GetHeight()
	if not (sw and sw > 0) then sw, sh = rect.w, rect.h - tall - 16 end
	plate.light:ClearAllPoints()
	plate.light:SetPoint("CENTER", stage, "CENTER", 0, -sh * 0.08)
	plate.light:SetSize(sw * 1.05, sh * 0.95)
	UI.Tint(plate.light, color, 0.3)
	plate.floor:ClearAllPoints()
	plate.floor:SetPoint("CENTER", stage, "BOTTOM", 0, 10)
	plate.floor:SetSize(sw * 0.7, 22)
	plate.model:Set({ display = rare.display, creature = rare.id })
end

-- The creature where it is on its way in or out: faded, and slid from its side.
local function Present()
	if not plate then return end
	local e = Ease(show.t)
	plate:SetShown(show.t > 0)
	plate:SetAlpha(e)
	if beacon then
		beacon:SetAlpha(e)
		if show.t <= 0 then beacon:Hide() end
	end
	local rect = plate.rect
	if rect then
		local off = K.SLIDE * (1 - e)
		local dx = plate.side == "right" and off or plate.side == "left" and -off or 0
		local dy = plate.side == "bottom" and off or plate.side == "top" and -off or 0
		plate:ClearAllPoints()
		plate:SetPoint("TOPLEFT", View.Chrome(), "TOPLEFT", rect.x + dx, -(rect.y + dy))
	end
	-- (Gone: its model goes too, nothing turning unseen.)
	if show.t <= 0 then plate.model:Set(nil) end
end

-- The copies

local function Copy(i)
	local copy = copies[i]
	if copy then return copy end
	-- (On the lift: in sight while all else fades. No mouse: nothing to flicker between.)
	copy = View.Pin("PIN_FRAME_LEVEL_AREA_POI", K.MARK)
	copy:SetParent(View.Lift())
	copy:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_AREA_POI"))
	copy.icon:SetAtlas(K.ATLAS)
	copy.icon:SetDrawLayer("ARTWORK", 2)
	copy.shadow = copy:CreateTexture(nil, "BACKGROUND", nil, -8)
	copy.shadow:SetTexture(K.GLOW)
	copy.shadow:SetVertexColor(0, 0, 0, 0.75)
	copy.shadow:SetPoint("CENTER")
	copy.shadow:SetSize(K.MARK * 2.1, K.MARK * 2.1)
	copy.ring = copy:CreateTexture(nil, "ARTWORK", nil, 1)
	copy.ring:SetTexture(K.RING)
	copy.ring:SetPoint("CENTER")
	copy.ring:SetSize(K.MARK * 1.45, K.MARK * 1.45)
	copy.breath = copy:CreateTexture(nil, "BORDER")
	copy.breath:SetTexture(K.RING)
	copy.breath:SetBlendMode("ADD")
	copy.breath:SetPoint("CENTER")
	copies[i] = copy
	return copy
end

-- The copies where they are on their way out to their places or back into the mark they fly from.
local function Spread()
	local from = fly.from
	local e = Ease(fly.t)
	for i = 1, usedCopies do
		local copy = copies[i]
		copy:SetShown(from ~= nil and fly.t > 0)
		if from and fly.t > 0 then
			View.Place(copy, from.sx + (copy.tx - from.sx) * e, from.sy + (copy.ty - from.sy) * e, 1)
		end
	end
	for i = usedCopies + 1, #copies do copies[i]:Hide() end
end

-- Each place breathes a ring out, one after another round them.
local function Breathe()
	local e = Ease(fly.t)
	for i = 1, usedCopies do
		local copy = copies[i]
		local f = ((pulse / K.PULSE) + i * 0.17) % 1
		copy.breath:SetSize(K.MARK * (1.4 + 1.6 * f), K.MARK * (1.4 + 1.6 * f))
		copy.breath:SetAlpha(0.75 * (1 - f) * e)
	end
end

-- Looking at one alone, and letting it go

-- All else back in sight (the marks stood at the zoom first, if it moved while they were hidden).
local function Unfocus()
	leaving = nil
	View.Focus(false)
	if stale then
		stale = false
		Stand()
	end
end

-- back: the view glides back to where it was, and all else comes back in once it is there (a view moving with
-- everything in sight lays every addon's pins at each step); else all else comes back at once.
local function Let(back)
	local mark = held
	if not mark then return end
	held, rested, glide = nil, nil, nil
	after = GetTime() + K.AGAIN
	fly.want, show.want = 0, 0
	if catch then catch:Hide() end
	if sheet then LayLines() end
	if back and was and View.Map() == was.map then
		View.Focus(true, nil)
		leaving = GetTime() + K.BACK
		if was.following then View.Seek(was.zoom) else View.Glide(was.x, was.y, was.zoom) end
	else
		Unfocus()
	end
	was = nil
end

local function Look(mark)
	if held == mark or not mark.rare then return end
	Let(false)
	local aim = Aim(mark)
	if not aim then return end
	local fit = View.Fit()
	local x, y = View.Center()
	was = { map = View.Map(), x = x, y = y, zoom = View.Scale() / fit, following = View.Following() }
	held, rested, leaving = mark, nil, nil
	mark.charge:SetAlpha(0)
	-- (All else fades out first; the view moves once it is out of sight: Tick.)
	View.Focus(true, aim.room)
	glide = aim
	-- A copy for each place, flying out from the mark (one on a path, where its mark stands).
	usedCopies = 0
	local color = Color(mark.rare)
	local function Add(tx, ty)
		usedCopies = usedCopies + 1
		local copy = Copy(usedCopies)
		copy.tx, copy.ty = tx, ty
		copy.ring:SetVertexColor(color[1], color[2], color[3], 0.95)
		UI.Tint(copy.breath, color, 1)
	end
	if mark.path then
		Add(mark.x, mark.y)
	else
		for i = 1, #mark.spots - 1, 2 do Add(mark.spots[i], mark.spots[i + 1]) end
	end
	fly.from, fly.want = mark, 1
	Spread()
	LayPlate(mark, aim)
	show.want = 1
	beacon:Show()
	flow, trail.t = 0, 0
	catch:Show()
end

-- The marks

-- The light that gathers behind a mark as the mouse rests on it.
local function Charge(mark, f)
	local e = Ease(math.max(0, math.min(1, f)))
	mark.charge:SetSize(K.MARK * (1.3 + 1.7 * e), K.MARK * (1.3 + 1.7 * e))
	mark.charge:SetAlpha(0.9 * e)
end

local function Rest(mark)
	if held or not mark.rare then return end
	rested = { mark = mark, t = 0 }
end

local function Unrest(mark)
	if rested and rested.mark == mark then
		Charge(mark, 0)
		rested = nil
	end
end

local function Mark(i)
	local mark = marks[i]
	if mark then return mark end
	mark = View.Pin("PIN_FRAME_LEVEL_AREA_POI", K.MARK, function(self) Rest(self) end, function(self) Look(self) end)
	mark:SetScript("OnLeave", function(self) Unrest(self) end)
	mark.icon:SetAtlas(K.ATLAS)
	mark.icon:SetDrawLayer("ARTWORK", 2)
	mark.shadow = mark:CreateTexture(nil, "BACKGROUND", nil, -8)
	mark.shadow:SetTexture(K.GLOW)
	mark.shadow:SetVertexColor(0, 0, 0, 0.7)
	mark.shadow:SetPoint("CENTER")
	mark.shadow:SetSize(K.MARK * 2.1, K.MARK * 2.1)
	mark.charge = mark:CreateTexture(nil, "BACKGROUND", nil, -7)
	mark.charge:SetTexture(K.GLOW)
	mark.charge:SetBlendMode("ADD")
	mark.charge:SetPoint("CENTER")
	mark.charge:SetAlpha(0)
	mark.ring = mark:CreateTexture(nil, "ARTWORK", nil, 1)
	mark.ring:SetTexture(K.RING)
	mark.ring:SetPoint("CENTER")
	mark.ring:SetSize(K.MARK * 1.45, K.MARK * 1.45)
	-- (A pile behind it and how many at its corner: a mark that stands for several places.)
	mark.pile = {}
	for k = 1, 2 do
		local t = mark:CreateTexture(nil, "BORDER", nil, -k)
		t:SetAtlas(K.ATLAS)
		t:SetSize(K.MARK * 0.9, K.MARK * 0.9)
		t:SetPoint("CENTER", mark, "CENTER", 3.5 * k, 3.5 * k)
		t:SetDesaturated(true)
		t:SetAlpha(0.6 - 0.18 * k)
		mark.pile[k] = t
	end
	mark.countBack = mark:CreateTexture(nil, "OVERLAY", nil, 1)
	mark.countBack:SetTexture(K.GLOW)
	mark.countBack:SetVertexColor(0, 0, 0, 0.8)
	mark.countBack:SetSize(20, 16)
	mark.countBack:SetPoint("CENTER", mark, "TOPRIGHT", 1, 0)
	mark.count = mark:CreateFontString(nil, "OVERLAY", nil, 2)
	mark.count:SetFontObject(UI.NameFont(9, "OUTLINE"))
	mark.count:SetPoint("CENTER", mark.countBack, "CENTER", 0, 0)
	marks[i] = mark
	return mark
end

local function Put(rare, x, y, spots, spread)
	usedMarks = usedMarks + 1
	local mark = Mark(usedMarks)
	mark.rare, mark.name, mark.x, mark.y, mark.sx, mark.sy = rare, rare.name, x, y, x, y
	mark.spots, mark.spread, mark.path = spots, spread, nil
	local color = Color(rare)
	mark.ring:SetVertexColor(color[1], color[2], color[3], 0.95)
	UI.Tint(mark.charge, color, 1)
	Charge(mark, 0)
	for _, t in ipairs(mark.pile) do t:SetShown(spread) end
	mark.count:SetText(spread and ("%d"):format(#spots / 2) or "")
	mark.count:SetShown(spread)
	mark.countBack:SetShown(spread)
	return mark
end

-- Marks that would overlap at this zoom stand side by side (as the docks do), then each is stood.
local places = {}
function Stand()
	local w, h = View.Size()
	wipe(places)
	for i = 1, usedMarks do places[2 * i - 1], places[2 * i] = marks[i].x, marks[i].y end
	if w and ns.Travel and ns.Travel.Apart then ns.Travel.Apart(places, w, h, K.MARK * 1.25 * View.Grow() / View.Scale()) end
	for i = 1, usedMarks do
		local mark = marks[i]
		mark.sx, mark.sy = places[2 * i - 1], places[2 * i]
		View.Stand(mark, mark.sx, mark.sy)
	end
	Spread()
end

local function Lay()
	Let(false)
	if leaving then Unfocus() end
	rested = nil
	fly.t, fly.want, fly.from, show.t, show.want = 0, 0, nil, 0, 0
	Present()
	usedMarks, usedCopies = 0, 0
	local map = View.Map()
	local quest = Shy.addons.Quest
	local info = map and C_Map.GetMapInfo(map)
	if View.IsOpen() and T.db.rares and quest and quest.Rares and info and info.mapType == Enum.UIMapType.Zone then
		for _, rare in ipairs(quest:Rares(map)) do
			if rare.path then
				local first = rare.path[1]
				local at = 2 * math.floor(#first / 4) + 1
				local mark = Put(rare, first[at] / 9999, first[at + 1] / 9999, {}, false)
				mark.path = rare.path
			else
				local spots = Spots(rare.points)
				if #spots / 2 >= K.SPREAD then
					local x, y = Middle(spots)
					Put(rare, x, y, spots, true)
				else
					for i = 1, #spots - 1, 2 do Put(rare, spots[i], spots[i + 1], spots, false) end
				end
			end
		end
	end
	for i = usedMarks + 1, #marks do
		marks[i].rare = nil
		marks[i]:Hide()
	end
	Stand()
	if sheet then LayLines() end
end

-- Every frame while the map is open: the mark rested on, the rare looked at let go once the mouse is off the
-- map, the copies and the creature on their way, the places breathing, the lines flowing, you followed.
local function Tick(dt)
	if rested and not held then
		local mark = rested.mark
		if mark:IsVisible() and mark:IsMouseOver() and GetTime() >= after then
			rested.t = rested.t + dt
			Charge(mark, rested.t / K.DWELL)
			if rested.t >= K.DWELL then Look(mark) end
		elseif not mark:IsMouseOver() then
			Unrest(mark)
		end
	end
	if held and not (View.Port():IsMouseOver() or catch:IsMouseOver()) then Let(true) end
	if glide and View.Clear() then
		View.Glide(glide.x, glide.y, glide.k / View.Fit())
		glide = nil
	end
	if leaving and (GetTime() >= leaving or not View.Busy()) then Unfocus() end
	if fly.t ~= fly.want then
		fly.t = fly.want > fly.t and math.min(1, fly.t + dt / K.FLY) or math.max(0, fly.t - dt / K.FLY)
		if fly.t == 0 then fly.from = nil end
		Spread()
	end
	if show.t ~= show.want then
		show.t = show.want > show.t and math.min(1, show.t + dt / K.SHOW) or math.max(0, show.t - dt / K.SHOW)
		Present()
	end
	if usedCopies > 0 and fly.t > 0 then
		pulse = (pulse + dt) % K.PULSE
		Breathe()
	end
	if held then
		flow = (flow + dt * K.FLOW) % 1
		trail.t = (trail.t + dt * K.TRAIL) % 1
		Flow()
		local now = GetTime()
		local x, y = View.PlayerAt(View.Map())
		if now >= trail.next then
			trail.next = now + K.TRAIL_EVERY
			if (x == nil) ~= (you == nil) or (x and (math.abs(x - you[1]) + math.abs(y - you[2]) > 1e-4)) then LayTrail() end
		end
		View.Stand(beacon, x, y)
		local f = (GetTime() % 1.6) / 1.6
		beacon.ring:SetSize(30 * (1 + 1.6 * f), 30 * (1 + 1.6 * f))
		beacon.ring:SetAlpha(0.8 * (1 - f))
	end
end

-- What stands on the map now: { { mark, copies = { copy } } } (copies: those of the rare looked at, while out); the
-- mark looked at alone.
function Rares.Shown()
	local out = {}
	for i = 1, usedMarks do
		local mark = marks[i]
		local list = {}
		if mark == fly.from then
			for j = 1, usedCopies do list[#list + 1] = copies[j] end
		end
		out[#out + 1] = { mark = mark, copies = list }
	end
	return out, held
end

function Rares.Lines() return usedLines + (trail.on and held and 1 or 0) end

-- The creature beside the rare looked at: its frame (name, level, rows, hint, model, side, rect).
function Rares.Plate() return plate end
-- What is over the map while one is looked at, to take a click or the wheel.
function Rares.Catch() return catch end

local function Build()
	local lift = View.Lift()
	sheet = CreateFrame("Frame", nil, lift)
	sheet:SetAllPoints()
	sheet:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_FLIGHT_ROUTES"))
	beacon = View.Pin("PIN_FRAME_LEVEL_GROUP_MEMBER", 26)
	beacon:SetParent(lift)
	beacon:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_GROUP_MEMBER") + 4)
	local light = Shy.Theme.light
	beacon.glow = beacon:CreateTexture(nil, "BACKGROUND")
	beacon.glow:SetTexture(K.GLOW)
	beacon.glow:SetBlendMode("ADD")
	beacon.glow:SetPoint("CENTER")
	beacon.glow:SetSize(64, 64)
	UI.Tint(beacon.glow, light, 0.55)
	beacon.ring = beacon:CreateTexture(nil, "BORDER")
	beacon.ring:SetTexture(K.RING)
	beacon.ring:SetBlendMode("ADD")
	beacon.ring:SetPoint("CENTER")
	UI.Tint(beacon.ring, light, 1)
	catch = CreateFrame("Frame", nil, View.Chrome())
	catch:SetAllPoints()
	catch:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 20)
	catch:EnableMouse(true)
	catch:EnableMouseWheel(true)
	catch:SetScript("OnMouseDown", function() Let(true) end)
	-- (The wheel lets it go and zooms from where it is, as the map's own wheel does.)
	catch:SetScript("OnMouseWheel", function(_, delta)
		Let(false)
		local port = View.Port()
		local wheel = port:GetScript("OnMouseWheel")
		if wheel then wheel(port, delta) end
	end)
	catch:Hide()
end

ns.Layer({
	id = "rares",
	later = true,
	Use = function(on)
		if on and not sheet then Build() end
		if not on then Lay() end
	end,
	Map = Lay,
	Scale = function()
		-- (In a focus the marks are out of sight: stood as it ends. Its copies are stood at each step.)
		if View.Focused() then
			stale = true
			Spread()
		else
			Stand()
		end
		if held then LayLines() end
		if beacon and beacon:IsShown() and beacon.x then View.Stand(beacon, beacon.x, beacon.y) end
	end,
	Tick = Tick,
	Close = function()
		Let(false)
		if leaving then Unfocus() end
		rested = nil
		fly.t, fly.want, fly.from, show.t, show.want = 0, 0, nil, 0, 0
		Spread()
		Present()
	end,
})

ns.OnApply(function()
	if View.IsOpen() then Lay() end
end)
