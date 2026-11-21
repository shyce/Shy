-- Shy.Maps: lines on the world map and the minimap, for every addon that draws there.
--
-- A pen draws on one map: on a frame of the world map's canvas (from its top left, y down, in canvas
-- units) or on the minimap (from its middle, y up). pen.unit is one screen pixel at the world map's size,
-- in the pen's units: every thickness below is in those pixels, so a line keeps its look at any zoom.
--
--   Shy.Maps.Pen(owner, point, anchor, down, over) -> pen
--        owner: the frame its lines are made on; point, anchor: what positions are measured from;
--        down: y grows downward (the world map); over: its strokes go over those of other pens on the
--        same frame
--   Shy.Maps.Begin(pen, unit), Shy.Maps.Finish(pen)       -- a pen's strokes are laid between the two
--   Shy.Maps.Segment(pen, ax, ay, bx, by, thick, alpha, color, depth) -> which of its lines is lit
--        one straight piece: `color` (moonlight, Maps.LIGHT, for none) over a soft shadow, on a soft halo of the color.
--        depth: the level it runs on: 0 the ground, down to -1 under it (its edge melting into a glow of its
--        color: Maps.BELOW), up to 1 a level over it (broader, over a wider shadow), by degrees between
--        pen.quiet: the pen's plain strokes have no halo (a quiet line: the halo is a lit one's)
--   Shy.Maps.Ribbon(pen, xs, ys, count, color)            -- a ribbon through count points, wide and bright at
--        the first and fine at the last, in `color` (the trail's, Maps.TrailColor, for none) in a crisp dark case
--        (Maps.CASE) with a comet running along it (Shine);
--        xs.depth[i]: point i's level;
--        xs.fall[i], xs.water[i]: how much of the stretch ending at point i is a slowed fall or walked on
--        water, 0 to 1 (Maps.AIR)
--   Shy.Maps.Shine(pen, now)                              -- runs the comet on: call it every frame
--   Shy.Maps.Start(pen, x, y, head) -> stray              -- a trail laid once (on a plate that slides) begins
--        where the player at (x, y) now is, clear of a circle `head` round them: the pieces behind are out of
--        sight, the first cut short. Returns how far the player has strayed from it (lay it again past a little)
--   pen.mask: a mask texture every region the pen makes is masked by (the minimap's round rim)
--   Shy.Maps.TrailColor() -> r, g, b                      -- the trail's color: the theme's accent, as it is now
--   Shy.Maps.LIGHT                                        -- moonlight: a journey's, or a stroke's, given no color
--   Shy.Maps.Trim(xs, ys, count, head, tail) -> count     -- cut `head` off a line's start and `tail` off its end
--   Shy.Maps.Smooth(flat, bend) -> line                   -- a smooth line through world points (flat: north, west,
--        ...), as a flight or a ship follows one: { north, west, n, along (yards to each), point }
--   Shy.Maps.Nearest(line, north, west, from, to) -> i, yards   -- the point of a line nearest a place
--   Shy.Maps.Within(ax, ay, bx, by, square, edge)         -- the part of a segment inside the minimap (points as
--        shares of its range): x1, y1, x2, y2, and whether the far end was cut; nil when none is inside.
--        edge: Maps.EDGE (where a pin waits at the rim, the default) or Maps.RIM (a line with no pin at its end)
--   Shy.Maps.RimMask(mask, radius, square)                -- shape a mask texture to the minimap's rim, its edge a
--        soft fade (set it on a pen's .mask: every line on the minimap melts away at the rim)
--   Shy.Maps.Mini(view) -> view or nil                   -- the minimap now: reach (yards to its rim), radius,
--        continent, north, west (where the player is), sin, cos (its turn), square; nil while unknown
--   Shy.Maps.OnMini(view, north, west) -> x, y            -- a place on the minimap, as shares of its range
--   Shy.Maps.MapLayer(above) -> frame                     -- a frame over the world map's canvas, at the level
--        of the game's quest pins (+ above)
--   Shy.Maps.Open(map) -> opened                          -- the map you use opened on `map`: ShyMaps' window
--        while ShyMaps is on (its :ShowMap), else the game's (not in a fight: the game's map is not ours to open)
--   Shy.Maps.Hush(who, on)                                -- every addon's layers out of sight while any `who` hushes
--        them (ShyMaps inside an instance), back as the last lets go
--   Shy.Maps.MapScale() -> unit, grow                     -- one screen pixel in canvas units, and the growth
--        with zoom ShyQuest's pins have
--   Shy.Maps.OnMap(fn)                                    -- fn() when the world map opens, changes map, zoom or size
--   Shy.Maps.Lead(who, continent, north, west [, line, first, last]), Shy.Maps.Led()   -- where you are led, for
--        a map that looks ahead (see "Where you are led")
--   Shy.Maps.ToMap(map, continent, north, west) -> x, y   -- a place as shares of a map (beyond 0-1 off it)
--   Shy.Maps.LineToMap(map, continent, norths, wests, count, xs, ys)   -- a line's points likewise, into xs and
--        ys (false where one has no place), without asking the game of each
--   Shy.Maps.Mark(parent, size) -> mark                   -- the family's mark on a map (see "Marks");
--        mark:Set(sign, color, lit), sign one of Shy.Maps.SIGNS
--   Shy.Maps.TRAIL                                        -- the ribbon's look (thicknesses, gleam)
--   Shy.Maps.DEPTH                                        -- how a stroke off the ground looks
--   Shy.Maps.Tag(pen, tag)                                -- the strokes laid from now on are `tag`'s (nil: no one's)
--   Shy.Maps.Hit(pen, x, y, reach) -> tag                 -- the tag of the stroke nearest (x, y) (in the pen's units,
--        as strokes are laid), if its edge is within `reach`; nil for none. Lines take no mouse: this is how
--        the line under the mouse is found
--
-- A pen keeps its lines and reuses them stroke after stroke: lay every stroke of a pen between Begin and
-- Finish each time anything moves (Finish hides what this round didn't use). Several ribbons may share a
-- pen; Shine runs the gleam along all of them.

local UI = Shy.UI

local Maps = {}
Shy.Maps = Maps

local AREA = Shy.MEDIA .. "Area"
-- Crisp strokes. The Stroke texture holds `count` cross-sections side by side (`texels` each, `wide` in all),
-- band k for a stroke `from` * (`to` / `from`) ^ ((k - 1) / (count - 1)) screen pixels across its texture:
-- solid, an edge one screen pixel wide, half a pixel clear past it. A stroke wears the band for its width on
-- screen, so its edge fades over one pixel at any width, scale or zoom: sharp, and never a staircase. (An
-- edge that fades over a share of the width is under a pixel on a fine line: stepped; over a wide one: blurred.)
local BAND = { count = 32, from = 2.5, to = 48, texels = 4, wide = 128 }
BAND.step = math.log(BAND.to / BAND.from) / (BAND.count - 1)
local STROKE = Shy.MEDIA .. "Stroke"
local PAD = 2         -- screen pixels a crisp stroke's texture runs past its edges: the fade, and clear room
local CRISP = 0.75    -- a crisp stroke's edge, as a share of the width it is given (the soft strip's that it replaced)
local HALO, HALO_ALPHA = 9, 0.22   -- extra width of the soft halo round a stroke, and its alpha
-- The soft shadow under a stroke, which lets it stand off light ground as well as dark: its extra width
-- and its alpha. Soft all the way out, so it never shows as a rim (a hard one is jagged where pieces meet).
-- A fainter stroke's shadow fades faster than its color (Shade): a quiet line fades into the ground, not
-- into a dark band with a dull color down it.
local SHADE, SHADE_ALPHA = 4.5, 0.5
local function Shade(alpha)
	return SHADE_ALPHA * alpha * alpha
end
Maps.EDGE = 0.86             -- how far toward the minimap's rim a pin may sit
Maps.RIM = 0.98              -- where a line that runs on off the minimap is cut: the rim
Maps.OVER = 0.85             -- the scale of everything laid over the map's window (Maps.Over, ShyMaps' plate): the map gets the room
-- The ribbon: a tube of light. A pale core (its color `core` of the way to white) on a soft shadow, in a
-- glow of its color, so it stands off any ground whatever the color. Its core's thickness at the start
-- and the end; pieces no longer than `piece` and points no nearer than `least`; its alpha at the end; the
-- core's alpha while the comet isn't passing; seconds per comet. (The core stays all but opaque: where
-- two pieces of a see-through line meet, the seam shows across it.)
-- The comet: a white-hot spark `spark` ribbon widths across in a bloom `bloom` widths across (at
-- `bloomAlpha`), its light rising over `head` of the ribbon ahead of it and fading over `tail` behind;
-- the ribbon's glow is `glow` times a plain stroke's halo at rest and `flare` times as the comet passes.
Maps.TRAIL = { wide = 5.4, fine = 3, piece = 9, least = 3, fade = 0.92, rest = 1, every = 1.9,
	spark = 2.2, bloom = 6.5, bloomAlpha = 0.55, head = 0.05, tail = 0.4, glow = 2, flare = 3.6 }
-- A ribbon's case (every ribbon but a journey's): its color inked round with a crisp dark edge, which stands it
-- off any ground, light or dark, whatever the color. The edge `edge` pixels (pen units) each side and never
-- under `least` screen pixels, `ink` at `alpha`; the color's own stroke never under `core` screen pixels. Down
-- its middle a gleam, `gleam` of its width, its color `light` of the way to white at `shine`, only on a broad
-- stroke: fading in as it widens from `none` screen pixels to `full`. Under it all a soft shadow, `spread`
-- pixels wider than the case, at `shadow`. (A glow of the color round the dark edge, or a gleam down a fine
-- line, read as stripes: the line looked doubled, not crisp.)
Maps.CASE = { edge = 1.2, least = 1.25, ink = { 0.02, 0.02, 0.03 }, alpha = 0.95, core = 1.5,
	gleam = 0.34, light = 0.6, shine = 0.6, full = 7, none = 4.5, spread = 4, shadow = 0.4 }
