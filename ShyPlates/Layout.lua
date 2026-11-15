-- Every size and offset on a plate. Nameplate regions are restricted and can't be measured,
-- so layout uses these numbers alone. Slice and art sizes must match the files in Media.

local ADDON, ns = ...

local L = {}
ns.Layout = L

local MEDIA = ns.MEDIA

L.EDGE, L.EDGE_SLICE = MEDIA .. "Edge", 4            -- the housing's edge (Forged's; another look wears its buttons')
L.EDGE_MOST = 6      -- a look's edge's corners at most, on a housing HEALTH tall
L.SHADE, L.SHADE_SLICE, L.SHADE_REACH = MEDIA .. "Shade", 12, 7   -- the shadow a plate throws, drawn this far past it
L.GLYPHS = MEDIA .. "Glyphs"                          -- four across
L.GLYPH = { skull = 0, star = 1, shield = 2, wings = 3 }

L.HEALTH = 14        -- the housing, with nothing but health in it
L.INSET = 2          -- the edge: from the housing's outline to what it holds
L.NAME_GAP = 3       -- from the housing's top to the foot of the name
L.TEXT = 9           -- the number on the bar, and what the cast row and a tag say
L.TEXT_INSET = 3
L.RANK = 11          -- the glyph after the name: elite, rare, a boss
L.CELL_GAP = 2       -- a tag's compartment: the housing reaches on past the bar by the tag's width and this (its edge)
L.MARK = 20          -- the raid mark, right of everything
L.MARK_GAP = 3
L.AURA_W, L.AURA_H = 22, 16      -- what you put on it: wide, so a row of them stays low
L.AURA_GAP = 2
L.AURA_RISE = 4      -- from the top of the name to the foot of that row
L.CONTROL = 1.3      -- crowd control is this much larger
L.TITLE = 9          -- what an NPC does, under its name
L.TITLE_GAP = 1
-- A player's pet, totem or guardian as a name: this much smaller than a player's, never under `least` (where the
-- game draws their nameplates smaller itself, no smaller again: Units.Simplified).
L.PET = { step = 1, least = 9 }
L.EXECUTE = 0.2      -- health share of the execute line

-- Target mark: corner brackets (top-left art, mirrored) or a line (end, mirrored end, middle).
L.CORNER = { top = MEDIA .. "CornerTop", bottom = MEDIA .. "CornerBottom", size = 8, t = 2.5, gap = 1 }
L.LINE = { ending = MEDIA .. "LineEnd", mid = MEDIA .. "LineMid", w = 4, h = 3, inset = 2 }

-- Tag: another addon's icon and count, in a compartment of the housing at its right end (the housing runs on past the
-- bar to hold it, a seam between them).
-- One gap through it, TAG_GAP: the seam, a gap, the icon, a gap, the count, a gap, the housing's edge (CELL_GAP).
L.TAG = 15           -- icon alone: TAG_GAP, the icon (TAG - 2 * TAG_GAP), TAG_GAP
L.TAG_GAP = 2
L.TAG_DIGIT = 6      -- a digit's width at the count's size: read off the plate's own font by Plate:Arrange (text on a
                     -- plate can't be measured), this until it is; a count is as wide as its digits
L.COUNT_LIFT = 0.5   -- the count's rise: a digit's ink sits a little under its line's middle
L.SEAT = 14          -- the same mark beside a name-only plate
L.CREST, L.CREST_GAP = 15, 2   -- a PvP flag's crest before a player's name (its height), and the gap to the name
-- A rank's seal on a full plate (an elite, a rare, a rare elite, a boss): a ring SEAL across, its middle SEAL_AT from the
-- housing's left end (over the end, a little into the bar), holding the level; the rank's dragon curled round it
-- (Shy.UI.RankDragon). The name then has no level before it and no glyph after it: the seal says both.
-- Its rim wears the edge's color; its face, a dome of enamel under the rim, a deep shade of the level's color
-- (Theme.Deep at SEAL_DEEP), and the level stands on it in white.
L.SEAL, L.SEAL_AT, L.SEAL_TEXT = 20, -6, 9
L.SEAL_RIM, L.SEAL_FACE, L.SEAL_DEEP = MEDIA .. "Seal", MEDIA .. "SealFace", 90
L.SEAL_NUDGE = 1     -- the level stands this far right of the seal's middle: the game sets centred digits that far left of it
L.SEAT_GAP = 3

function L.TagWidth(count)
	if not count then return L.TAG end
	return L.TAG + L.TAG_DIGIT * #tostring(count) + L.TAG_GAP
