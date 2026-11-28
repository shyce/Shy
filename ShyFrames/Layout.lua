-- The frame layouts as data, and the arithmetic that turns them into rectangles. Touches no frame.
-- A riser is a housing on a plate's top edge: plate-wide for combo points (L.COMBO), and as wide as its icons
-- for the buffs and debuffs ShyBuffs stands there (L.RISER).

local ADDON, ns = ...

local L = {}
ns.Layout = L

local MEDIA = "Interface\\AddOns\\ShyFrames\\Media\\"

-- (The bars' fill is the hatch of the theme's look: Shy.Skin.HatchBar and Shy.Skin.Hatch lay it and keep it current.)
L.NAME_FONT = MEDIA .. "BigNoodleTitling-Oblique.ttf"

L.SPACING = 1          -- between bars
L.TEXT_INSET = 4       -- a text from the end of its bar
L.TEXT_SPACING = 3     -- between a left text and the right text
L.MARK = 15            -- a mark's base size, before its own multiplier
L.MARK_SPACING = 3     -- between marks in a row

-- Nine slices with no bottom margin: a riser is open at the foot.
L.RISER_FILL, L.RISER_EDGE = MEDIA .. "RiserFill", MEDIA .. "RiserEdge"
L.RISER_SLICE = 8

-- The blade textures are drawn for 44.8 x 8, which these numbers give on a 248 wide plate.
L.COMBO = { count = 5, rise = 13, inset = 5, top = 3, height = 8, gap = 3.5, glow = 6 }
L.BLADE, L.BLADE_WELL, L.BLADE_GLOW = MEDIA .. "Blade", MEDIA .. "BladeWell", MEDIA .. "BladeGlow"