-- A journey's look (Ribbon's `look`; Shy.Maps.Trip): in its case as a trail is (Maps.CASE), in the color of
-- its kind (a flight's, a boat's, a zeppelin's), and told from a trail at a glance: it keeps its width `wide`
-- all the way (a trail tapers), with no gleam down it and no comet along it.
Maps.JOURNEY = { wide = 4.6 }
-- A stroke off the ground. A level up: its halo's share gained, how much darker and wider its shadow, how
-- much broader the stroke. edge: how near the world map's edge a line to a place off the map runs, as a
-- share of the map.
Maps.DEPTH = { overHalo = 0.45, shade = 0.7, shadow = 1.5, wide = 0.2, edge = 0.004 }
-- Under the ground (a cave, a hall, a tunnel, a city's covered ways) a stroke is light seen through it: its
-- dark edge dissolves into a soft glow of its own color and the stroke itself grows paler, as though lit from
-- beneath. All by degrees as the way goes under (depth 0 to -1, eased), so a line going in at a door melts
-- into its glow and comes back out of it, one line all the way. At full depth: the edge kept at `edge` of its
-- strength (a pale color still reads on pale ground), the glow `glow` strong and `spread` pixels wider than
-- the edge, the stroke `pale` of the way to white and `thin` of its width.
Maps.BELOW = { edge = 0.25, glow = 0.42, spread = 7, pale = 0.28, thin = 0.86 }
-- A stretch of a ribbon not walked on the ground (Ribbon's xs.fall and xs.water): a fall slowed off a cliff
-- turns toward the pale of the open sky and fines down, a contrail; water walked on turns partly toward
-- the sea's glass. `share` of the way to the color, the stroke's width times `thin`.
Maps.AIR = { fall = { color = { 0.84, 0.94, 1.00 }, share = 0.85, thin = 0.6 }, water = { color = { 0.40, 0.86, 0.92 }, share = 0.55, thin = 1.12 } }

-- Where you are led
--
-- Whoever draws the way you follow says where it goes, and a map that keeps you in its middle looks ahead
-- along it. `who`: a key of the leader's own (several may lead; the one that began last is followed).
--   Shy.Maps.Lead(who, continent, north, west [, line, first, last])
--        the place led to, and the line there where the leader has one of its own (a flight's, a boat's:
--        { north = {}, west = {}, n }, from its point `first`, the next ahead of you, to `last`). With no
--        line the way is the trail kept to the place (Shy.Way.Trailed), or straight at it.
--        No continent: `who` leads nowhere now.
--   Shy.Maps.Led() -> continent, north, west, line, first, last     nil while nobody leads
local leads, leading, began = {}, nil, 0
function Maps.Lead(who, continent, north, west, line, first, last)
	local lead = leads[who]
	if not (continent and north and west) then
		if not (lead and lead.continent) then return end
		lead.continent, lead.line = nil, nil
		if leading == lead then
			leading = nil
			for _, other in pairs(leads) do
				if other.continent and (not leading or other.since > leading.since) then leading = other end
			end
		end
		return
	end
	if not lead then
		lead = {}
		leads[who] = lead
	end
	if not lead.continent then
		began = began + 1
		lead.since, leading = began, lead
	end
	lead.continent, lead.north, lead.west, lead.line, lead.first, lead.last = continent, north, west, line, first, last
end

function Maps.Led()
	local lead = leading
	if not lead then return nil end
	return lead.continent, lead.north, lead.west, lead.line, lead.first, lead.last
end

-- A line's regions are set only where something changed: the maps lay every line again many times a
-- second, mostly as it already stands. Each region keeps what it was last given (.up, .alpha, .r, .g, .b,
-- .a); only this file shows, hides, fades or colors them.
-- The game rebuilds a region's picture where it is shown again or placed anew (Fit), and what it keeps of
-- the color and alpha then is not always what it was given (a leg's shadow came back black and solid, and
-- stayed so until a zoom placed it again). So at those two moments a region is given its color and alpha
-- over again; between them, nothing is set that already stands.
local function Up(region)
	if not region.up then
		region.up = true
		region:Show()
		-- (Back in sight: colored and faded again by whoever lays it, this round.)
		region.r, region.alpha = nil, nil
	end
end

-- The color and alpha a region was last given, given again (Fit).
local function Again(region)
	if region.r ~= nil then region:SetVertexColor(region.r, region.g, region.b, region.a) end
	if region.alpha ~= nil then region:SetAlpha(region.alpha) end
end

local function Down(region)
	if region.up ~= false then
		region.up = false
		region:Hide()
	end
end

local function Alpha(region, alpha)
	if region.alpha ~= alpha then
		region.alpha = alpha
		region:SetAlpha(alpha)
	end
end

-- Its color, through the theme (UI.Tint) whenever it changes, so a theme color still follows the accent.
local function Tint(region, color, alpha)
	local r, g, b, a
	if type(color) == "function" then
		r, g, b, a = color()
	else
		r, g, b, a = color[1], color[2], color[3], color[4]
	end
	a = alpha or a or 1
	if region.r ~= r or region.g ~= g or region.b ~= b or region.a ~= a then
		region.r, region.g, region.b, region.a = r, g, b, a
		UI.Tint(region, color, alpha)
	end
end

-- A color of its own (a shadow), not the theme's.
local function Color(region, r, g, b, a)
	if region.r ~= r or region.g ~= g or region.b ~= b or region.a ~= a then
		region.r, region.g, region.b, region.a = r, g, b, a
		region:SetVertexColor(r, g, b, a)
	end
end

-- Pens

function Maps.Pen(owner, point, anchor, down, over)
	return { owner = owner, point = point, anchor = anchor, down = down, unit = 1, px = 1, pad = PAD, lines = { used = 0 }, sub = over and 3 or 0 }
end

-- Screen pixels a pen unit (pen.px) where its owner stands now, and a crisp stroke's room in pen units.
local function Pixels(pen)
	local scale = pen.owner:GetEffectiveScale()
	if scale and scale > 0 then
		pen.px = scale / PixelUtil.GetPixelToUIUnitFactor()
		pen.pad = PAD / pen.px
	end
end

local Settle   -- (Joints, below.)
local Whole    -- (Start, below.)

function Maps.Begin(pen, unit)
	Settle(pen)
	Whole(pen)
	Pixels(pen)
	pen.unit, pen.lines.used, pen.path, pen.trail, pen.tag = unit, 0, nil, nil, nil
	if pen.traced then pen.traced.n = 0 end
end

-- Tagged strokes: each one's ends and half its width, kept in the pen's own lists as it is laid.
function Maps.Tag(pen, tag)
	pen.tag = tag
	if tag ~= nil and not pen.traced then pen.traced = { n = 0, ax = {}, ay = {}, bx = {}, by = {}, half = {}, tag = {} } end
end

local function Trace(pen, ax, ay, bx, by, half)
	local t = pen.traced
	local n = t.n + 1
	t.n, t.ax[n], t.ay[n], t.bx[n], t.by[n], t.half[n], t.tag[n] = n, ax, ay, bx, by, half, pen.tag
end

function Maps.Hit(pen, x, y, reach)
	local t = pen.traced
	if not t then return nil end
	local best, tag = reach, nil
	for i = 1, t.n do
		local ax, ay = t.ax[i], t.ay[i]
		local dx, dy = t.bx[i] - ax, t.by[i] - ay
		local span = dx * dx + dy * dy
		local along = span > 0 and math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy) / span)) or 0
		local off = math.sqrt((x - ax - dx * along) ^ 2 + (y - ay - dy * along) ^ 2) - t.half[i]
		if off <= best then best, tag = off, t.tag[i] end
	end
	return tag
end

function Maps.Finish(pen)
	Settle(pen)
	local pool = pen.lines
	for i = pool.used + 1, pool.shown or #pool do
		for _, line in ipairs(pool[i]) do Down(line) end
	end
	pool.shown = pool.used
	if not pen.trail and pen.comet then
		Down(pen.comet[1])
		Down(pen.comet[2])
	end
end

local function Lighter(color, by)
	return { color[1] + (1 - color[1]) * by, color[2] + (1 - color[2]) * by, color[3] + (1 - color[3]) * by }
end

-- Moonlight, a cool white-blue: a journey's light where it is given no color of its own.
Maps.LIGHT = { 0.62, 0.78, 1.00 }

-- The trail's color: the theme's accent, as the theme has it now, so the trail follows it. Its dark case
-- (Maps.CASE) stands it off any ground. The gleam down its middle and the comet's spark are paler: of the
-- way to white.
local Theme = Shy.Theme
local function Toward(r, g, b, by)
	return r + (1 - r) * by, g + (1 - g) * by, b + (1 - b) * by
end
function Maps.TrailColor()
	return Theme.Accent()
end
local function TrailGleam()
	local r, g, b = Theme.Accent()
	return Toward(r, g, b, Maps.CASE.light)
end
local function TrailSpark()
	local r, g, b = Theme.Accent()
	return Toward(r, g, b, 0.8)
end

-- A caller's color `by` of the way to white: a color as it was given (a table, or a function the theme reads).
local function Pale(color, by)
	if type(color) == "function" then
		return function()
			local r, g, b = color()
			return Toward(r, g, b, by)
		end
	end
	return Lighter(color, by)
end

-- A region of a line, laid where its points fall to the fraction of a pixel. Snapped to the screen's
-- pixels, as regions are unless told, a thin line at a slant is a staircase, and one that moves shimmers.
local function Unsnapped(region)
	region:SetSnapToPixelGrid(false)
	region:SetTexelSnappingBias(0)
	return region
end

-- A crisp stroke: the Stroke texture, its band chosen as it is laid (Band).
local function Crisp(texture)
	texture:SetTexture(STROKE, "CLAMP", "CLAMP")
	texture.crisp, texture.band = true, nil
	return texture
end

-- How wide a stroke's texture is laid, in pen units: a crisp one's edge (.wide) and the room for its fade.
local function Span(pen, texture)
	if texture.crisp then return texture.wide + (pen.pad or PAD) end
	return texture.wide
end

