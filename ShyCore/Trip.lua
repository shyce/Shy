-- Shy.Maps.Trip: a journey on the maps, for any addon: a flight, a boat, anything with a line it follows.
--
-- While a trip has a line, the minimap and the world map show it from the player to where it lands, in
-- the trip's color (a flight's, a boat's, a zeppelin's: each kind its own) in a crisp dark case, melting
-- away at the minimap's rim, with a mark there (on the minimap, waiting at the rim while that is out of
-- range, as a pin does) and the time left under the mark. The mark's hover says where the trip goes and how long it
-- has to go, and keeps saying it while the mouse stays. Flights are one (Shy.Way.Flight); ShyQuest's crossings
-- and escorts are others.
--
--   local trip = Shy.Maps.Trip(spec)
--   spec.color = { r, g, b }        the line, the mark, the time under it, the hover's light
--   spec.sign = "flight"            the mark's sign (any Shy.Maps.Mark takes: Shy.Maps.SIGNS, or an addon's own)
--   spec.strip = "Flight"           the hover's strip
--   spec.Line(continent, north, west) -> line, first, last
--        the line ({ continent, north = {}, west = {}, n }), the first of its points still ahead of the
--        player at (north, west), and the last (where it lands); nil while there is nothing to show
--   spec.Left() -> label, left, share, said
--        the countdown: seconds left (or so far), the share left (0: unknown or past) and the time in words
--        ("about 1:23", "1:23", "landing", "1:05 so far"); nil with none
--   spec.To() -> name                where it lands: the hover's title
--   spec.unknown = { title, sub }    the hover while there is no countdown (optional)
--   spec.aboard = true              the player rides the thing (a flight, a boat): the line is drawn from
--                                   where they stand, and where that is off the line (on a deck beside the
--                                   ship's own path) it carries their offset, shed over the first TAPER
--                                   yards, so it leads from them and joins the line ahead
--   spec.look                       the line's look (default Shy.Maps.JOURNEY: even and still, in its case:
--                                   never mistaken for the way walked, which tapers and has a comet)
--   trip:Update()                   after it starts, changes or ends: both maps are laid again now
--   trip:Look(sign, color, strip)   another sign, color or strip (a crossing's kind)
--
-- The work is done each frame while the trip shows. On the minimap the path ahead, and a landing that
-- is in range, are drawn on the shared plate and a step moves them. They are drawn again when the next
-- point of the path is the one ahead, or the plate is drawn again. A landing out of range waits at the
-- rim. With no plate, the line is laid every frame. An error in the work is told once (the error bag)
-- and the trip is put away until its next Update, rather than told every frame.

local UI = Shy.UI
local Maps = Shy.Maps

local MINI_SIZE, MAP_SIZE = 20, 27   -- the mark's size on each, at the widest zoom (ShyQuest's pins)
local MINI_GROW = 0.3        -- extra size at the minimap's closest zoom
local MINI_LINE = 0.65       -- scale of lines on the minimap
local MINI_YOU = 10          -- the line starts this far from the minimap's middle, clear of the player arrow
local MAP_YOU = 0.45         -- ... and this far from the player on the world map, in mark sizes
local RIM = 0.56             -- a line ends this far from a mark's middle, in mark sizes
-- The time left, under a mark: a dark capsule in a fine rim of the trip's color, its top tucked under the
-- mark so the two read as one badge. `text` its words' size, `tall` its height (units), `pad` room either
-- side of the words and `rim` its colored edge (screen pixels), `tuck` the share of its height over the
-- mark's foot, `fill` its dark.
local TAG = { text = 10, tall = 14, pad = 4, tuck = 0.3, rim = 1, fill = { 0.04, 0.04, 0.05, 0.92 } }
-- The capsules it is laid from: one for each height `least` to `most` screen pixels, a texel to a pixel, down
-- a sheet `wide` by `high` (h's row `(h - least) * (h + least - 1) / 2` texels down; h + 1 wide: its left end
-- h / 2, a texel of its middle, its right end). The tag takes the one as tall as it is on screen, so its edge
-- is as crisp as the rest of the screen at any scale.
local CAPSULE = { file = Shy.MEDIA .. "Capsule", least = 8, most = 40, wide = 64, high = 1024 }