-- Icons on a plate's top edge: `size` square and `gap` apart, in `lines` rows at most (a raid boss's every
-- debuff), in a housing of the look's mini make that hugs them: `foot` between them and the edge, `pad` over them
-- (the housing's own room and its line reaching outward), the first `ends` in from the plate's end. A party
-- member's cell has one row of `cell`. Nothing ever stands past that room.
L.RISER = { size = 20, lines = 2, cell = 20, gap = 2, pad = 6, foot = 2, ends = 8 }

-- How far that housing rises over the edge: `lines` rows of icons of `size` (a plate's by default).
function L.Rise(size, lines)
	local riser = L.RISER
	size, lines = size or riser.size, lines or riser.lines
	return lines * size + (lines - 1) * riser.gap + riser.pad + riser.foot
end

-- Whether the icons on your target's plate stand on its combo points' housing: a class that builds them.
function L.Stacked(class)
	return class == "ROGUE" or class == "DRUID"
end

-- Height of what rises above a plate's top edge: combo points, and the icons when something stands them there
-- (on the combo points' housing, for a class that builds them).
function L.Overhang(icons, class)
	local combo = L.COMBO.rise
	if not icons then return combo end
	if L.Stacked(class) then return combo + L.Rise() end
	return math.max(combo, L.Rise())
end

-- Room for the panel's edge round the bars, where a plate can't say better (Plate:Pad: the look's own border and a
-- gap of whole screen pixels, `L.GAP` units rounded, the same on every side).
local PAD = { top = 3, side = 3, bottom = 3 }
L.GAP = 1

L.LAYOUTS = {
	-- Player and target.
	main = {
		width = 248, height = 51,
		fades = true,
		portrait = true,
		nameLimit = 18,   -- letters before a long name is abbreviated
		bars = {
			{ id = "health", size = 28 },
			{ id = "power", size = 14 },
			{ id = "druid", size = 4 },   -- a druid's mana while shapeshifted, player frame only
		},
		texts = {
			name = { on = "health", font = "name", size = 18 },
			health = { on = "health", font = "value", size = 12 },
			class = { on = "power", font = "value", size = 11 },
			power = { on = "power", font = "value", size = 11 },
			druid = { on = "power", font = "value", size = 10 },
		},
		-- Marks on the frame's edges: location, order within it, size.
		marks = {
			{ id = "raidTarget", location = "edge_top_right", position = 3, size = 1.3, stand = 1 },
			{ id = "leader", location = "edge_top_left", position = 29, size = 0.75 },
			{ id = "masterLooter", location = "edge_top_left", position = 33, size = 0.75 },
			{ id = "readyCheck", location = "edge_bottom_right", position = 5, size = 1 },
			{ id = "voice", location = "edge_top_right", position = 28, size = 1 },
		},
	},
	-- A party member: one cell of the row over your plate and your target's. Its width comes from L.FitSquad.
	squad = {
		width = 121, height = 36,
		pad = { top = 3, side = 3, bottom = 3 },
		portrait = true,
		nameLimit = 10,
		first = true,        -- first name only
		short = true,        -- health says what is missing and no more
		role = true,         -- the role leads the name
		powerLine = true,    -- power is a line in its kind's color, with no text
		signals = true,      -- reach, an enemy on them, your target
		bars = {
			{ id = "health", size = 24 },
			{ id = "power", size = 5 },
		},
		texts = {
			name = { on = "health", font = "name", size = 15 },
			health = { on = "health", font = "value", size = 11 },
		},
		-- Buffs and debuffs stand on the top edge, so marks keep to the bottom one.
		marks = {
			{ id = "raidTarget", location = "edge_bottom", position = 3, size = 1 },
			{ id = "voice", location = "edge_bottom", position = 28, size = 0.9 },
			{ id = "masterLooter", location = "edge_bottom_left", position = 33, size = 0.75 },
			{ id = "readyCheck", location = "edge_bottom_right", position = 5, size = 1 },
		},
	},
	-- A cell of the healing grid: the party and you, side by side and no wider than they need to be, so a heal is
	-- never far from the last one. The name and what is missing share the top line; the foot of the health bar is
	-- kept for what ShyBuffs marks there (L.GRID): your own heals in their seats, and a debuff.
	-- A name is its first five letters: what fits beside "-3200" whole, in the game's own letter widths (seven let
	-- "Borin" be cut to "Bo..." by the number beside it). A name cut at a letter reads as a name; one cut by three
	-- dots reads as broken.
	grid = {
		width = 88, height = 50,
		pad = { top = 3, side = 3, bottom = 3 },
		nameLimit = 5,
		first = true,
		short = true,
		role = true,
		roles = {},          -- nobody wears the role's picture: a tank is told by the first seat, and a name needs its room
		powerLine = true,
		signals = true,
		lift = 10,           -- the texts stand this far over the health bar's middle
		smooth = true,       -- health glides to its new value: a hit is seen arriving, not only landed
		bars = {
			{ id = "health", size = 39 },
			{ id = "power", size = 4 },
		},
		texts = {
			name = { on = "health", font = "name", size = 14 },
			health = { on = "health", font = "value", size = 10 },
		},
		marks = {
			{ id = "raidTarget", location = "edge_bottom", position = 3, size = 1 },
			{ id = "voice", location = "edge_bottom", position = 28, size = 0.9 },
			{ id = "masterLooter", location = "edge_bottom_left", position = 33, size = 0.75 },
			{ id = "readyCheck", location = "edge_bottom_right", position = 5, size = 1 },
		},
	},
	-- A party member's pet: a bar at the end of its owner's cell.
	sliver = { width = 9, height = 24, gap = 1 },
	-- Pet, focus.
	small = {
		width = 135, height = 40,
		portrait = true,
		nameLimit = 12,
		bars = {
			{ id = "health", size = 20 },
			{ id = "power", size = 11 },
		},
		texts = {
			name = { on = "health", font = "name", size = 15 },
			health = { on = "health", font = "value", size = 11 },
			power = { on = "power", font = "value", size = 10 },
		},
		marks = {},
	},
	-- Target's target: health alone, as small as the game's, saying only what is missing. Its picture stands at its
	-- right end, as your target's does: it mirrors the focus frame across your plates.
	tot = {
		width = 120, height = 30,
		portrait = true,
		nameLimit = 10,
		first = true,
		short = true,
		bars = {
			{ id = "health", size = 22 },
		},
		texts = {
			name = { on = "health", font = "name", size = 15 },
			health = { on = "health", font = "value", size = 11 },
		},
		marks = {},
	},
}

-- A portrait at one end of the frame, `seam` from the bars: set into the frame, a square as tall as the bars' room;
-- or like the game's, a circle as tall as the frame at its very end, as the game's frames of old stood theirs.
L.COLUMN = { seam = 2 }
-- The round portrait's dial (Media\PortraitFace<circle>, PortraitRing<circle>): the circles it is drawn for, the
-- room round each for its shadow, a dark line's half width, the steel's width (or that share of the circle when
-- more). Its picture reaches the middle of the ring's inner line.
-- Like the game's frames of old, the housing is shorter than the circle and runs in behind it, on the circle's
-- middle: its top and its foot each `inset` of the circle in from the frame's (the old frames' bars stood 70% as tall
-- as their portrait), its end at the circle's middle (`house`). Each bar
-- starts where the ring's edge crosses its row farthest from the circle's middle, `tuck` under it, so the ring lies
-- over its end with no gap and its fill grows out from the curve. A bar's words keep `clear` past the ring.
L.RING = { circles = { 28, 32, 36, 40, 45, 51, 58, 66, 75, 85 }, pad = 4, half = 0.41, band = 2.54, share = 0.075,
	inset = 0.15, house = 0.5, tuck = 1, clear = 2, media = "Interface\\AddOns\\ShyFrames\\Media\\" }

-- The circle drawn nearest `across` (by ratio), and the radii of its ring's lines at that size: the picture's edge
-- (the inner line's middle) and the ring's outer edge.
function L.Ring(across)
	local best, off = nil, math.huge
	for _, circle in ipairs(L.RING.circles) do
		local d = math.abs(math.log(across / circle))
		if d < off then best, off = circle, d end
	end
	local k = across / best
	local out = best / 2 - L.RING.half
	local inner = out - math.max(L.RING.band, L.RING.share * best)
	return best, inner * k, (out + L.RING.half) * k
end
-- Which setting (Portrait.lua) a kind's column follows, and the kinds whose column stands at the right end.
L.PORTRAITS = { player = "pair", target = "pair", pet = "small", focus = "small", targettarget = "small", party = "party" }
L.MIRRORED = { target = true, targettarget = true }

-- How tall your frame and your target's are (T.db.height): as the console was cut for, or as tall as the game's own
-- (its portrait is 60 across). The console plans round whichever (T:Sizes); set out of combat only (Place.Apply).
L.HEIGHTS = { compact = 51, game = 64 }

function L.MainHeight(pick)
	L.LAYOUTS.main.height = L.HEIGHTS[pick] or L.HEIGHTS.game
end

-- Which layout a unit uses, and a width multiplier.
L.UNITS = {
	player = { layout = "main" },
	target = { layout = "main" },
	party = { layout = "squad" },
	targettarget = { layout = "tot" },
	pet = { layout = "small", widthMult = 1.3 },
	focus = { layout = "small", widthMult = 1.3 },
	partypet = { layout = "sliver" },
}

function L.Of(unitKind)
	return L.LAYOUTS[L.UNITS[unitKind].layout]
end

function L.Size(unitKind)
	local def = L.UNITS[unitKind]
	local layout = L.LAYOUTS[def.layout]
	return layout.width * (def.widthMult or 1), layout.height
end

-- Four cells `gap` apart span `width`: the player's plate, the target's and what lies between them.
function L.FitSquad(width, gap)
	L.LAYOUTS.squad.width = (width - 3 * gap) / 4
end

-- What stands in the foot of a grid cell's health bar, from the bar's own corners: `seats` marks of `mark`
-- from its left, `gap` apart (your own heals, a hair `hair` high under each for the time left), and one debuff
-- of `harm` at its right; all `foot` over the bar's bottom edge and `ends` in from its ends.
L.GRID = { seats = 4, mark = 12, gap = 1, hair = 2, harm = 16, foot = 3, ends = 2 }

-- A party cell as it is made, by its layout: the row's and the column's (its width is the span's or its place's:
-- L.FitSquad, Place.lua) and the healing grid's. And the least and the most the player may make one (Place.lua):
-- a first name and what is missing fit the least, the grid's marks its height.
L.CELL = { squad = { 121, 36 }, grid = { 88, 50 } }
L.CELL_LEAST = { squad = { 70, 28 }, grid = { 64, 42 } }
L.CELL_MOST = { 320, 90 }

-- The party's cells at `width` and `height` (nil: the width as it stands, the height they are made at). A pet's
-- bar is as tall as its owner's health bar, whatever the cell's height.
function L.Cell(width, height)
	local name = L.UNITS.party.layout
	local layout = L.LAYOUTS[name]
	layout.width, layout.height = width or layout.width, height or L.CELL[name][2]
	local room = layout.height - layout.pad.top - layout.pad.bottom - L.SPACING * (#layout.bars - 1)
	local points = 0
	for _, bar in ipairs(layout.bars) do points = points + bar.size end
	L.LAYOUTS.sliver.height = layout.bars[1].size * room / points
end

-- The party's cells are the healing grid's (true) or the row's over your plates.
function L.Party(grid)
	L.UNITS.party.layout = grid and "grid" or "squad"
	L.Cell()
end

-- Room for the panel's edge round a layout's bars (`pad`: a plate's own, Plate:Pad).
function L.Pad(layout, pad)
	return pad or layout.pad or PAD
end

-- The side of the square a layout's portrait set into the frame is: as tall as its bars' room. 0 for a layout with
-- none.
function L.Column(layout, pad)
	if not layout.portrait then return 0 end
	pad = L.Pad(layout, pad)
	return layout.height - pad.top - pad.bottom
end

-- Where a layout's portrait stands, and what it takes from the bars: its box's side; how far in its box starts from
-- the frame's end and down from its top; the width the bars give up (set into the frame); how far the housing stands
-- in from the frame's top and foot; how far in from the frame's end the housing starts; and the ring's radius
-- (round: the bars start on its curve, L.Bars). Round (`ringed`): the circle as tall as the frame, at its very end,
-- the housing shorter, behind it and on its middle (L.RING). All 0 for a layout with none.
function L.Portrait(layout, ringed, pad)
	if not layout.portrait then return 0, 0, 0, 0, 0, 0, 0 end
	pad = L.Pad(layout, pad)
	if ringed then
		local side, ring = layout.height, L.RING
		return side, 0, 0, 0, math.floor(side * ring.inset + 0.5), side * ring.house, side / 2
	end
	local side = L.Column(layout, pad)
	return side, pad.side, pad.top, side + L.COLUMN.seam, 0, 0, 0
end

-- Where a bar from `top` to `bottom` starts beside a ring of radius `r` standing at the frame's end, its top on the
-- frame's: on the ring's edge at the bar's row farthest from the ring's middle, tucked under it. And how far in from
-- that its words keep, past the ring.
function L.OnCurve(r, top, bottom, side)
	local dy = math.max(math.abs(top - r), math.abs(bottom - r))
	local edge = dy < r and r + math.sqrt(r * r - dy * dy) or side
	local left = math.max(side, edge - L.RING.tuck)
	return left, math.max(0, 2 * r + L.RING.clear - left)
end

-- The bars in `present` (by id) share the height in proportion to their `size`.
-- `trim` is taken off the health bar's right end (a pet's bar stands there).
-- `give` (a portrait's room) is taken off every bar's width, at the left end, or at the right end when `mirrored`;
-- `inset` off the top and the bottom of their room (the housing stood in). With `ring` (a round portrait's radius) each bar
-- instead starts on the ring's curve (L.OnCurve), and says how far its words keep in (`clear`).
--   -> { [id] = { left, top, width, height, clear = n } }, from the frame's top left, y downward
function L.Bars(layout, width, present, trim, give, mirrored, inset, ring, pad)
	pad = L.Pad(layout, pad)
	give = give or 0
	local start = mirrored and 0 or give
	local shown, points = {}, 0
	for _, bar in ipairs(layout.bars) do
		if present[bar.id] then
			shown[#shown + 1] = bar
			points = points + bar.size
		end
	end
	inset = inset or 0
	local room = layout.height - 2 * inset - pad.top - pad.bottom - L.SPACING * (#shown - 1)
	local perPoint = room / points
	local rects, y = {}, inset + pad.top
	for _, bar in ipairs(shown) do
		local height = bar.size * perPoint
		if ring and ring > 0 then
			local into, clear = L.OnCurve(ring, y, y + height, pad.side)
			rects[bar.id] = { mirrored and pad.side or into, y, width - pad.side - into, height, clear = clear }
		else
			rects[bar.id] = { pad.side + start, y, width - pad.side * 2 - give, height, clear = 0 }
		end
		y = y + height + L.SPACING
	end
	if trim and rects.health then rects.health[3] = rects.health[3] - trim end
	return rects
end

-- A mark's size counts twice on purpose: a row starts a little left of center.
local function HalfWidth(row)
	local total = 0
	for _, item in ipairs(row) do
		total = total + item.size * item.size * L.MARK * item.aspect
	end
	return (total + (#row - 1) * L.MARK_SPACING) / 2
end

local MIDDLE = { edge_top = true, edge_bottom = true }

-- Marks on the edges: one alone is centered on its corner (or the middle of an edge), several run in a row from there.
-- `present[id]` = aspect (width/height) of each shown mark; `heights[id]` overrides a height;
-- `stand` sets a mark on the edge, that far into the frame; `lift[id]` raises it.
--   -> { [id] = { centerX, centerY, width, height } }, from the frame's top left, y downward
function L.Marks(layout, width, present, heights, lift)
	local rows = {}
	for _, def in ipairs(layout.marks) do
		local aspect = present[def.id]
		if aspect then
			local size = heights and heights[def.id] and heights[def.id] / L.MARK or def.size
			rows[def.location] = rows[def.location] or {}
			table.insert(rows[def.location], { id = def.id, size = size, position = def.position, aspect = aspect, stand = def.stand })
		end
	end
	local corner = {
		edge_top = { width / 2, 0 }, edge_top_left = { 0, 0 }, edge_top_right = { width, 0 },
		edge_bottom = { width / 2, layout.height }, edge_bottom_left = { 0, layout.height },
		edge_bottom_right = { width, layout.height },
	}
	local out = {}
	for location, row in pairs(rows) do
		table.sort(row, function(a, b) return a.position < b.position end)
		local at = corner[location]
		local x
		for i, item in ipairs(row) do
			local h = L.MARK * item.size
			local w = h * item.aspect
			if i == 1 then
				if #row == 1 or not MIDDLE[location] then
					x = at[1] - w / 2              -- centered on the corner
				else
					x = at[1] - HalfWidth(row)     -- a row on an edge's middle is centered as a whole
				end
			end
			local y = item.stand and at[2] - h / 2 + item.stand or at[2]
			out[item.id] = { x + w / 2, y - (lift and lift[item.id] or 0), w, h }
			x = x + w + L.MARK_SPACING
		end
	end
	return out
end