-- A crisp stroke's band, for `span` pen units across (Span) on screen.
local function Band(pen, texture, span)
	local k = math.floor(math.log(math.max(span * (pen.px or 1), BAND.from) / BAND.from) / BAND.step + 1.5)
	if k > BAND.count then k = BAND.count end
	if texture.band ~= k then
		texture.band = k
		local u = (k - 0.5) * BAND.texels / BAND.wide
		texture:SetTexCoord(u, u, 0, 1)
	end
end

-- A stroke's second line: the soft shadow under it, or (case) the crisp dark case round a ribbon.
local function Under(line, case)
	if line.case == case then return end
	line.case = case
	if case then
		Crisp(line)
	else
		line.crisp = nil
		line:SetTexture(AREA)
		line:SetTexCoord(0.49, 0.51, 0, 1)
	end
end

-- Joints
-- A line of pieces is drawn as one band, as the game draws its quest areas. Each of a piece's strokes is
-- a texture whose four corners are set where they belong (SetVertexOffset), and where a piece starts where
-- the one before it ended, the two share their corners at the turn, on the line that halves it. Nothing
-- overlaps and nothing gaps, so a see-through line shows no seam where its pieces meet. A shared corner
-- comes in no farther along than half the shorter piece (a piece is never folded over itself) and sits no
-- more than MITER half-widths out (a hairpin's point is cut short).
local MITER = 3

-- One stroke of a piece: a texture, its corners moved where they belong (Fit).
local function Piece(pen, sub)
	local texture = Unsnapped(pen.owner:CreateTexture(nil, "ARTWORK", nil, sub))
	texture.corner = {}
	if pen.mask then texture:AddMaskTexture(pen.mask) end
	return texture
end

-- A stroke's ends across: its left and right corners at the start (from 1) or the end (from 5), half `h`
-- either side of (x, y) along the normal (nx, ny). Pen units, y up.
local function Ends(corner, from, x, y, nx, ny, h)
	corner[from], corner[from + 1], corner[from + 2], corner[from + 3] = x + nx * h, y + ny * h, x - nx * h, y - ny * h
end

-- A stroke where its corners are: its rect is the box round all four, each corner moved from that box's
-- own. Its texture's top runs down the left of its way, as a Line's does.
-- The game culls and clips a region by its rect, never by where its corners were moved: a rect smaller
-- than the stroke would take the stroke out of sight wherever the rect left the map's window or fell
-- under a pixel, however much of the stroke was on screen. So the rect holds the whole stroke, and is
-- never under a screen pixel across (pen.unit).
-- (Set only where it moved: texture.fit holds what it was last given.)
local function Fit(pen, texture)
	local c = texture.corner
	local left, right = math.min(c[1], c[3], c[5], c[7]), math.max(c[1], c[3], c[5], c[7])
	local bottom, top = math.min(c[2], c[4], c[6], c[8]), math.max(c[2], c[4], c[6], c[8])
	local least = pen.unit
	if right - left < least then
		local middle = (left + right) / 2
		left, right = middle - least / 2, middle + least / 2
	end
	if top - bottom < least then
		local middle = (bottom + top) / 2
		bottom, top = middle - least / 2, middle + least / 2
	end
	local f = texture.fit
	if not f then
		f = {}
		texture.fit = f
	elseif f[1] == left and f[2] == right and f[3] == bottom and f[4] == top and f[5] == c[1] and f[6] == c[2] and f[7] == c[3]
		and f[8] == c[4] and f[9] == c[5] and f[10] == c[6] and f[11] == c[7] and f[12] == c[8] and f[13] == pen.anchor then
		return
	end
	f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11], f[12], f[13] = left, right, bottom, top, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], pen.anchor
	texture:SetSize(right - left, top - bottom)
	texture:SetPoint("CENTER", pen.anchor, pen.point, (left + right) / 2, (bottom + top) / 2)
	texture:SetVertexOffset(UPPER_LEFT_VERTEX, c[1] - left, c[2] - top)
	texture:SetVertexOffset(LOWER_LEFT_VERTEX, c[3] - left, c[4] - bottom)
	texture:SetVertexOffset(UPPER_RIGHT_VERTEX, c[5] - right, c[6] - top)
	texture:SetVertexOffset(LOWER_RIGHT_VERTEX, c[7] - right, c[8] - bottom)
	Again(texture)
end

-- The last piece laid is placed only once the next one is laid (which may share its end) or the pen is
-- finished: each stroke is placed once a round.
Settle = function(pen)
	local set = pen.pending
	if not set then return end
	pen.pending = nil
	for i = 1, set.count do Fit(pen, set[i]) end
end

-- Lay a piece's first `count` strokes (each .wide across) from a to b, joined to the piece before it when
-- it starts where that one ended.
local function Lay(pen, set, ax, ay, bx, by, count)
	local sign = pen.down and -1 or 1
	ay, by = ay * sign, by * sign
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	local nx, ny = 0, 1
	if length > 0 then nx, ny = -dy / length, dx / length end
	local pool = pen.lines
	local before = pool.used > 1 and pool[pool.used - 1]
	local mx, my, cos, sin, reach
	if before and before.length > 0 and length > 0 and math.abs(before.bx - ax) + math.abs(before.by - ay) <= pen.unit * 0.01 then
		mx, my = before.nx + nx, before.ny + ny
		local m = math.sqrt(mx * mx + my * my)
		if m > 0.01 then
			mx, my = mx / m, my / m
			cos = mx * nx + my * ny
			sin = math.sqrt(math.max(0, 1 - cos * cos))
			reach = math.min(before.length, length) / 2
		else
			-- (It turns straight back: two square ends.)
			mx = nil
		end
	end
	for i = 1, count do
		local texture = set[i]
		local corner = texture.corner
		local span = Span(pen, texture)
		if texture.crisp then Band(pen, texture, span) end
		Ends(corner, 5, bx, by, nx, ny, span / 2)
		local prior = mx and i <= before.count and before[i]
		local h, s
		if prior then
			h = (Span(pen, prior) + span) / 4
			s = math.min(MITER, 1 / cos)
			if h * s * sin > reach then s = reach / (h * sin) end
			-- (A piece too short for the turn would bring the shared corner in under the stroke's own width,
			-- and the long piece beside it is drawn down to a point: the two keep their square ends there.)
			if s < 1 then prior = nil end
		end
		if prior then
			Ends(corner, 1, ax, ay, mx, my, h * s)
			Ends(prior.corner, 5, ax, ay, mx, my, h * s)
		else
			Ends(corner, 1, ax, ay, nx, ny, span / 2)
		end
	end
	-- (The piece before, its end now known; this one once the next is laid.)
	Settle(pen)
	pen.pending = set
	set.ax, set.ay, set.bx, set.by, set.nx, set.ny, set.length, set.count = ax, ay, bx, by, nx, ny, length, count
end

-- A piece's fourth stroke, over its others, made the first time it is asked for, in sight: a ribbon's
-- gleam, or a journey's core.
local function Over(pen, set, i)
	if not set[i] then set[i] = Crisp(Piece(pen, pen.sub + i - 1)) end
	-- (In sight first: Up forgets what a region back in sight was given, so it is faded and colored after.)
	Up(set[i])
	Alpha(set[i], 1)
	return set[i]
end

-- A color as it was given (a table, or a function the theme reads): r, g, b.
local function RGB(color)
	if type(color) == "function" then
		local r, g, b = color()
		return r, g, b
	end
	return color[1], color[2], color[3]
end

-- How far under the ground a stroke at `depth` is, eased (Maps.BELOW): 0 on it, 1 fully under.
local function Below(depth)
	local below = depth and depth < 0 and math.min(1, -depth) or 0
	return below * below * (3 - 2 * below)
end

