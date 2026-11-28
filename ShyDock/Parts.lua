-- The screen as the console plans it, as a list of rectangles: every piece the
-- layout places and what stands with it, each with its kind. Touches no frame:
-- everything comes from the console's plan (Console.Build), what was measured
-- for it (Layout's `now`) and the cockpit's plan (Layout.Cockpit). The preview
-- draws the list (Preview.lua), the ghost labels it, and so can anything else
-- that has a plan and no screen.
--
--   ns.Parts.List(g, now, c, s)  ->  { { l, b, r, t, kind, label, group, cells, color, share }, ... }
--     g      Console.Build's plan
--     now    its inputs and measurements: screen, height, plates, rise, under, map, column, raid
--     c      the cockpit's plan (Layout.Cockpit), or nil to leave the cockpit out
--     s      switches: deck (the guide docks under the minimap), arrange; top: the column down from the
--            top's middle as Shy.Top plans it, or nil to leave it out; stand: the armor stand's piece
--            ({ id, width, height, scale, sample, passing }), or nil while there is none; threat: the threat
--            meter's piece ({ id, width, height, scale, head, row, rows }: standing on the damage meter in a
--            classic layout, by your target in one by role), or nil while it is off; farm: ShyFarm's session piece
--            ({ id, width, height, scale, passing }: the top left's corner, over how to play), or nil while it is off
--   l, b, r, t   x from the screen's middle, y up from its foot, in screen units
--   kind         what the piece is (KINDS below); a kind is drawn one way
--   label        the name the ghost shows; a piece with none is part of a labelled one
--   group        true: the piece is a labelled outline round smaller pieces, not drawn itself
--   cells        a row of cells: how many, drawn from the rect's right end when `fromRight`
--   color        a plate's fill: "health", "bad", "mana"
--   piece        a "top" part's entry in Shy.Top's plan: its picture's builder, its scale, whether it comes and goes
--
-- Kinds: chat, meter, housing, button, rack, pull, tray, plate, small, party, raid, xp, petbar, map, buffs, buff,
-- debuffs, debuff, column, guide, objectives, menu, bags, cockpit, cast, tracked, bars, extra, top, stand, threat, farm.
-- A pull is a drawer's (Shy.Drawer): the menu's on top of its tray (the panel its rows stand in), a
-- rack's astride the seam beside it; `side` says which edge of the drawer it is on (the drawer slides
-- out away from it).

local ADDON, ns = ...
local Console = ns.Console
local max, min = math.max, math.min

local P = {}
ns.Parts = P