-- A capsule in three textures (its ends and its stretched middle), laid `h` screen pixels tall, `inset`
-- pixels in from each side of `tag`; `unit` the units in a pixel.
local function Capsule(tag, layer, sub)
	local parts = {}
	for i = 1, 3 do
		parts[i] = tag:CreateTexture(nil, layer, nil, sub)
		parts[i]:SetTexture(CAPSULE.file)
	end
	return parts
end
local function LayCapsule(parts, tag, h, inset, unit)
	local C = CAPSULE
	local top, cap = (h - C.least) * (h + C.least - 1) / 2, h / 2
	local v0, v1 = top / C.high, (top + h) / C.high
	local left, middle, right = parts[1], parts[2], parts[3]
	left:SetTexCoord(0, cap / C.wide, v0, v1)
	left:SetSize(cap * unit, h * unit)
	left:ClearAllPoints()
	left:SetPoint("LEFT", tag, "LEFT", inset * unit, 0)
	right:SetTexCoord((cap + 1) / C.wide, (h + 1) / C.wide, v0, v1)
	right:SetSize(cap * unit, h * unit)
	right:ClearAllPoints()
	right:SetPoint("RIGHT", tag, "RIGHT", -inset * unit, 0)
	-- (The middle: its one texel's column, stretched between the ends.)
	middle:SetTexCoord((cap + 0.5) / C.wide, (cap + 0.5) / C.wide, v0, v1)
	middle:ClearAllPoints()
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
end
local MAP_EVERY = 0.2        -- seconds between re-lays of the world map's line
local TAPER = 150            -- yards over which the player's offset from the line is shed (spec.aboard)

-- Points of the line on the screen, filled anew for each one laid (one trip at a time lays).
local xs, ys = { depth = {} }, {}

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Aboard: where the player stands on the line (its nearest point, between first - 1 and first) and how far
-- off it they are, north and west; nothing when the trip isn't ridden.
local function Offset(self, line, first, north, west)
	if not self.spec.aboard then return nil end
	local an, aw = line.north[first], line.west[first]
	local bn, bw = an, aw
	if first > 1 then bn, bw = line.north[first - 1], line.west[first - 1] end
	local dn, dw = an - bn, aw - bw
	local len = dn * dn + dw * dw
	local t = 0
	if len > 0 then t = math.max(0, math.min(1, ((north - bn) * dn + (west - bw) * dw) / len)) end
	local on, ow = bn + dn * t, bw + dw * t
	return on, ow, north - on, west - ow
end

-- Whether a mark's hover is the one up. (Shy.Hover is missing only where ShyCore is loaded in part.)
local function Owns(holder)
	return Shy.Hover ~= nil and Shy.Hover.Owner() == holder
end

local Trip = {}
Trip.KEEP_AHEAD = 4           -- path points the rider may pass before the minimap's path is laid again
Trip.STRAY = 4                -- minimap units the rider may be off the path laid before it is laid again
Trip.__index = Trip

-- The hover: where to, and how long.
function Trip:Hover(holder)
	local spec = self.spec
	local label, _, share, said = spec.Left()
	local content = { strip = self.strip, light = self.color }
	if not label then
		local unknown = spec.unknown or {}
		content.title, content.sub = spec.To() or unknown[1], unknown[2]
	else
		content.title = spec.To()
		if share > 0 then
			-- "about 1:23" -> "About 1:23 left"
			content.sub = (said:gsub("^%l", string.upper)) .. " left"
			content.bar = { have = share, color = self.color }
		else
			-- "landing", "1:05 so far"
			content.sub = (said:gsub("^%l", string.upper))
		end
	end
	Shy.Hover.Show(holder, content, { side = holder.side, keep = false })
end

-- The time left under a mark, on its tag; no tag while it is unknown or past. The tag is laid in whole
-- screen pixels (its capsule the one as tall as it is on screen), and again only where that changes.
function Trip:Clocked(holder)
	local _, left, share = self.spec.Left()
	local tag = holder.tag
	local text = share and share > 0 and Clock(left) or ""
	holder.clock:SetText(text)
	if text == "" then
		tag:Hide()
		return
	end
	local per = tag:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
	if not (per > 0) then return end
	local unit = 1 / per
	-- (An even height, so its round ends are whole pixels: the capsule sheet's rows run least to most.)
	local h = math.max(CAPSULE.least + 2 * TAG.rim, math.min(CAPSULE.most, 2 * math.floor(TAG.tall * per / 2 + 0.5)))
	if tag.h ~= h or tag.per ~= per then
		tag.h, tag.per = h, per
		tag:SetHeight(h * unit)
		LayCapsule(tag.edge, tag, h, 0, unit)
		LayCapsule(tag.fill, tag, h - 2 * TAG.rim, TAG.rim, unit)
		tag:ClearAllPoints()
		tag:SetPoint("TOP", holder, "BOTTOM", 0, math.floor(h * TAG.tuck + 0.5) * unit)
	end
	-- As wide as its words, its round ends and room either side, in whole pixels.
	local wide = math.ceil(holder.clock:GetStringWidth() * per) + h + 2 * TAG.pad
	if tag.wide ~= wide or tag.wideAt ~= per then
		tag.wide, tag.wideAt = wide, per
		tag:SetWidth(wide * unit)
	end
	tag:Show()
end

-- The tag's rim in the trip's color.
function Trip:TagColor(holder)
	for _, part in ipairs(holder.tag.edge) do part:SetVertexColor(self.color[1], self.color[2], self.color[3], 1) end
end

function Trip:Rehover(holder)
	if holder.over and Owns(holder) then self:Hover(holder) end
end

-- side: where its hover opens.
function Trip:NewMark(parent, size, side)
	local trip = self
	local holder = CreateFrame("Frame", nil, parent)
	holder.side = side
	holder:SetSize(size, size)
	holder:SetFrameLevel(parent:GetFrameLevel() + 6)
	local mark = Maps.Mark(holder, size)
	mark:SetAllPoints()
	holder.mark = mark
	-- Its time, on a tag tucked under its foot (Clocked lays it), over the mark so the two are one badge.
	local tag = CreateFrame("Frame", nil, holder)
	tag:SetFrameLevel(mark:GetFrameLevel() + 2)
	tag.edge, tag.fill = Capsule(tag, "BACKGROUND", 0), Capsule(tag, "BACKGROUND", 1)
	for _, part in ipairs(tag.fill) do part:SetVertexColor(TAG.fill[1], TAG.fill[2], TAG.fill[3], TAG.fill[4]) end
	tag:Hide()
	holder.tag = tag
	holder.clock = UI.Text(tag, "", TAG.text, true)
	holder.clock:SetPoint("CENTER", tag, "CENTER", 0, 0)
	self:TagColor(holder)
	holder:SetMouseMotionEnabled(true)
	holder:SetScript("OnEnter", function(this)
		this.over = true
		this.mark:Set(trip.sign, trip.color, true)
		trip:Hover(this)
	end)
	holder:SetScript("OnLeave", function(this)
		this.over = false
		this.mark:Set(trip.sign, trip.color, false)
		if Shy.Hover then Shy.Hover.Hide(this) end
	end)
	return holder
end

-- One point of a journey, shifted toward where the rider stands. The shift is shed over TAPER yards.
local function Ridden(line, i, pn, pw, offN, offW, along)
	local n, w = line.north[i], line.west[i]
	if not offN then return n, w, n, w, along end
	along = along + math.sqrt((n - pn) ^ 2 + (w - pw) ^ 2)
	local keep = 1 - along / TAPER
	if keep > 0 then return n + offN * keep, w + offW * keep, n, w, along end
	return n, w, n, w, along
end

-- Where the trip leads, said for a map that looks ahead along it (Shy.Maps.Lead): its line from the point
-- ahead of the player to where it lands; nowhere with no line.
function Trip:Lead(line, first, last)
	if line and last and line.north[last] then
		Maps.Lead(self, line.continent, line.north[last], line.west[last], line, first, last)
	else
		Maps.Lead(self)
	end
end

-- The minimap: the line from its middle to the mark, which waits at the rim where the line leaves it.
local AHEAD = 500            -- yards of a journey drawn ahead of the plate's shot
function Trip:LayMini()
	local mini = self.mini
	local v = Maps.Mini(self.view)
	local line, first, last
	if v then line, first, last = self.spec.Line(v.continent, v.north, v.west) end
	-- (Asked here at every frame the trip shows, so the point ahead is the one ahead now.)
	self:Lead(line, first, last)
	if not line then
		if mini.held and Maps.Drop then Maps.Drop() end
		mini.held, mini.line = nil, nil
		mini.frame:Hide()
		return
	end
	Maps.RimMask(mini.mask, v.radius, v.square)
	local shot, plate
	if Maps.Carry then shot, plate = Maps.Carry(v) end
	local ride = shot and plate
	if ride and shot.held then
		mini.held = true
	elseif mini.held then
		if Maps.Drop then Maps.Drop() end
		mini.held = nil
	end
	local levels = Minimap:GetZoomLevels() or 0
	local grow = 1 + MINI_GROW * (levels > 1 and Minimap:GetZoom() / (levels - 1) or 0)
	local size = MINI_SIZE * grow
	local holder = mini.mark
	-- (The path laid is kept while the rider is only a few of its points further on: a flight passes one
	-- every few yards, and laying it again at each was most of a flight's cost. What the rider has passed
	-- since is put out of sight as they pass it: Shy.Maps.Start, below.)
	local kept = ride and mini.line == line and mini.first and first >= mini.first and first - mini.first < Trip.KEEP_AHEAD
		and mini.last == last and mini.gen == shot.gen and mini.grow == grow
	local view = v
	local riderX, riderY
	if ride then
		view = mini.view or {}
		mini.view = view
		view.reach, view.radius, view.continent = shot.reach, shot.radius, shot.continent
		view.north, view.west, view.sin, view.cos, view.square = shot.north, shot.west, shot.sin, shot.cos, v.square
		-- The path rides a plate of its own, laid out as the shot's and slid with it: a region slides with the
		-- frame it is anchored to only within its own frame's tree.
		local x, y = Maps.OnMini(view, v.north, v.west)
		x, y = x * shot.radius, y * shot.radius
		riderX, riderY = x, y
		if x ~= mini.plateX or y ~= mini.plateY then
			mini.plateX, mini.plateY = x, y
			mini.plate:SetPoint("CENTER", Minimap, "CENTER", -x, -y)
		end
		plate = mini.plate
	end
	if not kept then
		-- On the plate the path is the world's, and a short piece joins it to the rider. With no plate
		-- the line starts at the rider, as it always did.
		local count, lx, ly = 1, 0, 0
		xs[1], ys[1] = 0, 0
		if ride then
			-- (From the rider, where they stand on the plate: the path's next point may be yards ahead.)
			xs[1], ys[1] = riderX, riderY
			lx, ly = riderX / view.radius, riderY / view.radius
		end
		mini.pen.anchor = ride and plate or Minimap
		-- (The rider's offset from where they are now, not from where the plate was drawn (`view`, on the
		-- plate): it joins the line to them, and taken from there it led to a place long since flown past.)
		local pn, pw, offN, offW = Offset(self, line, first, v.north, v.west)
		local along, span = 0, math.max(AHEAD, view.reach * 2.5)
		for i = first, last do
			local n, w
			n, w, pn, pw, along = Ridden(line, i, pn, pw, offN, offW, along)
			local x, y = Maps.OnMini(view, n, w)
			if x ~= lx or y ~= ly then
				if ride then
					count = count + 1
					xs[count], ys[count] = x * view.radius, y * view.radius
					lx, ly = x, y
					if (n - view.north) ^ 2 + (w - view.west) ^ 2 > span * span then break end
				else
					local _, _, bx, by, cut = Maps.Within(lx, ly, x, y, v.square)
					if not bx then break end
					count = count + 1
					xs[count], ys[count] = bx * v.radius, by * v.radius
					if cut then break end
					lx, ly = x, y
				end
			end
		end
		if ride then
			mini.line, mini.first, mini.last, mini.gen, mini.grow = line, first, last, shot.gen, grow
		else
			mini.line = nil
		end
		Maps.Begin(mini.pen, MINI_LINE * grow)
		count = Maps.Trim(xs, ys, count, ride and 0 or MINI_YOU, size * RIM)
		if count > 1 then Maps.Ribbon(mini.pen, xs, ys, count, self.color, self.look) end
		Maps.Finish(mini.pen)
	end
	-- On the plate the path is kept while the rider passes a few of its points: every frame it begins where
	-- they are now (Shy.Maps.Start), clear of their arrow, so it keeps up with them however fast they go,
	-- never trailing back to where it was laid. Strayed off it, it is laid again next frame.
	if ride then
		local stray = Maps.Start(mini.pen, riderX, riderY, MINI_YOU)
		if stray and stray > Trip.STRAY then mini.line = nil end
	end
	-- Where the mark sits. In range it rides the plate, and a step moves it with the path. Out of range
	-- it waits at the rim: only that direction is worked out, and the path stays where it was drawn.
	holder:SetSize(size, size)
	holder.mark:SetSize(size, size)
	if not (kept and mini.inside) then
		local lx, ly, bx, by, waiting = 0, 0, nil, nil, false
		local pn, pw, offN, offW = Offset(self, line, first, v.north, v.west)
		local along = 0
		for i = first, last do
			local n, w
			n, w, pn, pw, along = Ridden(line, i, pn, pw, offN, offW, along)
			local x, y = Maps.OnMini(v, n, w)
			if x ~= lx or y ~= ly then
				local _, _, cx, cy, cut = Maps.Within(lx, ly, x, y, v.square)
				if not cx then break end
				bx, by = cx, cy
				if cut then
					waiting = true
					break
				end
				lx, ly = x, y
			end
		end
		mini.inside = ride and not waiting
		local parent, px, py
		if mini.inside then
			local sx, sy = Maps.OnMini(view, line.north[last], line.west[last])
			parent, px, py = plate, sx * shot.radius, sy * shot.radius
		else
			parent, px, py = Minimap, (bx or 0) * v.radius, (by or 0) * v.radius
		end
		if holder.hold ~= parent or not holder.hx or math.abs(holder.hx - px) > 0.5 or math.abs(holder.hy - py) > 0.5 then
			holder:ClearAllPoints()
			holder:SetPoint("CENTER", parent, "CENTER", px, py)
			holder.hold, holder.hx, holder.hy = parent, px, py
		end
		-- (Whole whether in range or waiting at the rim: where the trip lands is never faded out.)
		holder:SetAlpha(1)
	end
	mini.frame:Show()
end

-- The world map: the line from the player to the mark where it lands, as far as the map shows it.
function Trip:LayMap()
	local map = self.map
	if not map or not map.frame:IsVisible() then return end
	-- (The map shown by whatever draws it: the game, or ShyMaps' view.)
	local shown = Maps.ShownMap()
	local position = shown and C_Map.GetPlayerMapPosition(shown, "player")
	local continent, world
	if position then continent, world = C_Map.GetWorldPosFromMapPos(shown, position) end
	local line, first, last
	if world then line, first, last = self.spec.Line(continent, world:GetXY()) end
	local unit = Maps.MapScale()
	local width, height = map.frame:GetWidth(), map.frame:GetHeight()
	local x, y
	if position then x, y = position:GetXY() end
	-- (GetPlayerMapPosition gives 0, 0 for a map the player isn't on.)
	if not line or not unit or width <= 0 or not x or (x <= 0 and y <= 0) then
		Maps.Begin(map.pen, unit or 1)
		Maps.Finish(map.pen)
		if map.link then
			Maps.Begin(map.link, 1)
			Maps.Finish(map.link)
		end
		map.road = nil
		map.mark:Hide()
		return
	end
	-- The line's points on this map, kept for as long as the line and the map are the same.
	local on = map.on
	if on.line ~= line or on.map ~= shown or on.n ~= line.n then
		on.line, on.map, on.n = line, shown, line.n
		Maps.LineToMap(shown, line.continent, line.north, line.west, line.n, on.fx, on.fy)
	end
	local size = MAP_SIZE * unit
	-- The path ahead is of the world, so it is drawn once for this point of it. Walking or flying
	-- changes only the piece from the player to where that line begins.
	local past = 0.02 + Maps.Beyond()
	local kept = map.road and map.road.line == line and map.road.first == first and map.road.last == last
		and map.road.map == shown and map.road.w == width and map.road.h == height and map.road.unit == unit
		and map.road.past == past
	if not map.link then map.link = Maps.Pen(map.frame, "TOPLEFT", map.frame, true, true) end
	if kept then
		local holder = map.mark
		holder:SetShown(map.road.lands)
		Maps.Begin(map.link, unit)
		local jx, jy = map.road.jx, map.road.jy
		if jx then
			xs[1], ys[1] = x * width, y * height
			xs[2], ys[2] = jx, jy
			local n = Maps.Trim(xs, ys, 2, MAP_SIZE * MAP_YOU * unit, 0)
			if n > 1 then Maps.Ribbon(map.link, xs, ys, n, self.color, self.look) end
		end
		Maps.Finish(map.link)
		return
	end
	local count, lands = 0, true
	-- (Aboard: the line from where the player stands, their offset from it shed over TAPER yards; the
	-- offset on this map is from where they stand on the line to where the map has them.)
	local pn, pw, offN = Offset(self, line, first, world:GetXY())
	local ox, oy, along = 0, 0, 0
	if offN then
		local sx, sy = Maps.ToMap(shown, line.continent, pn, pw)
		if sx then ox, oy = x - sx, y - sy else offN = nil end
	end
	for i = first, last do
		local fx, fy = on.fx[i], on.fy[i]
		if not fx then
			lands = false
			break
		end
		if offN then
			local n, w = line.north[i], line.west[i]
			along = along + math.sqrt((n - pn) ^ 2 + (w - pw) ^ 2)
			pn, pw = n, w
			local keep = 1 - along / TAPER
			if keep > 0 then fx, fy = fx + ox * keep, fy + oy * keep end
		end
		count = count + 1
		xs[count], ys[count] = fx * width, fy * height
		-- (Where it leaves what the map's window may show it ends: the map's own edge, or as far past it as
		-- the ground goes on, Maps.Beyond.)
		if fx < -past or fx > 1 + past or fy < -past or fy > 1 + past then
			lands = false
			break
		end
	end
	local jx, jy = xs[1], ys[1]
	local ex, ey = xs[count], ys[count]
	local holder = map.mark
	holder:SetShown(lands and count > 0)
	if lands and count > 0 then
		holder:SetScale(unit)
		holder:ClearAllPoints()
		holder:SetPoint("CENTER", map.frame, "TOPLEFT", ex / unit, -ey / unit)
		if holder.scaled ~= unit then
			holder.scaled = unit
			holder.mark:Set(self.sign, self.color, holder.over)
		end
	end
	Maps.Begin(map.pen, unit)
	if count > 1 then
		count = Maps.Trim(xs, ys, count, 0, lands and size * RIM or 0)
		if count > 1 then Maps.Ribbon(map.pen, xs, ys, count, self.color, self.look) end
	end
	Maps.Finish(map.pen)
	Maps.Begin(map.link, unit)
	if jx then
		xs[1], ys[1] = x * width, y * height
		xs[2], ys[2] = jx, jy
		local n = Maps.Trim(xs, ys, 2, MAP_SIZE * MAP_YOU * unit, 0)
		if n > 1 then Maps.Ribbon(map.link, xs, ys, n, self.color, self.look) end
	end
	Maps.Finish(map.link)
	map.road = { line = line, first = first, last = last, map = shown, w = width, h = height, unit = unit, jx = jx, jy = jy, lands = lands,
		past = past }
end

-- Runs fn(self) unless the trip is put away; an error puts it away and is told once.
function Trip:Safe(fn)
	if self.broken then return end
	local ok, err = pcall(fn, self)
	if not ok then
		self.broken = true
		Maps.Lead(self)
		self.mini.frame:Hide()
		if self.map then
			Maps.Begin(self.map.pen, 1)
			Maps.Finish(self.map.pen)
			self.map.mark:Hide()
		end
		geterrorhandler()(err)
	end
end

function Trip:SetupMap()
	if self.map or not WorldMapFrame then return end
	local map = { frame = Maps.MapLayer(1), on = { fx = {}, fy = {} } }
	self.map = map
	map.pen = Maps.Pen(map.frame, "TOPLEFT", map.frame, true, true)
	map.mark = self:NewMark(map.frame, MAP_SIZE)
	map.mark:Hide()
	Maps.OnMap(function() self:Safe(self.LayMap) end)
	-- (Kept out of sight while ShyMaps' view opens: laid as it comes into sight.)
	map.frame:SetScript("OnShow", function() self:Safe(self.LayMap) end)
	local since, ticks = 0, 0
	map.frame:SetScript("OnUpdate", Shy.Clocked("trip: " .. tostring(self.strip) .. " on the world map", function(_, elapsed)
		since = since + elapsed
		if since >= MAP_EVERY then
			since = 0
			ticks = ticks + 1
			self:Safe(function()
				self:LayMap()
				self:Clocked(map.mark)
				if ticks % 5 == 0 then self:Rehover(map.mark) end
			end)
		end
		Maps.Shine(map.pen, GetTime())
		if map.link then Maps.Shine(map.link, GetTime()) end
	end))
end

function Trip:SetupMini()
	local mini = { frame = CreateFrame("Frame", nil, Minimap) }
	self.mini = mini
	mini.frame:SetAllPoints()
	mini.frame:Hide()
	-- The path can run on past the rim, so it is clipped. The mark stays on the frame: its time sits
	-- just outside the rim and must not be cut off.
	local clip = CreateFrame("Frame", nil, mini.frame)
	clip:SetAllPoints()
	clip:SetClipsChildren(true)
	mini.pen = Maps.Pen(clip, "CENTER", Minimap, false, true)
	-- (It melts away at the minimap's rim, as the trail does: Maps.RimMask, shaped as it is laid.)
	mini.mask = clip:CreateMaskTexture()
	mini.mask:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	mini.pen.mask = mini.mask
	mini.plate = CreateFrame("Frame", nil, clip)
	mini.plate:SetSize(1, 1)
	mini.plate:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	mini.mark = self:NewMark(mini.frame, MINI_SIZE, "LEFT")
	mini.mark.mark:Set(self.sign, self.color, false)
	local since = 0
	-- (Shown while there is a line: hidden, it no longer runs, and Update shows it again.)
	mini.frame:SetScript("OnUpdate", Shy.Clocked("trip: " .. tostring(self.strip) .. " on the minimap", function(_, elapsed)
		self:Safe(function()
			self:LayMini()
			since = since + elapsed
			if since >= 1 then
				since = 0
				self:Clocked(mini.mark)
				self:Rehover(mini.mark)
			end
		end)
		Maps.Shine(mini.pen, GetTime())
	end))
end

function Trip:Update()
	self.broken = false
	if not self.map then self:SetupMap() end
	self:Safe(function()
		local mini, map = self.mini, self.map
		mini.mark.mark:Set(self.sign, self.color, mini.mark.over)
		self:Clocked(mini.mark)
		self:LayMini()
		if not mini.frame:IsShown() and Owns(mini.mark) then Shy.Hover.Hide(mini.mark) end
		if map then
			map.mark.scaled = nil
			self:Clocked(map.mark)
			self:LayMap()
			if not map.mark:IsShown() and Owns(map.mark) then Shy.Hover.Hide(map.mark) end
		end
	end)
end

function Trip:Look(sign, color, strip)
	self.strip = strip or self.strip
	if sign == self.sign and color == self.color then return end
	self.sign, self.color = sign or self.sign, color or self.color
	self:TagColor(self.mini.mark)
	if self.map then self:TagColor(self.map.mark) end
	self:Update()
end

function Maps.Trip(spec)
	local trip = setmetatable({ spec = spec, sign = spec.sign, color = spec.color, strip = spec.strip, look = spec.look or Maps.JOURNEY,
		view = {} }, Trip)
	trip:SetupMini()
	-- (The world map's layer is made at the first Update: the map may not be there yet when the trip is.)
	return trip
end