-- A ribbon in its case (Maps.CASE): its color, in a crisp dark edge, with a pale gleam down its middle where
-- it is broad, on a soft shadow. Raised (depth over 0), broader on a deeper shadow. Under the ground (depth
-- under 0, Maps.BELOW) the edge melts into a glow of its color and the stroke pales. Which is lit, and how
-- many strokes it has.
local function Cased(pen, set, thick, alpha, color, depth, journey)
	local CASE, DEPTH, BELOW, px = Maps.CASE, Maps.DEPTH, Maps.BELOW, pen.px or 1
	local raised = depth and depth > 0 and depth or 0
	local below = Below(depth)
	local core = math.max(thick * CRISP * (1 + DEPTH.wide * raised) * (1 + (BELOW.thin - 1) * below) * pen.unit, CASE.core / px)
	local edge = math.max(CASE.edge * pen.unit, CASE.least / px)
	-- (Its shadow holds still: the comet flares no glow round a cased ribbon, Shine.)
	set.cased = true
	-- The soft shadow under it, turning into a glow of its color as it goes under.
	local shadow = CASE.shadow * (1 + DEPTH.shade * raised)
	if below > 0 then
		local r, g, b = RGB(color)
		Color(set[1], r * below, g * below, b * below, math.min(1, (shadow + (BELOW.glow - shadow) * below) * alpha))
	else
		Color(set[1], 0, 0, 0, math.min(1, shadow * alpha))
	end
	set[1].wide = core + 2 * edge + (CASE.spread * (1 + DEPTH.shadow * raised) + (BELOW.spread - CASE.spread) * below) * pen.unit
	Under(set[2], true)
	local ink = CASE.ink
	Color(set[2], ink[1], ink[2], ink[3], CASE.alpha * alpha * (1 - (1 - BELOW.edge) * below))
	set[2].wide = core + 2 * edge
	Alpha(set[2], 1)
	if below > 0 then
		local r, g, b = RGB(color)
		r, g, b = Toward(r, g, b, BELOW.pale * below)
		Color(set[3], r, g, b, alpha)
	else
		Tint(set[3], color, alpha)
	end
	set[3].wide = core
	-- (A journey: even, its color its kind's, no gleam down it.)
	local shine = journey and 0 or CASE.shine * (1 - below) * math.min(1, math.max(0, (core * px - CASE.none) / (CASE.full - CASE.none)))
	if shine <= 0 then
		if set[4] then Down(set[4]) end
		return 3, 3
	end
	local gleam = Over(pen, set, 4)
	Tint(gleam, pen.gleam or color, shine * alpha)
	gleam.wide = core * CASE.gleam
	return 3, 4
end

-- How the strokes of a piece look; their widths (.wide, in pen units: a crisp one's to its edges), laid by
-- Lay. Which is lit, and how many strokes it has.
local function Dress(pen, set, thick, alpha, color, depth, look, glow, halo)
	-- (Shine dims a trail's halo between comets.)
	Alpha(set[1], 1)
	set.cased = nil
	color = color or Maps.LIGHT
	glow, halo = glow or 1, halo or color
	-- A journey: in its case as a trail is, even all the way, in its own color (Maps.JOURNEY).
	if look then return Cased(pen, set, thick, alpha, color, depth, true) end
	if pen.cased then return Cased(pen, set, thick, alpha, color, depth) end
	if set[4] then Down(set[4]) end
	if depth and depth > 0 then
		local DEPTH = Maps.DEPTH
		local raised = depth
		Tint(set[1], halo, math.min(1, HALO_ALPHA * glow * alpha * (1 + DEPTH.overHalo * raised)))
		set[1].wide = (thick + HALO) * pen.unit
		Under(set[2], false)
		Color(set[2], 0, 0, 0, math.min(1, Shade(alpha) * (1 + DEPTH.shade * raised)))
		set[2].wide = (thick + SHADE * (1 + DEPTH.shadow * raised)) * pen.unit
		Alpha(set[2], 1)
		Tint(set[3], color, alpha)
		set[3].wide = thick * (1 + DEPTH.wide * raised) * pen.unit * CRISP
		return 3, 3
	end
	-- (Under the ground, Maps.BELOW: its shadow fades, its halo grows into a glow and the stroke pales.)
	local BELOW, below = Maps.BELOW, Below(depth)
	Tint(set[1], halo, math.min(1, HALO_ALPHA * glow * alpha * (1 + 2 * below)))
	set[1].wide = (thick + HALO + BELOW.spread * below) * pen.unit
	Under(set[2], false)
	Color(set[2], 0, 0, 0, Shade(alpha) * (1 - (1 - BELOW.edge) * below))
	set[2].wide = (thick + SHADE) * pen.unit
	Alpha(set[2], 1)
	if below > 0 then
		local r, g, b = RGB(color)
		r, g, b = Toward(r, g, b, BELOW.pale * below)
		Color(set[3], r, g, b, alpha)
	else
		Tint(set[3], color, alpha)
	end
	set[3].wide = thick * (1 + (BELOW.thin - 1) * below) * pen.unit * CRISP
	return 3, 3
end

-- look: a journey's (Maps.JOURNEY): even all the way, in its case, no gleam.
-- glow: the halo this many times a plain stroke's (a trail's, which its comet flares). halo: its color,
-- where that isn't the stroke's (a trail's glow round its pale core).
function Maps.Segment(pen, ax, ay, bx, by, thick, alpha, color, depth, look, glow, halo)
	local pool = pen.lines
	pen.laid = (pen.laid or 0) + 1   -- (counts its pieces laid, ever: Shine looks at them again)
	pool.used = pool.used + 1
	local set = pool[pool.used]
	if not set then
		local sub = pen.sub
		set = { Piece(pen, sub), Piece(pen, sub + 1), Piece(pen, sub + 2) }
		-- Across the soft disc's middle: full along the halo's own middle, gone at its edges.
		set[1]:SetTexture(AREA)
		set[1]:SetTexCoord(0.49, 0.51, 0, 1)
		Under(set[2], false)
		Crisp(set[3])
		pool[pool.used] = set
	end
	if pen.tag ~= nil then Trace(pen, ax, ay, bx, by, thick * pen.unit / 2) end
	-- (pen.quiet: a plain stroke given no glow has no halo: its first line stays out of sight.)
	if glow == nil and pen.quiet then glow = 0 end
	local bare = glow == 0 and not look and not pen.cased
	if bare then Down(set[1]) else Up(set[1]) end
	Up(set[2])
	Up(set[3])
	local lit, count = Dress(pen, set, thick, alpha, color, depth, look, glow, halo)
	Lay(pen, set, ax, ay, bx, by, count)
	return lit
end

-- Lines of points

function Maps.Trim(xs, ys, count, head, tail)
	local whole = 0
	for i = 2, count do whole = whole + math.sqrt((xs[i] - xs[i - 1]) ^ 2 + (ys[i] - ys[i - 1]) ^ 2) end
	if whole <= head + tail then return 0 end
	local left = tail
	while left > 0 do
		local dx, dy = xs[count] - xs[count - 1], ys[count] - ys[count - 1]
		local length = math.sqrt(dx * dx + dy * dy)
		if length > left then
			xs[count], ys[count] = xs[count] - dx * left / length, ys[count] - dy * left / length
			left = 0
		else
			left = left - length
			count = count - 1
		end
	end
	local first = 1
	left = head
	while left > 0 do
		local dx, dy = xs[first + 1] - xs[first], ys[first + 1] - ys[first]
		local length = math.sqrt(dx * dx + dy * dy)
		if length > left then
			xs[first], ys[first] = xs[first] + dx * left / length, ys[first] + dy * left / length
			left = 0
		else
			left = left - length
			first = first + 1
		end
	end
	if first > 1 then
		local depth, fall, water = xs.depth, xs.fall, xs.water
		for i = first, count do
			xs[i - first + 1], ys[i - first + 1] = xs[i], ys[i]
			if depth then depth[i - first + 1] = depth[i] end
			if fall then fall[i - first + 1] = fall[i] end
			if water then water[i - first + 1] = water[i] end
		end
		count = count - first + 1
	end
	return count
end

-- How much of a stretch is in the air or on water at `t` of the way along it: its own share in the middle,
-- easing over its first and last EASE to halfway toward the stretch either side, so it fades in and out.
local EASE = 0.25
local function Share(list, i, t, count)
	local here = list[i] or 0
	if t < EASE then
		local before = i > 2 and (list[i - 1] or 0) or here
		return before + (here - before) * (0.5 + 0.5 * t / EASE)
	elseif t > 1 - EASE then
		local after = i < count and (list[i + 1] or 0) or here
		return after + (here - after) * (0.5 + 0.5 * (1 - t) / EASE)
	end
	return here
end

-- A piece's width and color where it falls or crosses water (Maps.AIR), in the pen's own color tables.
local function Air(pen, piece, i, t, thick, color, fall, water, count)
	local fell, wet = fall and Share(fall, i, t, count) or 0, water and Share(water, i, t, count) or 0
	if fell <= 0 and wet <= 0 then return thick, color end
	local AIR = Maps.AIR
	local base = color or Maps.LIGHT
	local r, g, b
	if type(base) == "function" then r, g, b = base() else r, g, b = base[1], base[2], base[3] end
	local a, w = fell * AIR.fall.share, wet * AIR.water.share
	local sky, sea = AIR.fall.color, AIR.water.color
	pen.air = pen.air or {}
	local mixed = pen.air[piece] or {}
	pen.air[piece] = mixed
	mixed[1] = r + (sea[1] - r) * w
	mixed[2] = g + (sea[2] - g) * w
	mixed[3] = b + (sea[3] - b) * w
	mixed[1], mixed[2], mixed[3] = mixed[1] + (sky[1] - mixed[1]) * a, mixed[2] + (sky[2] - mixed[2]) * a, mixed[3] + (sky[3] - mixed[3]) * a
	return thick * (1 + (AIR.fall.thin - 1) * fell) * (1 + (AIR.water.thin - 1) * wet), mixed
end

-- Short pieces, each a little finer and fainter than the one before. pen.along says how far along the
-- ribbon each piece is, for Shine. look: a journey's (Maps.JOURNEY) instead: even all the way, still.
-- With no `color`, a trail wears the trail's color (Maps.TrailColor) in its case (CASE, TRAIL).
function Maps.Ribbon(pen, xs, ys, count, color, look)
	local TRAIL = Maps.TRAIL
	-- A point nearer the last one than a piece is worth drawing is left out: a line a fraction of a pixel
	-- long isn't drawn at all, and a stretch made of those (a twist seen from afar, a way on a map
	-- zoomed out) would be a gap in the ribbon.
	local least, kept = (TRAIL.least * pen.unit) ^ 2, 1
	local depth = xs.depth or {}
	-- (A stretch left out is joined to the one after it, which then is as much fall or water as either.)
	local fall, water, fell, wet = xs.fall, xs.water, 0, 0
	for i = 2, count do
		if fall then fell = math.max(fell, fall[i] or 0) end
		if water then wet = math.max(wet, water[i] or 0) end
		if (xs[i] - xs[kept]) ^ 2 + (ys[i] - ys[kept]) ^ 2 >= least then
			kept = kept + 1
			xs[kept], ys[kept], depth[kept] = xs[i], ys[i], depth[i]
			if fall then fall[kept] = fell end
			if water then water[kept] = wet end
			fell, wet = 0, 0
		elseif i == count and kept > 1 then
			-- (It still ends where it ends.)
			xs[kept], ys[kept], depth[kept] = xs[i], ys[i], depth[i]
			if fall then fall[kept] = math.max(fall[kept] or 0, fell) end
			if water then water[kept] = math.max(water[kept] or 0, wet) end
		end
	end
	count = kept
	local whole = 0
	for i = 2, count do whole = whole + math.sqrt((xs[i] - xs[i - 1]) ^ 2 + (ys[i] - ys[i - 1]) ^ 2) end
	local sofar, pieces = 0, pen.lines.used
	pen.along = pen.along or {}
	pen.lit = pen.lit or {}
	-- (Where each of a trail's pieces begins and ends along it, for Start.)
	pen.span0, pen.span1 = pen.span0 or {}, pen.span1 or {}
	-- (A journey's too, for Start, where no trail shares the pen: a trail's come first.)
	if not look or not pen.trail then pen.firstPiece = pieces + 1 end
	-- A journey: in its kind's color, or the trail's (the theme's accent) for none.
	if look then color = color or Maps.TrailColor end
	-- A trail: in its case (Maps.CASE), in the trail's color (the theme's accent) or a caller's own, with a
	-- paler gleam down it and a paler spark on its comet; a glow of its color round it.
	local glow
	if not look then
		if color then
			local pale = pen.pale
			if not pale or pale.of ~= color then
				pale = { of = color, gleam = Pale(color, Maps.CASE.light), spark = Pale(color, 0.8) }
				pen.pale = pale
			end
			pen.gleam, pen.spark = pale.gleam, pale.spark
		else
			color, pen.gleam, pen.spark = Maps.TrailColor, TrailGleam, TrailSpark
		end
		glow, pen.glow = color, color
	end
	pen.cased = true
	-- The way the comet runs and Start follows the player along: its points, and the pixels along it to each.
	local path = pen.kept or { x = {}, y = {}, along = {} }
	pen.kept = path
	if look then pen.path = path else pen.trail = path end
	path.n, path.along[1], path.from = count, 0, 0
	for i = 1, count do
		path.x[i], path.y[i] = xs[i], ys[i]
		if i > 1 then path.along[i] = path.along[i - 1] + math.sqrt((xs[i] - xs[i - 1]) ^ 2 + (ys[i] - ys[i - 1]) ^ 2) end
	end
	for i = 2, count do
		local ax, ay = xs[i - 1], ys[i - 1]
		local dx, dy = xs[i] - ax, ys[i] - ay
		local length = math.sqrt(dx * dx + dy * dy)
		local parts = math.ceil(length / (TRAIL.piece * pen.unit))
		-- (The level changes over the pieces between two points: a way goes under by degrees.)
		local from, to = depth[i - 1] or 0, depth[i] or 0
		-- (Each piece starts where the last ended: Segment joins them.)
		for part = 1, parts do
			local along = (sofar + length * (part - 0.5) / parts) / whole
			pieces = pieces + 1
			if look then
				pen.lit[pieces] = Maps.Segment(pen, ax + dx * (part - 1) / parts, ay + dy * (part - 1) / parts, ax + dx * part / parts, ay + dy * part / parts,
					look.wide, 1, color, nil, look)
				-- (Still: no comet along it.)
				pen.along[pieces] = false
				pen.span0[pieces], pen.span1[pieces] = sofar + length * (part - 1) / parts, sofar + length * part / parts
			else
				-- (pen.flat: a piece that leads into a ribbon of its own, at that one's start: no taper of its own.)
				local shape = pen.flat and 0 or along
				local thick, tint = TRAIL.wide + (TRAIL.fine - TRAIL.wide) * shape, color
				if fall or water then thick, tint = Air(pen, pieces, i, (part - 0.5) / parts, thick, color, fall, water, count) end
				pen.lit[pieces] = Maps.Segment(pen, ax + dx * (part - 1) / parts, ay + dy * (part - 1) / parts, ax + dx * part / parts, ay + dy * part / parts,
					thick, 1 + (TRAIL.fade - 1) * shape, tint, from + (to - from) * (part - 0.5) / parts, nil, TRAIL.flare, glow)
				pen.along[pieces] = along
				pen.span0[pieces], pen.span1[pieces] = sofar + length * (part - 1) / parts, sofar + length * part / parts
			end
		end
		sofar = sofar + length
	end
	-- (A stroke laid on the same pen after the ribbon is a plain one.)
	pen.cased = nil
	if not look or not pen.trail then pen.lastPiece = pieces end
end

-- Start: a trail laid once and slid under the player (on a plate) begins where the player now is.
-- Pieces behind are put out of sight, the first one left is cut short to begin there, and the comet runs
-- from there. Laid again (Begin), the ribbon is whole.
-- How the player is followed along it (Start): stretches they may get on in one look (a bend is many short
-- ones), and pixels nearer the next stretch than this one that say a corner was cut.
local WALK = { ahead = 16, cut = 2 }

-- A piece's strokes out of sight, or back.
local function Cut(set, out)
	set.cut = out or nil
	for i = 1, 5 do
		local texture = set[i]
		if texture and texture.up then texture:SetShown(not out) end
	end
end

-- The first piece's start corners, as laid (kept), or as laid again (put back).
local function KeepStart(set)
	for i = 1, set.count do
		local c = set[i].corner
		local kept = set[i].laid or {}
		set[i].laid = kept
		kept[1], kept[2], kept[3], kept[4] = c[1], c[2], c[3], c[4]
	end
end
local function PutStart(pen, set)
	for i = 1, set.count do
		local c, kept = set[i].corner, set[i].laid
		if kept then
			c[1], c[2], c[3], c[4] = kept[1], kept[2], kept[3], kept[4]
			Fit(pen, set[i])
		end
	end
end

-- Every piece in sight again, before a trail is laid anew.
Whole = function(pen)
	local pool = pen.lines
	if pen.cutTo then
		for i = pen.firstPiece or 1, pen.cutTo - 1 do
			if pool[i] and pool[i].cut then Cut(pool[i], false) end
		end
	end
	pen.cutTo, pen.headPiece, pen.headAt, pen.seek, pen.firstPiece, pen.lastPiece = nil, nil, nil, nil, nil, nil
end

-- The ribbon from `at` pen units along it on.
local function From(pen, at)
	local first, last = pen.firstPiece, pen.lastPiece
	local pool, span0, span1 = pen.lines, pen.span0, pen.span1
	local k = pen.headPiece or first
	while k > first and span0[k] > at do k = k - 1 end
	while k <= last and span1[k] <= at do k = k + 1 end
	local cutTo = pen.cutTo or first
	for i = cutTo, math.min(k, last + 1) - 1 do Cut(pool[i], true) end
	for i = k, cutTo - 1 do Cut(pool[i], false) end
	pen.cutTo = k
	if pen.headPiece and pen.headPiece ~= k then PutStart(pen, pool[pen.headPiece]) end
	if k <= last then
		local set = pool[k]
		if pen.headPiece ~= k then
			KeepStart(set)
			pen.headPiece, pen.headAt = k, nil
		end
		local t = span1[k] > span0[k] and math.max(0, (at - span0[k]) / (span1[k] - span0[k])) or 0
		-- (Moved under a hundredth of a pixel: as it stands.)
		if not pen.headAt or math.abs(pen.headAt - t) * (span1[k] - span0[k]) > pen.unit * 0.01 then
			pen.headAt = t
			local sx, sy = set.ax + (set.bx - set.ax) * t, set.ay + (set.by - set.ay) * t
			for i = 1, set.count do
				Ends(set[i].corner, 1, sx, sy, set.nx, set.ny, Span(pen, set[i]) / 2)
				Fit(pen, set[i])
			end
		end
	else
		pen.headPiece = nil
	end
	local path = pen.trail or pen.path
	path.from = at
end

-- The trail begins clear of a circle `head` across round (x, y) (the player, in the pen's units, as its
-- points were given): where it leaves that circle on from the point of it nearest (x, y). Returns how
-- far (x, y) has strayed from it (from its start, past `head`, while short of it), or nil with no trail.
function Maps.Start(pen, x, y, head)
	local path = pen.trail or pen.path
	if not path or path.n < 2 or not pen.firstPiece or pen.lastPiece < pen.firstPiece then return nil end
	local px, py, along, n = path.x, path.y, path.along, path.n
	-- The stretch walked on, as a way is walked (Shy.Way.Along): on from the one found last to the next once
	-- past its end, or plainly on the next (a corner cut); never to a later stretch for being near it, nor
	-- back. A way round a corner, or in at a door and along the wall, passes near the player again further
	-- on: taken for where they are, all the trail before it was put out of sight.
	local function Stretch(k)
		local ax, ay = px[k - 1], py[k - 1]
		local dx, dy = px[k] - ax, py[k] - ay
		local span = dx * dx + dy * dy
		local share = span > 0 and ((x - ax) * dx + (y - ay) * dy) / span or 1
		local t = math.max(0, math.min(1, share))
		return math.sqrt((ax + dx * t - x) ^ 2 + (ay + dy * t - y) ^ 2), share, t
	end
	local bestAt = math.max(2, math.min(pen.seek or 2, n))
	local off, share, bestT = Stretch(bestAt)
	local cut = WALK.cut * pen.unit
	for _ = 1, WALK.ahead do
		if bestAt >= n then break end
		local nextOff, nextShare, nextT = Stretch(bestAt + 1)
		if not (share >= 1 or (nextShare > 0 and nextOff + cut < off)) then break end
		bestAt, off, share, bestT = bestAt + 1, nextOff, nextShare, nextT
	end
	pen.seek = bestAt
	local at = along[bestAt - 1] + (along[bestAt] - along[bestAt - 1]) * bestT
	if off < head then
		-- On to where it leaves the circle: the far root of |A + D s - P| = head, on from where it was nearest.
		at = along[n]
		local t0 = bestT
		for k = bestAt, n do
			local ax, ay = px[k - 1], py[k - 1]
			local dx, dy = px[k] - ax, py[k] - ay
			local a = dx * dx + dy * dy
			if a > 0 then
				local fx, fy = ax - x, ay - y
				local b = 2 * (fx * dx + fy * dy)
				local disc = b * b - 4 * a * (fx * fx + fy * fy - head * head)
				if disc >= 0 then
					local s = (-b + math.sqrt(disc)) / (2 * a)
					if s >= t0 and s <= 1 then
						at = along[k - 1] + (along[k] - along[k - 1]) * s
						break
					end
				end
			end
			t0 = 0
		end
	end
	From(pen, at)
	if bestAt == 2 and bestT == 0 then return math.max(0, off - head) end
	return off
end

-- The comet: a spark that runs along a ribbon from its start outward, over and over. Ahead of it the
-- ribbon brightens quickly; behind it the light fades slowly, a tail, on whichever of a piece's lines
-- wears the color (pen.lit), and the halo round it flares as it passes.
-- (A journey has none: it is still, Ribbon's look.)
-- A piece in its case, with the lit stroke at rest whole (TRAIL.rest 1), has nothing the comet changes: its
-- stroke is given its alpha once, the first time the pen shines after it was laid (pen.laid, Segment), and
-- left. A pen of such pieces alone (a trail) is not walked again until it is laid again: only its spark moves.
local Comet
function Maps.Shine(pen, now)
	local TRAIL = Maps.TRAIL
	local used = pen.lines.used
	local fresh = pen.shone ~= pen.laid or pen.shoneUsed ~= used
	if fresh or pen.flares then
		local head, tail, still = TRAIL.head, TRAIL.tail, TRAIL.rest == 1
		local flares = false
		for i = 1, used do
			local along = pen.along[i]
			if along ~= false then
				local set = pen.lines[i]
				if still and set.cased then
					if fresh then Alpha(set[pen.lit[i] or 3], 1) end
				else
					flares = true
					local phase = (now / TRAIL.every - (along or 0)) % 1
					local lit = phase < head and phase / head or phase < head + tail and (1 - (phase - head) / tail) ^ 2 or 0
					-- (In the screen's own steps of alpha: a change too small to see sets nothing.)
					Alpha(set[pen.lit[i] or 3], math.floor((TRAIL.rest + (1 - TRAIL.rest) * lit) * 255 + 0.5) / 255)
					if not set.cased then
						Alpha(set[1], math.floor((TRAIL.glow + (TRAIL.flare - TRAIL.glow) * lit) / TRAIL.flare * 255 + 0.5) / 255)
					end
				end
			end
		end
		pen.flares, pen.shone, pen.shoneUsed = flares, pen.laid, used
	end
	if pen.trail then Comet(pen, now) end
end

-- The comet's spark on its bloom, where the light peaks (Shine), as wide as the ribbon is there. It comes
-- out of the start and goes into the end, so it never jumps from one to the other.
Comet = function(pen, now)
	local TRAIL = Maps.TRAIL
	local path = pen.trail
	local whole = path.along[path.n] or 0
	local comet = pen.comet
	if not comet then
		comet = { Unsnapped(pen.owner:CreateTexture(nil, "OVERLAY", nil, 0)), Unsnapped(pen.owner:CreateTexture(nil, "OVERLAY", nil, 1)) }
		comet[1]:SetTexture(AREA)
		comet[2]:SetTexture(AREA)
		if pen.mask then
			comet[1]:AddMaskTexture(pen.mask)
			comet[2]:AddMaskTexture(pen.mask)
		end
		pen.comet = comet
	end
	-- (From where the ribbon now begins: Start.)
	local begin = math.min(path.from or 0, whole)
	if path.n < 2 or whole - begin <= 0 then
		Down(comet[1])
		Down(comet[2])
		return
	end
	local share = (now / TRAIL.every - TRAIL.head) % 1
	local s = begin + share * (whole - begin)
	local at = 2
	while at < path.n and path.along[at] < s do at = at + 1 end
	local from, to = path.along[at - 1], path.along[at]
	local t = to > from and (s - from) / (to - from) or 0
	local x = path.x[at - 1] + (path.x[at] - path.x[at - 1]) * t
	local y = path.y[at - 1] + (path.y[at] - path.y[at - 1]) * t
	local sign = pen.down and -1 or 1
	local wide = (TRAIL.wide + (TRAIL.fine - TRAIL.wide) * s / whole) * pen.unit
	local fade = math.min(1, share / 0.06, (1 - share) / 0.1)
	-- (Its one point, set again: a region's point of the same name takes the place of the old.)
	for i = 1, 2 do
		local texture, size = comet[i], i == 1 and TRAIL.bloom or TRAIL.spark
		texture:SetPoint("CENTER", pen.anchor, pen.point, x, y * sign)
		texture:SetSize(wide * size, wide * size)
		Up(texture)
		Tint(texture, i == 1 and (pen.glow or Maps.TrailColor) or (pen.spark or TrailSpark), fade * (i == 1 and TRAIL.bloomAlpha or 1))
	end
end


-- A smooth line through points (flat: north, west, north, west, ...), as the game moves a flight or a
-- ship along such a line: Catmull-Rom, in pieces of no more than `bend` yards. Returns { north = {},
-- west = {}, n, along = {} (yards along it to each of its points), point = {} (the point of it each given
-- point is) }; nil for fewer than two points.
function Maps.Smooth(flat, bend)
	local m = math.floor(#flat / 2)
	if m < 2 then return nil end
	local line = { north = { flat[1] }, west = { flat[2] }, n = 1, along = { 0 }, point = { 1 } }
	local north, west, along = line.north, line.west, line.along
	for i = 1, m - 1 do
		local a, d = math.max(1, i - 1), math.min(m, i + 2)
		local an, aw, bn, bw = flat[a * 2 - 1], flat[a * 2], flat[i * 2 - 1], flat[i * 2]
		local cn, cw, dn, dw = flat[i * 2 + 1], flat[i * 2 + 2], flat[d * 2 - 1], flat[d * 2]
		local pieces = math.max(1, math.ceil(math.sqrt((cn - bn) ^ 2 + (cw - bw) ^ 2) / bend))
		for step = 1, pieces do
			local t = step / pieces
			local t2, t3 = t * t, t * t * t
			local n = line.n + 1
			line.n = n
			north[n] = 0.5 * (2 * bn + (cn - an) * t + (2 * an - 5 * bn + 4 * cn - dn) * t2 + (3 * bn - an - 3 * cn + dn) * t3)
			west[n] = 0.5 * (2 * bw + (cw - aw) * t + (2 * aw - 5 * bw + 4 * cw - dw) * t2 + (3 * bw - aw - 3 * cw + dw) * t3)
			along[n] = along[n - 1] + math.sqrt((north[n] - north[n - 1]) ^ 2 + (west[n] - west[n - 1]) ^ 2)
		end
		line.point[i + 1] = line.n
	end
	return line
end

-- The point of a line nearest (north, west), looked for from `from` (default 1) to `to` (default its
-- last): its index and how far away it is in yards.
function Maps.Nearest(line, north, west, from, to)
	local best, least = from or 1, math.huge
	for i = from or 1, to or line.n do
		local away = (line.north[i] - north) ^ 2 + (line.west[i] - west) ^ 2
		if away < least then best, least = i, away end
	end
	return best, math.sqrt(least)
end

-- The minimap

function Maps.Within(ax, ay, bx, by, square, edge)
	edge = edge or Maps.EDGE
	local dx, dy = bx - ax, by - ay
	local from, to = 0, 1
	if square then
		for side = 1, 4 do
			-- left, right, bottom, top
			local p = side == 1 and -dx or side == 2 and dx or side == 3 and -dy or dy
			local q = side == 1 and ax + edge or side == 2 and edge - ax or side == 3 and ay + edge or edge - ay
			if p == 0 then
				if q < 0 then return nil end
			elseif p < 0 then
				from = math.max(from, q / p)
			else
				to = math.min(to, q / p)
			end
		end
	else
		local a = dx * dx + dy * dy
		local b = 2 * (ax * dx + ay * dy)
		local crossed = b * b - 4 * a * (ax * ax + ay * ay - edge * edge)
		if a == 0 or crossed <= 0 then return nil end
		local root = math.sqrt(crossed)
		from, to = math.max(from, (-b - root) / (2 * a)), math.min(to, (-b + root) / (2 * a))
	end
	if from >= to then return nil end
	-- (Last: whether its far end was cut off. Told here, not by comparing what comes back with what went
	-- in: a sum of fractions is seldom the number it started from.)
	return ax + dx * from, ay + dy * from, ax + dx * to, ay + dy * to, to < 1
end

-- A mask the minimap's lines are cut by: the rim (Maps.RIM), round or square, its edge a soft fade (the
-- RimFade textures fade over their outer eighth), so a line melts away there rather than stopping on a
-- hard edge. Set again only where the minimap's size or shape has changed.
local RIM_FADE = { [true] = Shy.MEDIA .. "RimFade", [false] = Shy.MEDIA .. "RimFadeRound" }
function Maps.RimMask(mask, radius, square)
	square = square and true or false
	if mask.rimRadius ~= radius then
		mask.rimRadius = radius
		mask:SetSize(2 * radius * Maps.RIM, 2 * radius * Maps.RIM)
	end
	if mask.rimSquare ~= square then
		mask.rimSquare = square
		mask:SetTexture(RIM_FADE[square], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
end

function Maps.Mini(view)
	local reach = C_Minimap.GetViewRadius()
	local radius = Minimap:GetWidth() / 2
	if not reach or reach <= 0 or radius <= 0 then return nil end
	local continent, north, west = Shy.Here()
	if not continent then return nil end
	local facing = C_CVar.GetCVarBool("rotateMinimap") and GetPlayerFacing() or 0
	view = view or {}
	view.reach, view.radius, view.continent = reach, radius, continent
	view.north, view.west = north, west
	view.sin, view.cos, view.facing = math.sin(facing), math.cos(facing), facing
	view.square = Shy.MinimapShape() == "SQUARE"
	return view
end

function Maps.OnMini(view, north, west)
	local east, up = -(west - view.west) / view.reach, (north - view.north) / view.reach
	return east * view.cos + up * view.sin, -east * view.sin + up * view.cos
end

-- The world map
-- What shows the world map is the game's canvas in its map window, or ShyMaps' view while that is in use
-- (Shy.addons.Maps:View()), in ShyMaps' own window (the map then). Both answer
-- alike: a canvas the size of the map's art, scaled by the zoom, with the map shown, the zoom and the pin
-- levels. Everything here goes by the one in use, and a layer (MapLayer) or a frame over the map (Over)
-- moves to the other when that changes, so what is drawn there shows whichever draws the map.
--   Shy.Maps.Canvas() -> what answers as the canvas in use: WorldMapFrame, or ShyMaps' view
--   Shy.Maps.ShownMap() -> the map shown;   Shy.Maps.PinLevel(name) -> a pin level on the canvas in use
--   Shy.Maps.Beyond() -> how far past the map's edges the canvas in use may show, in shares of the map
--   Shy.Maps.PinLayer(above) -> a frame over the map's window that the zoom never scales: pins on it hang from a
--                                           point on a MapLayer and keep their size on screen
--   Shy.Maps.Over(frame, point, x, y)       a frame of one's own over the map's window (a note, a key), at Maps.OVER scale, placed
--                                           at `point` of the canvas's frame in use, and kept there; it stays with the
--                                           window when ShyMaps lays its view over the whole screen (its overlay)

local GROW = 0.4             -- extra size at the closest zoom, linear from the widest (ShyQuest's pins)

local function View()
	local maps = Shy.addons.Maps
	return maps and maps.View and maps:View() or nil
end

function Maps.Canvas()
	return View() or WorldMapFrame
end

function Maps.ShownMap()
	return Maps.Canvas():GetMapID()
end

function Maps.Open(map)
	local own = Shy.addons.Maps
	if own and own.ShowMap and own:ShowMap(map) then return true end
	if InCombatLockdown() then return false end
	OpenWorldMap(map)
	return true
end

-- How far past the shown map's edges what draws the map may show, in shares of the map: 0 on the game's
-- canvas; ShyMaps' view on a look whose ground goes on past the map says how far (GetBeyond). A line that
-- leaves the map is drawn that far, where a cut at the map's edge would end it in the middle of the window.
function Maps.Beyond()
	local view = View()
	return view and view.GetBeyond and view:GetBeyond() or 0
end

function Maps.PinLevel(name)
	local view = View()
	if view then return view:GetPinFrameLevel(name) end
	return WorldMapFrame:GetPinFrameLevelsManager():GetValidFrameLevel(name)
end

local layers, overs = {}, {}  -- { frame, above }; { frame, point, x, y }

-- (Asked at every opening: only what is no longer so is set. A pin layer stands on the canvas's container, the
-- window the map shows in, which the zoom never scales.)
local function Home(entry)
	local canvas = Maps.Canvas():GetCanvas()
	local on = entry.still and Maps.Canvas():GetCanvasContainer() or canvas
	local frame = entry.frame
	if frame:GetParent() ~= on then
		frame:SetParent(on)
		frame:ClearAllPoints()
		frame:SetAllPoints(on)
	end
	local level = Maps.PinLevel("PIN_FRAME_LEVEL_ACTIVE_QUEST") + entry.above
	if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
	if entry.still then
		layers.Follow(canvas)
		layers.Fade(entry, canvas:GetAlpha())
	end
end

local function Place(entry)
	-- (ShyMaps' view keeps what is over the window apart: its canvas may leave the window for the overlay.)
	local view = View()
	local container = view and view.GetOverContainer and view:GetOverContainer() or Maps.Canvas():GetCanvasContainer()
	local frame = entry.frame
	if entry.on == container and frame:GetParent() == container then return end
	entry.on = container
	if frame:GetParent() ~= container then frame:SetParent(container) end
	-- (Smaller over the map, by Maps.OVER; the offsets are the frame's own units, so they are kept in screen terms.)
	frame:SetScale(Maps.OVER)
	frame:ClearAllPoints()
	frame:SetPoint(entry.point, container, entry.point, entry.x / Maps.OVER, entry.y / Maps.OVER)
end

-- Every layer and frame over the map onto what is in use now.
local Rehome = Shy.Clocked("maps: layers onto the map in use", function()
	for _, entry in ipairs(layers) do Home(entry) end
	for _, entry in ipairs(overs) do Place(entry) end
end)

-- On ShyMaps' view the layers stay out of sight from a close until the view has opened (it shows the
-- map at once and tells its opening a few frames after): each then draws itself once, as it comes into
-- sight, never in the frame the map window opens.
-- (Timed apart: a layer's own drawing as it shows has its clock, and what is left of this one is the game
-- showing every region on it.)
local seated = true
local hushed = {}           -- why every layer is out of sight besides (Maps.Hush): { [who] = true }
local seat = {
	[true] = Shy.Clocked("maps: layers into sight", function(frame) frame:Show() end),
	[false] = Shy.Clocked("maps: layers out of sight", function(frame) frame:Hide() end),
}
local function Seat(on)
	seated = on
	local show = on and next(hushed) == nil
	for _, entry in ipairs(layers) do
		local want = show and not entry.faded
		if entry.frame:IsShown() ~= want then seat[want](entry.frame) end
	end
end

-- A pin layer fades as the canvas it stands for does (ShyMaps' view fades what stands on the map for a focus), and
-- is out of sight with it at none, so nothing unseen takes the mouse.
local faders = setmetatable({}, { __mode = "k" })   -- canvas -> true once its fading is followed
function layers.Fade(entry, alpha)
	entry.frame:SetAlpha(alpha)
	local faded = alpha <= 0
	if faded == (entry.faded == true) then return end
	entry.faded = faded or nil
	Seat(seated)
end
function layers.Follow(canvas)
	if faders[canvas] then return end
	faders[canvas] = true
	hooksecurefunc(canvas, "SetAlpha", function(self, alpha)
		if Maps.Canvas():GetCanvas() ~= self then return end
		for _, entry in ipairs(layers) do
			if entry.still then layers.Fade(entry, alpha) end
		end
	end)
end

-- Every addon's layers out of sight for a while (who: whoever asks, on: true to hush, false to let them back):
-- ShyMaps keeps the map clear inside an instance so.
function Maps.Hush(who, on)
	if (hushed[who] == true) == (on == true) then return end
	hushed[who] = on and true or nil
	Seat(seated)
end

function Maps.MapLayer(above)
	local entry = { frame = CreateFrame("Frame", nil, Maps.Canvas():GetCanvas()), above = above or 0 }
	layers[#layers + 1] = entry
	entry.frame:SetAllPoints()
	entry.frame:SetShown(seated and next(hushed) == nil)
	Home(entry)
	return entry.frame
end

-- A layer for pins that keep their size on screen whatever the zoom: over the map's window at the layer's level,
-- cut to the window, moved with the canvas in use, and out of sight with the layers. A pin hangs from a point on a
-- MapLayer (anchored to a region there), so the zoom carries it to its place and nothing is told of a zoom's step.
function Maps.PinLayer(above)
	local entry = { frame = CreateFrame("Frame", nil, Maps.Canvas():GetCanvasContainer()), above = above or 0, still = true }
	layers[#layers + 1] = entry
	entry.frame:SetAllPoints()
	entry.frame:SetClipsChildren(true)
	entry.frame:SetShown(seated and next(hushed) == nil)
	Home(entry)
	return entry.frame
end

function Maps.Over(frame, point, x, y)
	local entry = { frame = frame, point = point, x = x or 0, y = y or 0 }
	overs[#overs + 1] = entry
	Place(entry)
end

function Maps.MapScale()
	local canvas = Maps.Canvas()
	local zoomed = canvas:GetCanvasZoomPercent()
	-- (A map with a single zoom level can give nil or NaN.)
	if not zoomed or zoomed ~= zoomed then zoomed = 0 end
	local grow = 1 + GROW * math.max(0, math.min(1, zoomed))
	local scale = canvas:GetCanvasScale()
	if not scale or scale <= 0 then return nil end
	return grow / scale, grow
end

-- fn(why) when the map shows, changes map ("map"), zoom ("scale") or size ("size"), or ShyMaps' view is
-- taken into use or given up ("use"); why is the view's own word for what changed while it is in use.
local onMap, hooked = {}, false
-- (Each word timed apart with every addon that hears it; in detail, each addon's listeners apart too.)
local tellers, onMapBy, toldBy = {}, {}, {}
local function Tell(why)
	if Shy.ClockDetail() then
		local by = toldBy[why]
		if not by then
			by = {}
			toldBy[why] = by
		end
		for _, fn in ipairs(onMap) do
			local addon = onMapBy[fn] or "ShyCore"
			local clock = by[addon]
			if not clock then
				clock = Shy.Clock("maps: the map's " .. tostring(why) .. " \226\134\146 " .. addon, addon)
				by[addon] = clock
			end
			local from, heap = debugprofilestop(), collectgarbage("count")
			local ok, err = pcall(fn, why)
			clock:Lap(debugprofilestop() - from, collectgarbage("count") - heap)
			if not ok then geterrorhandler()(err) end
		end
		return
	end
	for _, fn in ipairs(onMap) do
		local ok, err = pcall(fn, why)
		if not ok then geterrorhandler()(err) end
	end
end
local function MapChanged(why)
	local tell = tellers[why]
	if not tell then
		tell = Shy.Clocked("maps: the map's " .. tostring(why) .. ", told every addon", Tell)
		tellers[why] = tell
	end
	tell(why)
end
function Maps.OnMap(fn)
	onMap[#onMap + 1] = fn
	onMapBy[fn] = Shy.AddonOf(2)
	if hooked then return end
	hooked = true
	-- The game's canvas tells only while it draws the map: under ShyMaps' view it is out of sight, and the
	-- view tells its own changes (each would otherwise be told twice, the open four times).
	local function Game(why)
		if not View() then MapChanged(why) end
	end
	-- The map's size and zoom are set after OnMapChanged: now and again next frame.
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
		Game("map")
		C_Timer.After(0, function() Game("map") end)
	end)
	hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function() Game("scale") end)
	hooksecurefunc(WorldMapFrame, "OnCanvasSizeChanged", function() Game("size") end)
	WorldMapFrame:HookScript("OnShow", function() Game("map") end)
end

-- A zoom tells its every frame. While the listeners take no more than SHARE milliseconds they hear each;
-- slower, they hear one every so many frames as their cost asks while the zoom moves, and always one
-- more as it stops: a slow listener never costs the zoom its smoothness.
local SHARE = 3
local FRAME = 1 / 60
local scaleCost, scaleAt, scaleAsked = 0, 0, 0
local owing = CreateFrame("Frame")   -- shown while a zoom is owed to the listeners
owing:Hide()
local function TellScale()
	owing:Hide()
	local from = debugprofilestop()
	MapChanged("scale")
	scaleCost, scaleAt = debugprofilestop() - from, GetTime()
end
local function Wait()
	return scaleCost > SHARE and (scaleCost / SHARE - 1) * FRAME or 0
end
-- (The time is the frame's: asked again this frame, the zoom still moves.)
owing:SetScript("OnUpdate", function()
	local now = GetTime()
	if now - scaleAt >= Wait() or now > scaleAsked then TellScale() end
end)
local function Scaled()
	scaleAsked = GetTime()
	if scaleAsked - scaleAt >= Wait() then
		TellScale()
	else
		owing:Show()
	end
end

-- ShyMaps (loaded after ShyCore, if at all): its view's changes are the map's, and taking it into use or
-- giving it up moves everything onto what now draws the map.
Shy:On("SHY_LOGIN", function()
	local maps = Shy.addons.Maps
	if maps and maps.OnView then
		maps:OnView(function(why)
			-- (A pan carries the canvas and all on it; a close shows nothing; being taken up or given up
			-- comes on the bus, below, once.)
			if why == "pan" or why == "use" then return end
			if why == "close" then
				owing:Hide()
				Seat(false)
				return
			end
			if why == "scale" then
				Scaled()
				return
			end
			if why == "open" then Rehome() end
			-- (Everything is laid as it is now: no zoom is owed.)
			owing:Hide()
			MapChanged(why)
			-- (Told while out of sight, a layer drew nothing: it draws as it comes into sight.)
			if why == "open" then Seat(true) end
		end)
	end
end)
Shy:On("SHY_MAPS", function(on)
	Rehome()
	-- (Taken up, the layers wait for the view's opening; given up, the game's canvas has them at once.)
	Seat(not on)
	MapChanged("use")
end)

function Maps.ToMap(map, continent, north, west)
	if not map or not continent then return nil end
	local _, spot = C_Map.GetMapPosFromWorldPos(continent, CreateVector2D(north, west), map)
	if not spot then return nil end
	return spot:GetXY()
end

-- A line's points on a map (norths[i], wests[i], `count` of them), as shares of it, into xs and ys; false
-- where the game has no place for one. Asked of the game, every point makes two vectors, and a way over the
-- ground has hundreds: on a map that lies on its continent as one rectangle (Shy.MapFrame) they are worked
-- out, and only the line's two ends are asked, to hold that against. A map seen to differ there is asked
-- point by point from then on.
local lineTo = { uneven = {}, SAME = 0.0005 }
function Maps.LineToMap(map, continent, norths, wests, count, xs, ys)
	local frame = map and continent and not lineTo.uneven[map] and Shy.MapFrame(map)
	if frame and frame[1] == continent and frame[4] ~= 0 and frame[5] ~= 0 and count > 0 then
		local north, west, tall, wide = frame[2], frame[3], frame[4], frame[5]
		local even = true
		for i = 1, count, math.max(1, count - 1) do
			local x, y = Maps.ToMap(map, continent, norths[i], wests[i])
			if not x then
				even = false
			elseif math.abs((wests[i] - west) / wide - x) > lineTo.SAME or math.abs((norths[i] - north) / tall - y) > lineTo.SAME then
				even, lineTo.uneven[map] = false, true
			end
		end
		if even then
			for i = 1, count do xs[i], ys[i] = (wests[i] - west) / wide, (norths[i] - north) / tall end
			return
		end
	end
	for i = 1, count do
		local x, y = Maps.ToMap(map, continent, norths[i], wests[i])
		xs[i], ys[i] = x or false, y or false
	end
end

-- Marks
-- What ShyCore itself stands on the maps wears the family's mark (ShyQuest's look): a dark glass plate
-- with one bezel and a sign, both in the sign's color; lit, the face in the color, the bezel a lighter
-- tint of it, a soft bloom round it and the sign dark. Two sheets, Mark.tga (64px cells) and
-- MarkSmall.tga (32px); a mark uses the one nearer its size on screen.
--   Shy.Maps.Mark(parent, size) -> mark;   mark:Set(sign, color, lit)   sign: Maps.SIGNS, one of Shy.Hover.GLYPHS,
--                                           nil for a plate its owner writes on (a number),
--                                           or another addon's own: { sheets = { small, large }, cell, cols, rows },
--                                           a cell of its sheets drawn as these are (the same two sizes)
local SHEETS = { Shy.MEDIA .. "MarkSmall", Shy.MEDIA .. "Mark" }
local GLYPH_SHARE = 0.56     -- a hover glyph as the sign: this share of the mark's width
local LARGE_FROM = 40        -- on-screen pixels from which the large sheet is used
local COLS, ROWS = 4, 4
local CELL = { badge = 0, lit = 1, ring = 2, bloom = 3, flight = 4, sail = 5, tram = 6, zeppelin = 7, shut = 8, open = 9 }
-- flight: the wing (a flight, an airboat); sail: a boat; tram: the tram's car; zeppelin: a zeppelin. Each in
-- its way's color (Shy.Theme.TRAVEL).
Maps.SIGNS = { flight = true, sail = true, tram = true, zeppelin = true }
local BLOOM_SCALE = 1.6      -- the bloom's picture is shown this many times the mark's size
local LIT_BEZEL, LIT_BLOOM = 0.45, 0.25   -- a lit plate's bezel and bloom: this far from its color toward white
local GRAPHITE = { 0.08, 0.08, 0.09 }     -- the sign on a lit plate
local WHITE = { 1, 1, 1 }

-- A color a share toward white: a table's, or the accent's as it is now (a function, so it follows the theme).
local function Paler(color, by)
	if type(color) ~= "function" then return Lighter(color, by) end
	return function()
		local r, g, b = color()
		return r + (1 - r) * by, g + (1 - g) * by, b + (1 - b) * by
	end
end

local function Cell(texture, name)
	local cell = CELL[name]
	local col, row = cell % COLS, math.floor(cell / COLS)
	texture:SetTexCoord(col / COLS, (col + 1) / COLS, row / ROWS, (row + 1) / ROWS)
	texture:Show()
end

function Maps.Mark(parent, size)
	local mark = CreateFrame("Frame", nil, parent)
	mark:SetSize(size, size)
	local bloom = mark:CreateTexture(nil, "BACKGROUND")
	bloom:SetPoint("CENTER")
	bloom:SetSize(size * BLOOM_SCALE, size * BLOOM_SCALE)
	local glyphed = false        -- the sign is a hover glyph, sized apart from the mark
	local sign
	mark:SetScript("OnSizeChanged", function(_, width)
		bloom:SetSize(width * BLOOM_SCALE, width * BLOOM_SCALE)
		if glyphed then sign:SetSize(width * GLYPH_SHARE, width * GLYPH_SHARE) end
	end)
	local plate = mark:CreateTexture(nil, "BORDER")
	plate:SetAllPoints()
	local face = mark:CreateTexture(nil, "BORDER", nil, 1)
	face:SetAllPoints()
	local bezel = mark:CreateTexture(nil, "BORDER", nil, 2)
	bezel:SetAllPoints()
	sign = mark:CreateTexture(nil, "ARTWORK")
	sign:SetAllPoints()
	local regions, sheet = { bloom, plate, face, bezel, sign }, nil
	local function Sheet()
		local _, height = GetPhysicalScreenSize()
		local want = SHEETS[mark:GetWidth() * mark:GetEffectiveScale() * height / 768 > LARGE_FROM and 2 or 1]
		if want ~= sheet then
			sheet = want
			for _, region in ipairs(regions) do region:SetTexture(sheet) end
		end
	end
	-- ink: the sign's own color, where it isn't the bezel's (unlit) or graphite (lit).
	function mark:Set(name, color, lit, ink)
		Sheet()
		UI.Tint(plate, WHITE, 1)
		Cell(plate, "badge")
		if lit then
			UI.Tint(face, color, 1)
			Cell(face, "lit")
			UI.Tint(bezel, Paler(color, LIT_BEZEL), 1)
			UI.Tint(bloom, Paler(color, LIT_BLOOM), 1)
			Cell(bloom, "bloom")
			UI.Tint(sign, ink or GRAPHITE, 1)
		else
			face:Hide()
			bloom:Hide()
			UI.Tint(bezel, color, 1)
			UI.Tint(sign, ink or color, 1)
		end
		Cell(bezel, "ring")
		sign:ClearAllPoints()
		if name == nil then
			-- No sign of its own: its owner writes on it (a number).
			glyphed = false
			sign:Hide()
		elseif type(name) == "table" then
			-- Another addon's sign: its sheet of the size this mark took.
			glyphed = false
			sign:SetTexture(name.sheets[sheet == SHEETS[2] and 2 or 1])
			sign:SetAllPoints()
			local col, row = name.cell % name.cols, math.floor(name.cell / name.cols)
			sign:SetTexCoord(col / name.cols, (col + 1) / name.cols, row / name.rows, (row + 1) / name.rows)
			sign:Show()
		elseif CELL[name] then
			glyphed = false
			sign:SetTexture(sheet)
			sign:SetAllPoints()
			Cell(sign, name)
		else
			glyphed = true
			local width = mark:GetWidth() * GLYPH_SHARE
			sign:SetPoint("CENTER")
			sign:SetSize(width, width)
			Shy.Hover.Glyph(sign, name, width)
			sign:Show()
		end
	end
	-- (Its size on screen decides which sheet is nearer: Set again after a change of scale or size.)
	return mark
end

-- A group's fold (UI.GroupHead's own, the quest card's zones): the family's mark with a chevron, pointing on while
-- shut and down while open, a steel bezel and a white sign; under the mouse it lights in your color.
--   local fold = UI.FoldMark(parent, size);   fold:Set("open" | "shut");   fold:SetHovered(on)
local FOLD_STEEL, FOLD_SIGN = { 0.74, 0.74, 0.78 }, { 0.96, 0.96, 0.98 }
function UI.FoldMark(parent, size)
	local mark = Maps.Mark(parent, size)
	local paint, state, hovered = mark.Set, "shut", false
	local function Draw()
		if hovered then
			paint(mark, state, Theme.Accent, true, UI.colors.onAccent)
		else
			paint(mark, state, FOLD_STEEL, false, FOLD_SIGN)
		end
	end
	function mark:Set(open)
		state = (open == "open") and "open" or "shut"
		Draw()
	end
	function mark:SetHovered(on)
		hovered = on and true or false
		Draw()
	end
	Draw()
	return mark
end