-- The buff and debuff rows at the top right, left of the minimap (Auras.lua): rows of CELL, the icons AURA
-- square, the debuffs a row under the buffs' right end. How many are drawn.
P.AURA, P.CELL, P.FOLD, P.AURA_GAP = 30, 40, 15, 4
P.BUFFS, P.DEBUFFS = 7, 2
-- The guide card and the objectives, as drawn: about this tall.
P.GUIDE, P.OBJECTIVES = 270, 140
-- The top left's corner, from it (x right, y down): how to play's own home (ShyCore's keys guide), where a farming
-- session (ShyFarm) stands while you farm, how to play under it. (In a raid on a classic layout the raid's frames
-- have the corner: Arrange.lua.)
P.TOP_LEFT = { x = 16, y = -16 }
-- Cells in the micro menu's row, tiles in the bags', rows of raid frames drawn.
P.MENU_CELLS, P.BAG_TILES, P.RAID_ROWS = 10, 5, 2
-- The pet bar: its buttons in their housing, over the housing's right end (Layout.lua, End; Console.PET).
P.PET_BUTTONS, P.PET_SIZE, P.PET_GAP, P.PET_PAD = ns.Console.PET.count, ns.Console.PET.button, ns.Console.PET.gap,
	ns.Console.PET.pad
-- The cockpit's labelled outlines: its rect's key, the label, and whether it is the accent's.
P.COCKPIT = {
	{ "box", "Cooldown manager", "cockpit", true }, { "cast", "Cast bar", "cast" }, { "buffs", "Tracked buffs", "tracked" },
	{ "barsWing", "Tracked bars", "bars" },
}

-- ShyFrames' plates over the housing, and what goes with them: the party row over the plates
-- (Place.lua, P.Lift), the small frames (focus and pet left, the target's target right) on the
-- wings' roofs in the console, beside the plates in the corner layouts. Beside them they stand on the
-- plates' foot: the target's target down at your target's right, your focus its mirror, your pet over it.
-- In the plates' proportions.
function P.Plates(g, now)
	local SEAM = Console.SEAM
	local h = g.housing
	local foot, top = h.top + SEAM, h.top + now.plates
	-- Their widths as ShyFrames has them (Layout.lua's now.beside); a plan made without ShyFrames' measure
	-- (a drawing tool's) draws them in the plates' proportions.
	local guess = (h.right - h.left) / 2 * 0.5
	local beside = now.beside
	local small = { w = beside and beside.left or guess, right = beside and beside.right or guess, h = now.plates * 0.75 }
	local lift = now.rise - now.plates   -- what rises over the plates, and a seam
	local p = { foot = foot, top = top, party = { h.left, top + lift, h.right, top + lift + now.plates * 0.78 } }
	-- What they can stand on: the wings' roof (a corner layout's too, where they don't fit beside the
	-- plates: g.roofed), or the flanks' racks (Housing.lua, T:Roof).
	local roof = (g.line == nil and g.wingTop) or (g.roofed and g.line)
		or (Console.RACKED[g.style] and (g.rack.left or g.rack.right) and g.rack.top) or nil
	if roof and roof > top - small.h then
		-- On the roofs, flush with the wings' (or racks') inner ends.
		roof = roof + SEAM
		local l = g.roofed and g.chat.art[3] or h.left - SEAM
		local r = g.roofed and g.meter and g.meter.art[1] or h.right + SEAM
		p.focus = { l - small.w, roof, l, roof + small.h }
		p.pet = { l - small.w, roof + small.h + SEAM, l, roof + 2 * small.h + SEAM }
		p.tot = { r, roof, r + small.right, roof + small.h }
	else
		p.focus = { h.left - SEAM - small.w, foot, h.left - SEAM, foot + small.h }
		p.pet = { h.left - SEAM - small.w, foot + small.h + SEAM, h.left - SEAM, foot + 2 * small.h + SEAM }
		p.tot = { h.right + SEAM, foot, h.right + SEAM + small.right, foot + small.h }
	end
	return p
end

-- The small frames on one side of the plates in a classic layout ("left": focus and pet; "right": your target's
-- target), as one rect { l, b, r, t }; nil with none there.
function P.Small(g, now, side)
	if (now.plates or 0) <= 0 then return nil end
	local p = P.Plates(g, now)
	if side == "right" then
		local r = p.tot
		return r[3] > r[1] and { r[1], r[2], r[3], r[4] } or nil
	end
	local f, e = p.focus, p.pet
	if f[3] <= f[1] then return nil end
	return { min(f[1], e[1]), min(f[2], e[2]), max(f[3], e[3]), max(f[4], e[4]) }
end

-- The armor stand (ShySkin's): a seam left of the minimap column, its top on the line the guide hangs from
-- (a seam under the map's foot), so it stands beside the column's head, clear of the buff rows over it.
-- w, h: the piece's size in screen units. Returns l, b, r, t on whole units.
function P.Stand(now, w, h)
	local SEAM, CORNER = Console.SEAM, Console.CORNER
	local r = math.floor(now.screen / 2 - CORNER - now.map.width - SEAM)
	local t = math.floor(now.height - CORNER - now.map.height - SEAM)
	return r - w, t - h, r, t
end

-- Where the minimap column stops above the console (in the corner layouts, above chat's and the meter's roof,
-- and over the small frames where they stand on it: g.roofed).
function P.ColumnFloor(g, now)
	if g.line then return g.line + 2 * Console.SEAM + ((g.roofed and now.plates > 0) and now.plates or 0) end
	return g.wingTop + 2 * Console.SEAM + (now.plates > 0 and now.plates or 0)
end

-- Where the pieces that stand on the wings start: a seam over their roof (in the corner layouts the corners' line),
-- clear of the small frames where they stand on it. The stack over chat's outer end (Arrange.lua) goes up from here.
function P.StackFloor(g, now)
	local SEAM = Console.SEAM
	if g.line then return g.line + SEAM + ((g.roofed and g.plates > 0 and now.plates > 0) and now.plates or 0) end
	return g.wingTop + SEAM + (now.plates > 0 and now.plates or 0)
end

-- The layouts by role: where each of your frames, the group and the threat meter stand (Console.ROLE has the
-- design board's numbers). One plan: the game's layout (Layout.lua), the live homes (Arrange.lua, ShyFrames
-- through Dock:UnitHomes) and every drawing read it.
--   P.Role(g, now, c, piece)  ->  { player, target, targettarget, focus, pet, group, threat, bars = rects { l, b, r, t }
--                                  (group: the raid's place, and the game's own party frames'; partyAt: where
--                                  ShyFrames' party stands, the group's unless the role stands it by your frames;
--                                  bars: the tracked bars' home, while c has them: P.BarsHome; barsRows the
--                                  rows it holds, barsGrow "down" or "up"; strip: the pings and markers, with
--                                  `strip`: P.StripHome);
--                                  party = "row" | "column", raid = an Enum.RaidGroupDisplayType key, rows = the
--                                  threat meter's most rows }, or nil in a classic layout
--     c      the cockpit's plan (the healer's group stands over it), or nil (it is reckoned at VESSEL tall)
--     piece  the threat meter's piece (ShyThreat's T:Piece), or nil for none
--     strip  the pings and markers' block { w, h } (P.StripSize), or nil to leave them out
-- now.units has each frame's size ({ w, h }, ShyFrames' T:Sizes, or the game's frames' when ShyFrames isn't
-- there); P.UNITS stands in for a plan made without them (a drawing tool's).
-- (`column`: ShyFrames' party as a column, four cells with what rises over each; only its height is read.)
P.UNITS = { player = { 232, 52 }, target = { 232, 52 }, targettarget = { 120, 34 }, focus = { 160, 36 }, pet = { 160, 36 },
	column = { 165, 245 } }

-- The threat meter's piece (ShyThreat's T:Piece), or nil while ShyThreat is off.
function P.ThreatPiece()
	local threat = Shy.addons.Threat
	return threat and threat.Piece and threat:Piece() or nil
end

-- One cell of ShyFrames' healing grid ({ w, h }, screen units) where the party stands as it in the layout drawn
-- (the healer's by default, any while your group made you its healer: ShyFrames' T:GridIn); nil otherwise.
function P.GridCell(now)
	local frames = Shy.addons.Frames
	local cell = now.units and now.units.cell
	if now.raiding or not (cell and frames and frames.GridIn) then return nil end
	return frames:GridIn(now.style == "healer" and "healer" or nil) and cell or nil
end

-- The pings and markers' block as it stands alone ({ w, h }, screen units), or nil while ShyTip's is off.
P.STRIP_ID = "shytip-strip"
function P.StripSize()
	local box = Shy.HUD.Find(P.STRIP_ID)
	if not box then return nil end
	local s = box:GetScale()
	return { box:GetWidth() * s, box:GetHeight() * s }
end
P.UNIT_GAP = 8        -- between two of your frames, and between them and what they hang under
P.SIDE_GAP = 18       -- between a frame and a piece standing beside it: their looks' borders reach past their edges
P.VESSEL = 70         -- the cooldown manager's height over the bars, for a plan made without its own

-- A frame `w` x `h` centred on x, y.
local function Centred(x, y, w, h) return { x - w / 2, y - h / 2, x + w / 2, y + h / 2 } end

function P.Role(g, now, c, piece, strip)
	local role = g.role
	if not role then return nil end
	local U, k = P.UNIT_GAP, g.k
	local units = now.units or P.UNITS
	local function Size(kind)
		local s = units[kind] or P.UNITS[kind]
		return s[1], s[2]
	end
	-- Under what the frames must stand clear of: the bars and their racks, and the cooldown manager over them.
	local h = g.housing
	local floorTop = max(h.top, g.rack and g.rack.top or 0)
	-- The cooldown manager's plate (in a layout by role the tracked bars stand apart from it: out.bars, below).
	local box = c and c.rects and c.rects.box
	local vesselTop = box and max(box[4], c.above or box[4]) or (h.top + U + P.VESSEL)
	local vesselHalf = box and max(math.abs(box[1]), math.abs(box[3])) or (g.width / 2 - 80)
	local out = { party = role.group.party, raid = role.group.raid }
	local pw, ph = Size("player")
	local tw, th = Size("target")
	local x = role.unitX * k
	local half = max(pw, tw) / 2
	-- The group under your character (the healer's), as wide as it stands: the raid's frames at the role's width,
	-- or ShyFrames' healing grid, five cells (you and a full party) and narrower. Round the grid your frames come
	-- in to its sides, a side's gap off, however large the screen: the board's distance grows with the screen
	-- and the grid doesn't, which would leave them far out from the five you heal.
	local wide = role.group.under and role.group.w or nil
	local cell = wide and P.GridCell(now)
	if cell then
		wide = 5 * cell[1] + 4 * Console.SEAM
		x = wide / 2 + P.SIDE_GAP + half
	end
	-- Never over the cooldown manager, nor over the group: their inner edges a gap outside them.
	x = max(x, vesselHalf + U + half)
	if wide and not cell then x = max(x, wide / 2 + U + half) end
	local y = now.height / 2 + role.unitY * k
	-- Your target's target hangs a gap under your target, flush with its outer end; your focus is its mirror under
	-- you, and your pet hangs under your focus. Nothing stands over your frames' auras.
	local function Lay(dy)
		local cy = y + dy
		out.player = Centred(-x, cy, pw, ph)
		out.target = Centred(x, cy, tw, th)
		local p, t = out.player, out.target
		local sw, sh = Size("targettarget")
		local fw, fh = Size("focus")
		local ew, eh = Size("pet")
		out.targettarget = { t[3] - sw, t[2] - U - sh, t[3], t[2] - U }
		out.focus = { p[1], p[2] - U - fh, p[1] + fw, p[2] - U }
		local f = out.focus
		out.pet = { p[1], f[2] - U - eh, p[1] + ew, f[2] - U }
	end
	Lay(0)
	-- The lowest of them (your pet, your target's target) stay a gap over the bars and their racks, and over chat
	-- and the meter where they stand over them (a short screen).
	local lift = 0
	for _, r in ipairs({ out.pet, out.targettarget }) do
		lift = max(lift, floorTop + U - r[2])
		for _, under in ipairs({ g.chat and g.chat.art or false, g.meter and g.meter.art or false }) do
			if under and under[1] < r[3] + U and under[3] > r[1] - U then lift = max(lift, under[4] + U - r[2]) end
		end
	end
	if lift > 0 then Lay(lift) end

	-- The group: on the group column's left edge, at its own place, or (the healer's) under your character over
	-- the cooldown manager.
	local G = role.group
	if G.under then
		local b = vesselTop + U
		out.group = { -wide / 2, b, wide / 2, b + G.h }
	elseif G.left then
		local l = -now.screen / 2 + Console.CORNER + Console.RAID_TAB + Console.SEAM
		local cy = now.height / 2 + G.y * k
		out.group = { l, cy - G.h / 2, l + G.w, cy + G.h / 2 }
	else
		out.group = Centred(G.x * k, now.height / 2 + G.y * k, G.w, G.h)
	end
	-- A group beside your frames gives way to them: outward (away from the middle), a gap clear of the outermost it
	-- would touch, never past the group column's left edge.
	local column = -now.screen / 2 + Console.CORNER + Console.RAID_TAB + Console.SEAM
	-- At the column's edge and still on one of them (a narrow screen), or down on the bars' racks (or on what is in
	-- `more`): it rises over it.
	local function Rise(rect, more)
		local beneath = {}
		for _, r in ipairs(more or {}) do beneath[#beneath + 1] = r end
		if g.rack and g.rack.rects then
			for _, side in ipairs({ -1, 1 }) do
				if g.rack.rects[side] then beneath[#beneath + 1] = g.rack.rects[side] end
			end
		end
		for _, key in ipairs({ "pet", "player", "focus" }) do beneath[#beneath + 1] = out[key] end
		for _, r in ipairs(beneath) do
			if r[1] < rect[3] and r[3] > rect[1] and r[2] < rect[4] and r[4] > rect[2] then
				local rise = r[4] + U - rect[2]
				rect[2], rect[4] = rect[2] + rise, rect[4] + rise
			end
		end
	end
	if not G.under then
		local g2 = out.group
		for _, key in ipairs({ "focus", "player", "pet" }) do
			local r = out[key]
			if r[1] < g2[3] + U and r[3] > g2[1] - U and r[2] < g2[4] and r[4] > g2[2] then
				local shift = (g2[3] + U) - r[1]
				if g2[1] - shift < column then shift = g2[1] - column end
				g2[1], g2[3] = g2[1] - shift, g2[3] - shift
			end
		end
		Rise(g2)
	end

	-- Your party (ShyFrames' own cells; a raid, and the game's party frames, keep the group's place). A column
	-- (the role gives it a width of its own, `near`) stands a side's gap outside the outermost of your frames,
	-- hung from the top of the highest of them (as the tank's threat meter hangs from the top of your target's,
	-- the other side): the four you play with stand by you however wide the screen is, in cells no wider than
	-- your small frames: at the edge and as wide as the group they would be far away and too wide. Never past the group column's edge; on one of your frames there (a narrow screen), or down on
	-- chat or the bars' racks, it rises over it. A row under your character that is no healing grid (the healer's
	-- layout with the grid off, or while your group gave you another role) is as wide as your frame and your
	-- target's together, a quarter of them a cell as over the plates of a classic layout, not the raid's width.
	out.partyAt = out.group
	if G.under and not cell and not now.partyOurs then
		local w = pw + tw
		out.partyAt = { -w / 2, out.group[2], w / 2, out.group[4] }
	elseif G.near and not G.under and not now.partyOurs then
		local outer = min(out.focus[1], out.player[1], out.pet[1])
		local l = max(column, outer - P.SIDE_GAP - G.near)
		local top = max(out.focus[4], out.player[4])
		local _, tall = Size("column")
		out.partyAt = { l, top - tall, l + G.near, top }
		Rise(out.partyAt, { g.chat and g.chat.art })
	end

	-- The threat meter: under the frame it hangs from, or beside your target, as many rows as the role asks and as
	-- fit over what stands under it (the bars, their racks, the damage meter, chat, the group); with not even
	-- THREAT_LEAST rows' room under the frame, beside your target instead.
	if piece then
		local T = role.threat
		local want = min(T.rows, piece.rows or T.rows)
		local under = { { h.left, h.bottom, h.right, h.top }, g.chat and g.chat.art, g.meter and g.meter.art, out.group,
			out.partyAt }
		for _, side in ipairs({ -1, 1 }) do
			if g.rack and g.rack.rects and g.rack.rects[side] then under[#under + 1] = g.rack.rects[side] end
		end
		-- The most rows that fit hanging from `top` at `l`, down to whatever stands under it.
		local function Rows(l, top)
			local floorAt = 0
			for _, r in pairs(under) do
				if r and r[1] < l + T.w + U and r[3] > l - U and r[4] <= top then floorAt = max(floorAt, r[4] + U) end
			end
			return min(want, math.floor((top - floorAt - piece.head) / piece.row))
		end
		-- Kept a corner's inset inside the screen's right edge; moved in that far, it hangs under every frame it now
		-- stands under.
		local edge = now.screen / 2 - Console.CORNER
		local least = piece.head + P.THREAT_LEAST * piece.row
		local function OnScreen(l, top)
			l = min(l, edge - T.w)
			for _, key in ipairs({ "targettarget", "target", "focus", "player", "pet" }) do
				local r = out[key]
				if r[1] < l + T.w + U and r[3] > l - U and r[2] - U < top and r[4] > top - least then top = r[2] - U end
			end
			return l, top
		end
		-- Where it may hang, in order: under its frame, flush with its outer end as your target's target is (the
		-- right side one column); beside your target (when the screen has room); under your target. The first with
		-- THREAT_LEAST rows' room wins.
		local tries = {}
		if not T.beside then
			local over = out[T.under]
			tries[#tries + 1] = { OnScreen(over[3] - T.w, over[2] - U) }
		end
		local side = out.target[3] + P.SIDE_GAP
		if side + T.w <= edge then tries[#tries + 1] = { side, out.target[4] } end
		tries[#tries + 1] = { OnScreen(out.target[3] - T.w, out.target[2] - U) }
		for _, at in ipairs(tries) do
			local rows = Rows(at[1], at[2])
			if rows >= P.THREAT_LEAST then
				out.rows = rows
				out.threat = { at[1], at[2] - (piece.head + rows * piece.row), at[1] + T.w, at[2] }
				break
			end
		end
		-- No room under any of them (a short screen, your frames close over the bars): it stands over your target
		-- and the frames over it, a gap above the highest.
		if not out.threat then
			local l = min(out.target[1], edge - T.w)
			local b = out.target[4]
			for _, key in ipairs({ "targettarget", "target", "focus", "player" }) do
				local r = out[key]
				if r[1] < l + T.w + U and r[3] > l - U then b = max(b, r[4]) end
			end
			b = b + U
			out.rows = want
			out.threat = { l, b, l + T.w, b + piece.head + want * piece.row }
		end
	end

	-- The tracked bars' home, apart from the cooldown manager on your side (the threat meter's mirror): a drawer as
	-- wide as the threat meter, one edge fixed by what it belongs with, the bars growing away from it as they come. It
	-- keeps room for every bar you track (c.barsUp), so a class tracking many never spills: P.BarsHome. Then the
	-- pings and markers (`strip`, their block's { w, h }), by your target's frames: they act on your target.
	if c and c.barsUp and c.m then
		out.bars, out.barsRows, out.barsGrow = P.BarsHome(g, now, c, out, floorTop, vesselTop)
	end
	if strip then out.strip, out.stripGrow = P.StripHome(g, now, c, out, strip, floorTop, vesselTop) end
	return out
end

-- The first try with room for every row of a piece `w` wide (`Tall(n)` tall with n rows, `want` rows), else the one
-- with the most (never under one row); { l, b, r, t }, the rows, and which way it grows. A try is { left edge,
-- the edge it keeps, "down" (hung from that top edge) or "up" (standing on that foot) }. Room is what stays clear
-- of the bars and their racks, the cooldown manager, the group's place and your party's (at their full size),
-- the threat meter, chat, the meter, every unit frame, what is in `more` and the screen's edges.
local function Pick(g, now, c, out, floorTop, w, Tall, want, tries, more)
	local U, h = P.UNIT_GAP, g.housing
	local clear = { { h.left, h.bottom, h.right, h.top }, out.player, out.pet, out.focus, out.target, out.targettarget }
	for _, r in ipairs({ out.group or false, out.partyAt ~= out.group and out.partyAt or false, c and c.rects and c.rects.box or false, out.threat or false,
		g.chat and g.chat.art or false, g.meter and g.meter.art or false,
		g.rack and g.rack.rects and g.rack.rects[-1] or false, g.rack and g.rack.rects and g.rack.rects[1] or false }) do
		if r then clear[#clear + 1] = r end
	end
	for _, r in ipairs(more or {}) do clear[#clear + 1] = r end
	local edge = now.screen / 2 - Console.CORNER
	local HAIR = 0.5   -- a place a gap from a frame, worked out from the frame's own edge, is a gap from it
	local function Clear(l, b, top)
		if l < -edge - HAIR or l + w > edge + HAIR or b < floorTop + U - HAIR or top > now.height - Console.CORNER + HAIR then
			return false
		end
		for _, r in ipairs(clear) do
			if r[1] < l + w + U - HAIR and r[3] > l - U + HAIR and r[2] < top + U - HAIR and r[4] > b - U + HAIR then
				return false
			end
		end
		return true
	end
	local function Rect(at, n)
		if at[3] == "up" then return { at[1], at[2], at[1] + w, at[2] + Tall(n) } end
		return { at[1], at[2] - Tall(n), at[1] + w, at[2] }
	end
	local function Rows(at)
		for n = want, 1, -1 do
			local r = Rect(at, n)
			if Clear(r[1], r[2], r[4]) then return n end
		end
		return 0
	end
	local best, bestRows = nil, 0
	for _, at in ipairs(tries) do
		local rows = Rows(at)
		if rows == want then
			best, bestRows = at, rows
			break
		end
		if rows > bestRows then best, bestRows = at, rows end
	end
	if not best then best, bestRows = tries[#tries], want end
	return Rect(best, bestRows), bestRows, best[3]
end

-- Where the tracked bars live in a layout by role: the home { l, b, r, t }, how many rows it holds, and which way
-- they grow ("down" from its top edge, "up" from its foot). Tried in order: standing a gap over your frame, flush
-- with its outer end, growing up (the pings and markers stand so over your target: P.StripHome); the threat
-- meter's mirror on your side (its width, its top); under your frames, flush with your frame's left edge, hung
-- from a gap under them; beside them outward, hung from your frame's top; over them slid in clear of the group;
-- over your target's; over the cooldown manager.
function P.BarsHome(g, now, c, out, floorTop, vesselTop)
	local U, m = P.UNIT_GAP, c.m
	local function Tall(n) return n * (m.barH + m.barGap) - m.barGap + 2 * m.pad end
	local p, t = out.player, out.target
	-- As wide as the threat meter, its mirror on your target's side (the role's), never wider than your frame.
	local bw = min(g.role.threat.w, p[3] - p[1])
	local left, foot, high = math.huge, math.huge, -math.huge
	for _, r in ipairs({ out.player, out.pet, out.focus }) do
		left, foot, high = min(left, r[1]), min(foot, r[2]), max(high, r[4])
	end
	local tries = { { p[1], high + U, "up" } }
	local th = out.threat
	if th then tries[#tries + 1] = { -th[3], th[4], "down" } end
	tries[#tries + 1] = { p[1], foot - U, "down" }
	tries[#tries + 1] = { left - P.SIDE_GAP - bw, p[4], "down" }
	for _, G in ipairs({ out.group or false, out.partyAt ~= out.group and out.partyAt or false }) do
		if G and G[3] + U > p[1] and G[3] + U < p[3] and G[1] < p[1] then
			tries[#tries + 1] = { G[3] + U, high + U, "up" }
		end
	end
	tries[#tries + 1] = { t[3] - bw, max(t[4], out.targettarget[4]) + U, "up" }
	tries[#tries + 1] = { -bw / 2, vesselTop + U, "up" }
	return Pick(g, now, c, out, floorTop, bw, Tall, max(1, c.barsUp), tries)
end

-- Where the pings and markers stand in a layout by role (`size` their block's { w, h }): by your target's frames,
-- since they act on your target. Tried in order: standing a gap over the highest of what is over your target (the
-- threat meter, where it stands there), flush with your target's outer edge: the tracked bars' mirror over you;
-- then flush with your target's target's; hung a gap under your target where your pet hangs under you; beside them
-- outward, hung from your target's top; hung a gap under your target's; over the cooldown manager. Clear of
-- everything P.BarsHome keeps clear of, and the bars.
function P.StripHome(g, now, c, out, size, floorTop, vesselTop)
	local U, w, h = P.UNIT_GAP, size[1], size[2]
	local t, tt = out.target, out.targettarget
	-- A gap over the highest of your target's frames and the threat meter under a block at `l`.
	local function Over(l)
		local top = t[4]
		for _, r in ipairs({ t, tt, out.threat or false }) do
			if r and r[1] < l + w + U and r[3] > l - U then top = max(top, r[4]) end
		end
		return top + U
	end
	local pet = out.pet
	local tries = {
		{ t[3] - w, Over(t[3] - w), "up" },
		{ tt[3] - w, Over(tt[3] - w), "up" },
		{ -(pet[1] + pet[3]) / 2 - w / 2, pet[4], "down" },
		{ max(t[3], tt[3]) + P.SIDE_GAP, t[4], "down" },
		{ t[3] - w, t[2] - U, "down" },
		{ -w / 2, vesselTop + U, "up" },
	}
	local rect, _, grow = Pick(g, now, c, out, floorTop, w, function() return h end, 1, tries, { out.bars })
	return rect, grow
end

-- The threat meter in a classic layout: a meter window standing on the damage meter at its width, its foot a seam
-- over the meter's top (where the stack over chat starts, its mirror), growing up as far as its rows go; with no
-- meter, over the housing's right end at its own width. Its rows are the piece's, fewer where the minimap column
-- over it would be left under OBJECTIVES_LEAST. Returns l, b, r, t, rows.
P.OBJECTIVES_LEAST = 120   -- the least the objectives keep under the menu's tray (Arrange.lua's TRACKER_MIN)
P.THREAT_LEAST = 2         -- the threat meter never shows fewer rows than this
function P.Threat(g, now, piece)
	local scale = piece.scale or 1
	local r = g.meter and g.meter.art[3] or g.wings.right
	local w = g.meter and (g.meter.art[3] - g.meter.art[1]) or piece.width * scale
	local b = P.StackFloor(g, now)
	local rows = piece.rows or P.THREAT_LEAST
	if now.map and now.column then
		-- Where the column would stand over it: under the map and the rows' tray, with the objectives' least.
		local mapLeft = now.screen / 2 - Console.CORNER - now.map.width
		if r - w < now.screen / 2 - Console.CORNER and r > mapLeft then
			local room = Console.Column(now).foot - Console.SEAM - P.OBJECTIVES_LEAST - 2 * Console.SEAM - b
			local fit = math.floor((room / scale - piece.head) / piece.row)
			rows = max(P.THREAT_LEAST, min(rows, fit))
		end
	end
	local tall = (piece.head + rows * piece.row) * scale
	return r - w, b, r, b + tall, rows
end

-- The minimap column's foot, raised clear of the threat meter where the meter stands under the column (in the
-- corner layouts the meter is the bottom right corner, under it). l, r: the column's sides, from the screen's middle.
function P.ColumnClear(g, now, piece, foot, l, r)
	if not piece or g.role then return foot end
	local tl, _, tr, tt = P.Threat(g, now, piece)
	if tl < r and tr > l then return max(foot, tt + 2 * Console.SEAM) end
	return foot
end

function P.List(g, now, c, s)
	s = s or {}
	local SEAM, CORNER = Console.SEAM, Console.CORNER
	local half, H = now.screen / 2, now.height
	local list = {}
	local function Add(kind, l, b, r, t, more)
		if r - l < 1 or t - b < 1 then return nil end
		local part = { l, b, r, t, kind = kind }
		for key, value in pairs(more or {}) do part[key] = value end
		list[#list + 1] = part
		return part
	end
	local function Rect(kind, rect, more)
		if rect then return Add(kind, rect[1], rect[2], rect[3], rect[4], more) end
	end

	-- The wings
	Rect("chat", g.chat.art, { label = "Chat" })
	if g.meter then Rect("meter", g.meter.art, { label = "Damage meter" }) end

	-- The housing and its rows of buttons
	local h = g.housing
	Add("housing", h.left, h.bottom, h.right, h.top, { label = "Action bars" })
	for _, bar in ipairs(g.stacked) do
		for i = 0, Console.BUTTONS - 1 do
			local l = -g.width / 2 + i * g.pitch
			Add("button", l, g.rows[bar], l + g.button, g.rows[bar] + g.button)
		end
	end

	-- The racks (or the open layout's shelves), with their buttons
	local rack = g.rack
	local size = Console.BUTTON * rack.percent / 100
	local step = size + Console.SPACING * rack.percent / 100
	for _, side in ipairs({ -1, 1 }) do
		local r = rack.rects[side]
		if r then
			Add("rack", r[1], r[2], r[3], r[4], { label = rack.kind == "shelf" and "Shelf" or "Side bar" })
			for column = 0, rack.columns - 1 do
				for row = 0, rack.rows - 1 do
					local l, b = r[1] + Console.PAD + column * step, rack.bottom + row * step
					Add("button", l, b, l + size, b + size)
				end
			end
			-- The rack's drawer, out: its pull astride the seam beside it, as tall as the dock; the rack tucks
			-- toward it (`side`: the edge of the drawer the pull is on).
			Rect("pull", Console.Grip(g, side), { side = side > 0 and "left" or "right" })
		end
	end

	-- The XP and reputation bars under the floor (by role, under the bars and the pet bar): edge to edge with what
	-- stands across the floor, at the top of their room, a seam over its foot (ShyXP's Under.lua stands them so).
	if now.under > 0 then
		local foot = g.xp or 0
		Add("xp", g.span.left, foot + SEAM, g.span.right, foot + now.under, { label = "XP bar", share = 0.3 })
	end

	-- By role: your frames round your character, the group where the role wants it, the threat meter by your target.
	local role = P.Role(g, now, c, s.threat)
	if role then
		Add("plates", role.player[1], role.pet[2], role.target[3], max(role.player[4], role.target[4]),
			{ label = "Unit frames", group = true })
		Rect("plate", role.player, { color = "health" })
		Rect("plate", role.target, { color = "bad" })
		Rect("small", role.targettarget, { color = "bad" })
		Rect("small", role.focus, { color = "mana" })
		Rect("small", role.pet, { color = "health", faint = true })
		local G = now.raiding and role.group or role.partyAt
		Rect("party", G, { label = now.raiding and "Raid frames" or "Party", group = true })
		local cells, across = 4, role.party == "row" and 4 or 1
		if now.raiding then cells, across = 10, 5 end
		-- ShyFrames' healing grid: you and the party's four, each cell its own size (now.units.cell), a row
		-- centred along the group's foot or a column down from its top.
		local grid = P.GridCell(now)
		if grid then cells, across = 5, role.party == "row" and 5 or 1 end
		local down = math.ceil(cells / across)
		local cw = grid and grid[1] or (G[3] - G[1] - (across - 1) * SEAM) / across
		local ch = grid and grid[2] or min(44, (G[4] - G[2] - (down - 1) * SEAM) / down)
		local left, top = G[1], G[4]
		if grid and across > 1 then
			left, top = (G[1] + G[3]) / 2 - (across * cw + (across - 1) * SEAM) / 2, G[2] + ch
		end
		for i = 0, cells - 1 do
			local col, row = i % across, math.floor(i / across)
			local l, t = left + col * (cw + SEAM), top - row * (ch + SEAM)
			Add("small", l, t - ch, l + cw, t, { color = "health", faint = true })
		end
		if role.threat then Rect("threat", role.threat, { label = "Threat meter", piece = s.threat, faint = true }) end
		local petW = P.PET_BUTTONS * P.PET_SIZE + (P.PET_BUTTONS - 1) * P.PET_GAP
		local foot = g.petBar + P.PET_PAD
		Add("petbar", -petW / 2, foot, petW / 2, foot + P.PET_SIZE, { label = "Pet bar", cells = P.PET_BUTTONS, faint = true })
	elseif s.threat then
		-- Classic: a meter window standing on the damage meter (P.Threat)
		local l, b, r, t = P.Threat(g, now, s.threat)
		Add("threat", l, b, r, t, { label = "Threat meter", piece = s.threat, faint = true })
	end

	-- ShyFrames' plates, the small frames and the party's row (where it stands while you're in a group)
	if now.plates > 0 and not role then
		local p = P.Plates(g, now)
		Add("plates", h.left, p.foot, h.right, p.top, { label = "Unit frames", group = true })
		Add("plate", h.left, p.foot, 0, p.top, { color = "health" })
		Add("plate", 0, p.foot, h.right, p.top, { color = "bad" })
		Rect("small", p.focus, { color = "mana" })
		Rect("small", p.pet, { color = "health" })
		Rect("small", p.tot, { color = "bad" })
		Rect("party", p.party, { label = "Party", group = true })
		-- Four cells across the plates; or the healing grid's five, each its own size, centred over them.
		local grid = P.GridCell(now)
		local cells = grid and 5 or 4
		local cell = grid and grid[1] or (p.party[3] - p.party[1] - 3 * SEAM) / 4
		local left = grid and (p.party[1] + p.party[3]) / 2 - (cells * cell + (cells - 1) * SEAM) / 2 or p.party[1]
		local top = grid and p.party[2] + grid[2] or p.party[4]
		for i = 0, cells - 1 do
			local l = left + i * (cell + SEAM)
			Add("small", l, p.party[2], l + cell, top, { color = "health", faint = true })
		end
	end

	-- The pet bar: over the housing's right end, clear of the plates and what rises over them
	if not role then
		local petW = P.PET_BUTTONS * P.PET_SIZE + (P.PET_BUTTONS - 1) * P.PET_GAP
		local right, foot = g.width / 2 - P.PET_PAD, h.top + now.rise + P.PET_PAD
		Add("petbar", right - petW, foot, right, foot + P.PET_SIZE, { label = "Pet bar", cells = P.PET_BUTTONS, faint = true })
	end

	-- The cockpit (drawn by Picker.lua; here its labelled outlines)
	if c then
		for _, def in ipairs(P.COCKPIT) do
			Rect(def[3], c.rects[def[1]], { label = def[2], group = true, accent = def[4] })
		end
		-- Over it: the slot an extra ability comes up in (Layout.Over), and Request Stop on a flight. Each comes and goes.
		Rect("extra", ns.Layout.Over(c).button, { label = "Extra ability, Request Stop", faint = true })
	end

	-- The system column: the minimap, the buffs left of it, the rows under it, the guide and the objectives
	local mapLeft, mapRight = half - CORNER - now.map.width, half - CORNER
	local mapFoot, mapTop = H - CORNER - now.map.height, H - CORNER
	Add("map", mapLeft, mapFoot, mapRight, mapTop, { label = "Minimap" })
	local AURA, CELL, FOLD, GAP = P.AURA, P.CELL, P.FOLD, P.AURA_GAP
	local right, top = mapLeft - SEAM, H - CORNER
	Add("buffs", right - P.BUFFS * (AURA + GAP) - FOLD, top - CELL, right, top, { label = "Buffs", group = true })
	for i = 1, P.BUFFS do
		local r = right - FOLD - (i - 1) * (AURA + GAP)
		Add("buff", r - AURA, top - AURA, r, top)
	end
	Add("debuffs", right - FOLD - P.DEBUFFS * (AURA + GAP), top - 2 * CELL, right - FOLD, top - CELL, { label = "Debuffs", group = true })
	for i = 1, P.DEBUFFS do
		local r = right - FOLD - (i - 1) * (AURA + GAP)
		Add("debuff", r - AURA, top - CELL - AURA, r, top - CELL)
	end
	-- Under the map: the guide, then the rows under it (Arrange.lua hangs them there), then the objectives down to
	-- the console, stopping over the threat meter where that stands on the damage meter under them; with no guide
	-- docked, the rows hang under the map as the layout has them.
	local roof = P.ColumnClear(g, now, s.threat, P.ColumnFloor(g, now), mapLeft, mapRight)
	local docked = s.deck and s.arrange
	local deckFoot
	if docked then
		local y = mapFoot - SEAM
		deckFoot = max(roof, y - P.GUIDE)
		Add("guide", mapLeft, deckFoot, mapRight, y, { label = "Guide", group = true })
		Add("guide", mapLeft, deckFoot, mapRight, y)
	end
	local column = Console.Column(now, deckFoot, s.arrange and true or false)
	-- The menu's drawer: its pull, and (unless it is tucked: they slide down out of the pull) the rows under it.
	if column.pull then Rect("pull", column.pull, { label = "Menu", side = "top" }) end
	if not (column.pull and now.tucked) then
		Rect("tray", column.tray)
		Rect("menu", column.menu, { label = "Micro menu", cells = P.MENU_CELLS })
		Rect("bags", column.bags, { label = "Bags", cells = P.BAG_TILES, fromRight = true })
	end
	local y = column.foot - SEAM
	Add("column", mapLeft, roof, mapRight, y, { label = "Objectives", group = true })
	if y - 40 > roof then Add("objectives", mapLeft, max(roof, y - P.OBJECTIVES), mapRight, y) end

	-- A farming session (ShyFarm) in the top left's corner, where how to play stands (that goes under it while it
	-- shows: Arrange.lua); it comes and goes.
	if s.farm then
		local k = s.farm.scale or 1
		local l, t = -half + P.TOP_LEFT.x, H + P.TOP_LEFT.y
		Add("farm", l, t - s.farm.height * k, l + s.farm.width * k, t, { label = "Farming", piece = s.farm, faint = true })
	end

	-- The armor stand beside the column's head (P.Stand), drawn by its own picture; it comes and goes.
	if s.stand then
		local l, b, r, t = P.Stand(now, s.stand.width, s.stand.height)
		Add("stand", l, b, r, t, { label = "Armor stand", piece = s.stand, faint = true })
	end

	-- The raid frames in the top left corner, past the raid manager's folded tab, five to a row, the groups
	-- stacked (by role they stand where the role has them, above).
	local groupLeft = -half + CORNER + Console.RAID_TAB + SEAM
	local gy = H - CORNER
	if now.raiding and now.raid and not role then
		Add("raid", groupLeft, gy - P.RAID_ROWS * now.raid.h, groupLeft + Console.RAID_CELLS * now.raid.w, gy,
			{ label = "Raid frames", group = true })
		for row = 0, P.RAID_ROWS - 1 do
			for i = 0, Console.RAID_CELLS - 1 do
				local l, t = groupLeft + i * now.raid.w, gy - row * now.raid.h
				Add("small", l, t - now.raid.h, l + now.raid.w, t, { color = "health", faint = true })
			end
		end
	end

	-- The column down from the top's middle (Shy.Top's plan): the death recap's line, the way back to the
	-- graveyard, the waypoint arrow, the zone's name, each in its place.
	for _, piece in ipairs(s.top or {}) do
		Add("top", -piece.width / 2, H - piece.y - piece.height, piece.width / 2, H - piece.y, { piece = piece })
	end
	return list
end