end

-- Plaque: behind the name of a name-only plate whose tag is a lead, a housing of the look worn. Strip height =
-- name size + rise; ring = strip + round; gap ring to name; reach name to the strip's end;
-- face / art = icon size in the ring with / without a back texture; shadow = ring shadow overhang; usual = the plaque's
-- length for a name whose own can't be read (a secret one), for laying a look's face on it.
L.PLAQUE = { ring = MEDIA .. "Ring", shade = MEDIA .. "RingShade",
	rise = 7, round = 7, gap = 2, reach = 9, art = 15, face = 18, shadow = 6, usual = 110 }

-- Keel: the tray under the housing for combo points and the cast row. Top slice margin is small so it can be one row tall.
L.KEEL = { art = MEDIA .. "Stem", slice = 9, top = 2, width = 113, foot = 1 }

-- Combo points: five pips in the keel's top row.
L.COMBO = { pip = MEDIA .. "Pip", well = MEDIA .. "PipWell", light = MEDIA .. "PipGlow",
	count = 5, row = 10, w = 19, h = 7, gap = 2, top = 1.5, glow = 5 }

-- Cast row: the keel's bottom row; icon, then bar, each inset 2 top and bottom.
L.CAST = 13
L.CAST_ICON = 9

-- Housing bottom above the nameplate's bottom; the space below is for the keel.
L.LIFT = 20
L.NAME_LIFT = 14     -- a name-only plate sits lower: no housing under it

-- The room a plate keeps among other nameplates when the game stacks them (Plate:Berth): past its ends (side),
-- over the name or the row of debuffs and under the cast row (air), under a housing with no cast row (foot).
-- `wide` is how much wider than the plate that room is: the game lets stacked plates overlap sideways by a
-- share of their width, so the room is that much wider and plates meet at their true ends (Driver.lua reads it).
L.BERTH = { side = 4, air = 2, foot = 3, wide = 1, widest = 2 }

-- Fixed meaning colors; they don't follow the accent.
L.COLORS = {
	hostile  = { 0.87, 0.24, 0.22 },
	neutral  = { 0.93, 0.78, 0.25 },
	friendly = { 0.31, 0.78, 0.37 },
	tapped   = { 0.56, 0.56, 0.60 },   -- tagged by someone else
	-- Threat, in a group: a tank's bar runs from held down to lost as the lead over the next player shrinks;
	-- a damage dealer's or healer's the other way, from held while far from pulling to lost once it is on them.
	-- The family's own threat colors (Theme.THREAT), so the threat meter reads the same.
	held     = Shy.Theme.THREAT.held,
	slipping = Shy.Theme.THREAT.slipping,
	lost     = Shy.Theme.THREAT.lost,
	theirs   = Shy.Theme.THREAT.theirs,
	guild    = { 0.40, 0.88, 0.44 },   -- a player's guild, under their name: green, as guilds are in the game
	pet      = { 0.64, 0.82, 0.66 },   -- a friend's pet, as a name: the friend's green, softer than whoever it belongs to
	kin      = { 0.58, 0.63, 0.60 },   -- whose it is, under that name: quieter than the name it stands under
	silver   = { 0.86, 0.87, 0.90 },   -- round a rare
	name     = { 1.00, 1.00, 1.00 },
	unknown  = { 1.00, 0.30, 0.25 },   -- a level the game won't tell
}

function L.Fill(width)
	return width - 2 * L.INSET
end

-- The threat color at a margin from 0 (lost) through 0.5 (slipping) to 1 (held).
function L.ThreatColor(margin)
	return Shy.Theme.Threat(margin)
end

-- What your damage over time still has to deal (ShyDots), on the health bar: one segment a spell in its
-- school's color (up to DOOM_SEGS; the rest join the last), at DOOM_ALPHA over the fill, a DOOM_SEAM wide
-- dark line at each one's far end; and the check at the bar's start: its size (the bar's inner height, so
-- it sits on whole units), and the length of the bar it rides, shown only over its last DOOM units (the
-- check comes into view only when the damage reaches the health).
L.DOOM = L.HEALTH - 2 * L.INSET
L.DOOM_REACH = 2000
L.DOOM_SEGS = 4
L.DOOM_ALPHA = 0.7
L.DOOM_SEAM = 1

function L.GlyphCoords(name)
	local cell = L.GLYPH[name]
	return cell / 4, (cell + 1) / 4, 0, 1
end

-- Classes with a finisher usable below 20% health.
L.FINISHERS = { WARRIOR = true, PALADIN = true }
