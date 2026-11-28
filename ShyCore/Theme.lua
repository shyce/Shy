-- Shy.Theme: the accent color (class color or a picked hue), the palettes derived from it, and panel opacity.
--
--   Theme.Accent()               -> r, g, b
--   Theme.AccentSolid()          -> r, g, b (same color, not drawn in the ramp)
--   Theme.Set(mode, hue)         -- "class", or "hue" with 0-360; saved and applied at once
--   Theme.Mode()                 -> mode, hue as saved
--   Theme.HueColor(hue)          -> r, g, b of a picked hue
--   Theme.Ramp(u)                -> r, g, b: deep shade (0), accent (0.5), light (1)
--   Theme.Combo(i, count)        -> r, g, b: i-th of count combo points, gold to crimson
--   Theme.Threat(margin)         -> r, g, b: threat held (1) through slipping (0.5) to lost (0); Theme.THREAT
--   Theme.Harm(kind)             -> r, g, b by debuff type ("Poison", "Curse", ...; red without one)
--   Theme.School(mask)           -> r, g, b by damage school mask (1 physical, 4 fire, ...)
--   Theme.Power(kind)            -> r, g, b by Enum.PowerType (0 mana, 1 rage, 3 energy)
--   Theme.Hex(color)             -> "rrggbb", for |cff escapes
--   Theme.Wrap(color, text)      -> the text in that color
--   Theme.Lc(r, g, b, r2, g2, b2) -> APCA lightness contrast of words (r, g, b) on (r2, g2, b2): about -108
--                                   to 106; |Lc| wants Theme.LC_BODY (75) for text, LC_LABEL (60) for labels
--   Theme.InkOn(r, g, b, lc)     -> r, g, b: the ink that reads on that color by APCA (a near-black of its hue
--                                   or a near-white of it, pushed to pure as far as `lc` needs)
--   Theme.OnColor(r, g, b)       -> Theme.InkOn at LC_LABEL
--   Theme.FaceFor(r, g, b, lc)   -> r, g, b: the color as a face for words: itself while an ink reads on it at
--                                   `lc` (LC_LABEL), else lighter or darker just far enough, its hue kept
--   Theme.Deep(r, g, b, lc)      -> r, g, b: the color as the ground white words stand on: itself while white
--                                   reads on it at `lc` (LC_BODY), else a deeper shade of it (a white's silver,
--                                   a yellow's gold)
--   Theme.Veil(r, g, b, ir, ig, ib, lc) -> 0 to 1: how much of an ink laid over the color white words need to
--                                   read on it at `lc` (LC_BODY); 0 where they read already
--   Theme.AccentHolds()          -> whether words read on the accent itself (UI.colors.face is the accent)
--   Theme.Readable(r, g, b, sr, sg, sb, lc, ir, ig, ib) -> r, g, b: the color, drawn toward the surface's ink
--                                   (or toward `ir, ig, ib`, an ink already chosen for it) just far enough to
--                                   read at `lc`
--   Theme.Quiet(r, g, b, sr, sg, sb, least) -> r, g, b: the color a tad quieter on the surface: Theme.QUIET.keep of
--                                   its contrast (never under `least`), by lightness, its chroma held and eased
--   Theme.Vivid(r, g, b, sr, sg, sb, lc) -> r, g, b: the color kept a color where it must read at `lc` on the
--                                   surface: its hue made vivid, its lightness moved just far enough (a lit word
--                                   among white words; Theme.Readable would wash it to a near-white)
--   Theme.Chroma(r, g, b)        -> 0 to 1: how much color it carries (a pale tint little, unlike HSL saturation)
--   Theme.Contrast(r, g, b, r2, g2, b2) -> 1 to 21: the WCAG 2.x ratio (text wants 4.5)
--   Theme.Legible(r, g, b, sr, sg, sb, ratio) -> r, g, b: the color, drawn toward the surface's ink just
--                                   far enough to stand `ratio` apart from it
--
-- Color tables change in place when the accent changes: keep the table, never copy its numbers.
--   Theme.ui     (Shy.UI.colors)     bg, bgHot, panel, row, rowEdge, fill, border, hot, text, dim, head, alert, onAlert,
--                                    quiet and quietAlert (the text and the gold a tad quieter on the panel, Theme.Quiet),
--                                    onAccent (the ink on a face in the accent), face and onFace (the accent
--                                    held where words read on it, Theme.FaceFor, and their ink), onFill (the ink on the fill:
--                                    a primary button's words, a checked box's mark), pick (a picked row) with
--                                    onPick and onPickDim (its text and quiet text, lifted to read), good, bad
--   Theme.skin   (Shy.Skin.colors)   metal, lit, inset, glyph, hover, on, panel, well, idle, strip, edge, text
--   Theme.light, Theme.icon          near-white highlight; the tint for addon icons
--
-- A region colored through these follows the theme:
--   Theme.Paint(texture, color, alpha)     -- SetColorTexture
--   Theme.Tint(texture, color, alpha)      -- SetVertexColor
--   Theme.Ink(fontString, color, alpha)    -- SetTextColor
--   Theme.Scope(frame, r, g, b)            -- the frame's regions take the palette of that color instead (nil: the
--                                          -- theme's again); Theme.Scoped(frame) -> its r, g, b, or nil
-- color: a table above (by reference), any { r, g, b, a }, a function returning r, g, b, or plain numbers.
-- A later direct SetVertexColor/SetTextColor is detected and wins; a direct SetColorTexture can't be.
-- Art tinted in the accent while a ramp is worn takes it as a gradient across itself; art whose alpha an
-- animation runs (a breathing glow) shows that gradient as white, so mark it `texture.shyFlat = true` before
-- tinting it and it takes one color instead, the ramp's where it stands.
--
--   Theme.Icon(texture, path[, units])  -- shows <path>Mono tinted with the accent; an addon's mark (a.mark) from
--                                the size of it drawn for where it stands, a texel a pixel (units: the texture's
--                                size where it fills a frame; none: its own, set to the art's). Theme.Plain(texture)
--                                before such a texture shows anything else
--   Theme.MarkArt(path, units)   -- a mark as a menu row's picture
--   Theme.IconMarkup(path, size) -- the same as an inline |T...|t
--
-- Opacity: one setting for everything that stays on screen during play (HUD boxes, the console, chat,
-- the tracker, tooltips). Windows stay solid (`panel`).
--   Theme.Strength()             -> 0 to 1
--   Theme.SetStrength(percent)   -- 0 to 100; saved and applied at once
--   Theme.StrengthSoon(percent)  -- the same from a slider: applied once it rests (as Theme.SetSoon)
--   ui.hud, ui.hudStrip          -- fill and title strip at that opacity (the strip slightly stronger);
--                                -- skin.hudMetal is their edge. UI.Panel and kit:Plate take `hud = true`.
--   Theme.TipStrength()          -> Theme.OVER to 1: tooltips and hovers carry text over text, so stay darker
--   ui.tip                       -- panel color at that opacity
--
-- The look: the make every housing on screen wears (UI.Panel and kit:Plate dress it; UI.lua's "The looks").
--   Theme.LOOKS                  -- "forged", "steel", "clear", "eclipse", "stitched", "riveted", in the order offered
--   Theme.Look()                 -> the look in use ("forged" unless another is saved)
--   Theme.LookChosen()           -> the look as saved, or nil when none was ever picked
--   Theme.SetLook(look)          -- saved and applied at once
--   Theme.AddLook(look, options) -- a look of its own file (UI.LookKind): offered after these, its options kept
-- A look's options (UI.LookKind's `options`: { key, label, kind = "choice" | "switch" | "slider", choices | min, max,
-- step, default, desc }), saved per look in db.theme.looks; changing one dresses every housing again, live.
--   Theme.LookOptions(look)      -> its option list ({} for none)
--   Theme.LookOption(look, key)  -> the value worn (its default unless one was set)
--   Theme.SetLookOption(look, key, value)   -- saved and applied at once; nil: back to the default
--   Theme.LookStamp()            -> a number that changes whenever a look option does (housings dressed under an
--                                -- older stamp are dressed again)
--
-- Presets: a whole theme at once, its look, accent, bars' fill, slots' finish and health's color picked to go
-- together (the setup's theme section and the hub offer them). Nothing of a preset is kept but its parts: the
-- preset worn is the one whose parts are all worn now, else "own".
--   Theme.PRESETS                -- { key, name, desc, look, accent, bar, slot, health, gradient, options, house }; accent a
--                                -- Theme.Picks() value, bar a Skin.BARS key, slot a Slot.STYLES key ("auto": the look's
--                                -- own), gradient a Theme.GRADIENTS key (with accent "gradient"), nil for one color;
--                                -- options its look's options (the rest at their defaults); house the family's
--                                -- own, named by Shy.Brand
--   Theme.PresetPicks()          -> the dropdown's items: every preset, then "Your own"
--   Theme.PresetWorn(parts)      -> the key of the preset `parts` (or what is worn now) matches, or "own"
--   Theme.PresetParts(key)       -> a copy of that preset's parts, nil for none
--   Theme.SetPreset(key)         -- puts every part on at once
--
-- The gradient: the accent as a ramp of colors instead of one ("The gradient" below).
--   Theme.Grad                   -- the ramp's model: Clean, Sample, Bends, Breaks, Add, Move, Remove, Reverse, Key
--   Theme.GRADIENTS              -- { key, name, desc, stops, spread }: the ramps offered, Rainbow Road first
--   Theme.Gradient()             -> the ramp in use (a copy), or nil for one color
--   Theme.GradientPick()         -> the GRADIENTS key the ramp in use is, "own", or nil for one color
--   Theme.GradientKey(g)         -> the same for any ramp
--   Theme.SolidPick()            -> the one color picked under any ramp (Theme.Pick says "gradient" while one is worn)
--   Theme.SetGradient(g)         -- saved and applied at once; nil: one color again
--   Theme.SetGradientSoon(g)     -- the same from a drag: applied once it rests (as Theme.SetSoon)
--   Theme.SetGradientPick(key)   -- a GRADIENTS key, "kept" (the last ramp worn), or nil for one color
--   Theme.Stops()                -> the ramp in use, one color being a ramp of one stop
--   Theme.At(u)                  -> r, g, b of the ramp in use at u (0 to 1)
--
-- The font: the lettering of Shy's own words (titles, headers, tabs, buttons, labels), a part of the theme ("The
-- font" below). Names and numbers and running text (chat) keep their readable faces.
--   Theme.FONTS                  -- { key, name, desc, file, russian, least, pair }: the fonts offered, Lilita One
--                                -- (Theme.FONT) first; under `least` units a face cramps and its `pair` (the
--                                -- default unless named) sets the words instead
--   Theme.Font()                 -> the key worn; Theme.FontShown() -> the one on screen (a preview's, else that)
--   Theme.FontFiles(key, size)   -> { roman, russian }, key: the files by alphabet of the face words of that size are
--                                -- set in (nil key: the font on screen; nil size: the font itself)
--   Theme.SetFont(key)           -- saved and applied at once: every string set through Theme.Face changes font
--   Theme.PreviewFont(key)       -- everything on screen in `key` for now, nothing saved; nil: the worn one again
--   Theme.Face(fs, size, flags, key)  -- UI.TitleFace: sets Shy's own words in the theme's font and keeps them in
--                                -- it (keeping the string's alignment, color and shadow); with `key`, that font for good
--   Theme.Follow(fs)             -- a string given UI.TitleFont's object another way follows the font from now on
-- A preset's `font` is a Theme.FONTS key; none means Theme.FONT.
--
-- The text effect: what Shy's own words wear to stand off their ground ("The text effect" below).
--   Theme.TEXTS                  -- { key, name, desc }: "plain", "shadow" (Theme.TEXT, the default), "outline"
--   Theme.TextEffect()           -> the effect on screen (a preview's, the one picked, the look's own, or a shadow)
--   Theme.TextChosen()           -> the one picked, or nil (the look's own: UI.LookKind's `text`)
--   Theme.SetTextEffect(key)     -- saved and worn at once; nil: the look's own
--   Theme.PreviewTextEffect(key) -- worn for now, nothing saved; nil: the one worn again
--   Theme.TextStrength()         -> 0 to 1, how deep a shadow is (1 to 2 units); Theme.SetTextStrength(v)
--   Theme.Letter(fs, opts)       -- UI.Letter: a string of Shy's own not set through Theme.Face wears it too;
--                                -- opts.least (an effect worn at the least), opts.ground (the color it stands on:
--                                -- its ink the readable one on it); false lets either go
--   Theme.HoldPlain(fs, on)     -- plain words whatever the effect, while on (found words on badges); false: a
--                                -- string that wears no effect
--   Theme.Centre(fs, to, x, y), Theme.Lead(fs), Theme.Run(fs)  -- words on a point, or beginning where plain ones do,
--                                -- whatever they wear ("Where letters stand")
-- A preset's `text` is a Theme.TEXTS key (none: the look's own) and `textStrength` 0 to 1 (none: 0).
--
-- "SHY_THEME" fires on every change of accent, opacity, look, gradient or font; "SHY_FONT" (key) after the words
-- on screen changed font (a preview's too): re-measure anything sized to its text.

local Shy = Shy
local core = Shy.core
local Theme = {}
Shy.Theme = Theme

local abs, floor, max, min = math.abs, math.floor, math.max, math.min
local format = string.format

Theme.SAPPHIRE = 212   -- the original hue; TOC titles and AddOns-list icons use it

-- Color maths

local function ToHSL(r, g, b)
	local hi, lo = max(r, g, b), min(r, g, b)
	local l, d = (hi + lo) / 2, hi - lo
	if d < 0.0001 then return 0, 0, l end
	local s = d / (1 - abs(2 * l - 1))
	local h
	if hi == r then h = ((g - b) / d) % 6
	elseif hi == g then h = (b - r) / d + 2
	else h = (r - g) / d + 4 end
	return h * 60, min(1, s), l
end

local function FromHSL(h, s, l)
	s, l = max(0, min(1, s)), max(0, min(1, l))
	local c = (1 - abs(2 * l - 1)) * s
	local hp = (h % 360) / 60
	local x = c * (1 - abs(hp % 2 - 1))
	local m = l - c / 2
	local r, g, b = 0, 0, 0
	if hp < 1 then r, g = c, x
	elseif hp < 2 then r, g = x, c
	elseif hp < 3 then g, b = c, x
	elseif hp < 4 then g, b = x, c
	elseif hp < 5 then r, b = x, c
	else r, b = c, x end
	return r + m, g + m, b + m
end
Theme.FromHSL, Theme.ToHSL = FromHSL, ToHSL

-- A piece's state shown in its own colors rather than a light laid over it (a light washes the art under it out):
-- the color `k` (0 to 1: the mouse over it part way, your target all the way) more saturated and a little lighter,
-- SAT of the way to full saturation and LIGHT of the way to white. A grey only lightens: it has no hue to make more
-- of (a cool grey would come out blue), so the saturation comes in from GREY, whole by HUED.
Theme.LIFT = { SAT = 0.5, LIGHT = 0.16, GREY = 0.08, HUED = 0.16 }
function Theme.Lift(r, g, b, k)
	if not k or k <= 0 then return r, g, b end
	local LIFT = Theme.LIFT
	local h, s, l = ToHSL(r, g, b)
	local hued = max(0, min(1, (s - LIFT.GREY) / (LIFT.HUED - LIFT.GREY)))
	return FromHSL(h, s + (1 - s) * LIFT.SAT * k * hued, l + (1 - l) * LIFT.LIGHT * k)
end

-- Signed shortest turn from one hue to another.
local function Turn(from, to)
	return (to - from + 540) % 360 - 180
end

-- How far a color's lighter shades lean: toward yellow or cyan, whichever is nearer; a grey has no hue.
local function Lean(h, s)
	if s < 0.08 then return 0 end
	local toYellow, toCyan = Turn(h, 60), Turn(h, 180)
	local nearest = abs(toYellow) < abs(toCyan) and toYellow or toCyan
	return max(-10, min(10, nearest))
end

-- A color's light, as the accent's is (the palette's `hot`): what the head's circle and its arrow are lit in.
function Theme.Hot(r, g, b)
	local h, s, l = ToHSL(r, g, b)
	local hotL = max(l, 0.66)
	return FromHSL(h + Lean(h, s), s, hotL + (1 - hotL) * 0.25)
end

-- Words on a color: APCA, the Accessible Perceptual Contrast Algorithm (APCA-W3 0.0.98G-4g, the contrast
-- of the WCAG 3 draft). It reads two colors as a lightness contrast, Lc, from about -108 to 106: positive
-- for dark words on a light color, negative for light words on a dark one. Unlike the 2.x ratio below it
-- weighs the two the way the eye does: light words on a mid tone (white on a mid blue, on an orange) are
-- judged as they read, and dark colors near black aren't overrated. Its levels, by what the words are:
Theme.LC_BODY  = 75   -- running text: the least for it
Theme.LC_LABEL = 60   -- labels, buttons, other short words
Theme.LC_LARGE = 45   -- large or heavy words (a title)
Theme.LC_MARK  = 30   -- a mark that isn't words (a glyph, a divider)

-- A color's screen luminance for APCA (its own simple 2.4 power), soft-clamped near black, where the eye
-- tells little apart.
local function ScreenY(r, g, b)
	r, g, b = max(0, min(1, r)), max(0, min(1, g)), max(0, min(1, b))
	local y = 0.2126729 * r ^ 2.4 + 0.7151522 * g ^ 2.4 + 0.0721750 * b ^ 2.4
	if y < 0.022 then y = y + (0.022 - y) ^ 1.414 end
	return y
end

-- Lc of words in (tr, tg, tb) on (br, bg, bb).
function Theme.Lc(tr, tg, tb, br, bg, bb)
	local words, back = ScreenY(tr, tg, tb), ScreenY(br, bg, bb)
	if abs(back - words) < 0.0005 then return 0 end
	if back > words then
		local c = (back ^ 0.56 - words ^ 0.57) * 1.14
		return c < 0.1 and 0 or (c - 0.027) * 100
	end
	local c = (back ^ 0.65 - words ^ 0.62) * 1.14
	return c > -0.1 and 0 or (c + 0.027) * 100
end

-- The ink for words on a color. Of a light ink and a dark one, each a neutral of the color's own hue (it
-- sits with the color better than plain white or black), the one APCA reads better; then, should even that
-- fall short of `lc` (Theme.LC_LABEL unless told), drawn on toward pure white or black just far enough.
-- So a yellow, a cyan or a priest's white take the dark ink, a blue, a brown or an orange the light.
local INK_DEEP = 0.14     -- the dark ink: this much of the color
local INK_PALE = 0.88     -- the light ink: this far from the color toward white

function Theme.InkOn(r, g, b, lc)
	lc = lc or Theme.LC_LABEL
	local Lc = Theme.Lc
	local ir, ig, ib = r + (1 - r) * INK_PALE, g + (1 - g) * INK_PALE, b + (1 - b) * INK_PALE
	local dr, dg, db = r * INK_DEEP, g * INK_DEEP, b * INK_DEEP
	local got, to = -Lc(ir, ig, ib, r, g, b), 1
	local dark = Lc(dr, dg, db, r, g, b)
	if dark > got then ir, ig, ib, got, to = dr, dg, db, dark, 0 end
	if got >= lc then return ir, ig, ib end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if abs(Lc(ir + (to - ir) * t, ig + (to - ig) * t, ib + (to - ib) * t, r, g, b)) >= lc then hi = t else lo = t end
	end
	return ir + (to - ir) * hi, ig + (to - ig) * hi, ib + (to - ib) * hi
end

function Theme.OnColor(r, g, b)
	return Theme.InkOn(r, g, b)
end

-- A color as a face words sit on: the color itself while its ink reads on it at `lc` (Theme.LC_LABEL unless
-- told), else moved in lightness, its hue and saturation kept, toward the side its better ink reads on, just
-- far enough. Some colors hold neither ink at a label's contrast (a warrior's tan: black on it reaches 55).
function Theme.FaceFor(r, g, b, lc)
	lc = lc or Theme.LC_LABEL
	local Lc = Theme.Lc
	local function Reads(fr, fg, fb)
		local ir, ig, ib = Theme.InkOn(fr, fg, fb, lc)
		return abs(Lc(ir, ig, ib, fr, fg, fb)) >= lc
	end
	if Reads(r, g, b) then return r, g, b end
	local h, s, l = ToHSL(r, g, b)
	-- Dark words read better: the face goes lighter; light words: darker.
	local lighter = Lc(0, 0, 0, r, g, b) >= -Lc(1, 1, 1, r, g, b)
	local function At(t)
		return FromHSL(h, s, lighter and l + (1 - l) * t or l * (1 - t))
	end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if Reads(At(t)) then hi = t else lo = t end
	end
	return At(hi)
end

-- A color as the ground white words stand on (a name on a health bar in a class's color): the color itself while
-- white reads on it at `lc` (Theme.LC_BODY unless told), else brought down in lightness just far enough. As it sinks
-- its hue leans off yellow toward amber and off cyan toward blue (a yellow's shade is gold, not olive), and its chroma
-- is held near its own (a pastel's shade stays a pastel's, not a neon). A priest's white comes to silver, a rogue's
-- yellow to gold; a shaman's blue is deep enough as it is.
local SINK = { warm = 30, cool = 14, within = 30, past = 6, chroma = 1.25 }

-- How far a color's hue turns as it sinks all the way: off yellow toward amber, off cyan toward blue; a grey not at all.
local function SinkLean(h, s)
	if s < 0.08 then return 0 end
	local toYellow, toCyan = Turn(h, 60), Turn(h, 180)
	if abs(toYellow) < SINK.within and toYellow >= -SINK.past then
		return -SINK.warm * (1 - abs(toYellow) / SINK.within)
	elseif abs(toCyan) < SINK.within then
		return SINK.cool * (1 - abs(toCyan) / SINK.within)
	end
	return 0
end

function Theme.Deep(r, g, b, lc)
	lc = lc or Theme.LC_BODY
	local Lc = Theme.Lc
	if -Lc(1, 1, 1, r, g, b) >= lc then return r, g, b end
	local h, s, l = ToHSL(r, g, b)
	local chroma = (1 - abs(2 * l - 1)) * s
	local lean = SinkLean(h, s)
	local function At(t)
		local nl = l * (1 - t)
		local room = 1 - abs(2 * nl - 1)
		return FromHSL(h + lean * t, room > 0 and min(s, chroma * SINK.chroma / room) or 0, nl)
	end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		local dr, dg, db = At(t)
		if -Lc(1, 1, 1, dr, dg, db) >= lc then hi = t else lo = t end
	end
	return At(hi)
end

-- Quiet words or a mark (a row you may pass by): the color a tad quieter on its surface, never greyed out. It keeps
-- QUIET.keep of its own contrast there (APCA), never under `least` (Theme.LC_LABEL unless told), and gets there by
-- lightness alone, moved toward the surface's: its hue held (a yellow leaning to gold as it sinks, as Theme.Deep's)
-- and its saturation worked out from its chroma, held to its own and eased by QUIET.fade the further it goes, since
-- the eye takes a vivid color for a brighter one than APCA, which reads lightness alone, does.
Theme.QUIET = { keep = 0.7, fade = 0.25 }
function Theme.Quiet(r, g, b, sr, sg, sb, least)
	least = least or Theme.LC_LABEL
	local Lc, Q = Theme.Lc, Theme.QUIET
	local own = abs(Lc(r, g, b, sr, sg, sb))
	local want = max(least, own * Q.keep)
	if own <= want then return r, g, b end
	local h, s, l = ToHSL(r, g, b)
	local _, _, ground = ToHSL(sr, sg, sb)
	local chroma = (1 - abs(2 * l - 1)) * s
	local lean = SinkLean(h, s) * (ground < l and 1 or 0)
	local function At(t)
		local nl = l + (ground - l) * t
		local room = 1 - abs(2 * nl - 1)
		return FromHSL(h + lean * t, room > 0 and min(1, chroma * (1 - Q.fade * t) / room) or 0, nl)
	end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		local qr, qg, qb = At(t)
		if abs(Lc(qr, qg, qb, sr, sg, sb)) >= want then lo = t else hi = t end
	end
	return At(lo)
end

-- A shade laid over a color for white words (a name on a health bar that keeps its own color and its bar's make
-- under it): how much of the ink `ir, ig, ib` over the color they need to read at `lc` (Theme.LC_BODY unless told),
-- none where they read on the color as it is.
function Theme.Veil(r, g, b, ir, ig, ib, lc)
	lc = lc or Theme.LC_BODY
	local Lc = Theme.Lc
	if -Lc(1, 1, 1, r, g, b) >= lc then return 0 end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local a = (lo + hi) / 2
		if -Lc(1, 1, 1, r + (ir - r) * a, g + (ig - g) * a, b + (ib - b) * a) >= lc then hi = a else lo = a end
	end
	return hi
end

-- Words of a color of their own on a surface: kept as they are while they read at `lc`, else drawn toward the
-- surface's ink (Theme.InkOn) just far enough. The quiet ink of a row stays quieter than its text that way.
-- `ir, ig, ib`: the ink to draw toward instead, where the surface's is already chosen (white on a shaded bar).
function Theme.Readable(r, g, b, sr, sg, sb, lc, ir, ig, ib)
	local Lc = Theme.Lc
	if abs(Lc(r, g, b, sr, sg, sb)) >= lc then return r, g, b end
	if not ir then ir, ig, ib = Theme.InkOn(sr, sg, sb, lc) end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if abs(Lc(r + (ir - r) * t, g + (ig - g) * t, b + (ib - b) * t, sr, sg, sb)) >= lc then hi = t else lo = t end
	end
	return r + (ir - r) * hi, g + (ig - g) * hi, b + (ib - b) * hi
end

-- A color kept a color where words of it must read on a surface and stand apart from the plain words round them (a
-- word lit in running text): itself while it reads at `lc`, else its hue made as vivid as it goes and moved in
-- lightness toward the side that reads, just far enough. Drawn toward the surface's ink instead (Theme.Readable), a
-- pink, a blue or a violet on a dark ground comes out a near-white, lost among white words; this way it keeps
-- several times the color. A grey has no hue to keep: it stays a grey.
function Theme.Vivid(r, g, b, sr, sg, sb, lc)
	local Lc = Theme.Lc
	if abs(Lc(r, g, b, sr, sg, sb)) >= lc then return r, g, b end
	local h, s, l = ToHSL(r, g, b)
	local vivid = s >= 0.08 and 1 or s
	local lighter = -Lc(1, 1, 1, sr, sg, sb) >= Lc(0, 0, 0, sr, sg, sb)
	local function At(t)
		return FromHSL(h, vivid, lighter and l + (1 - l) * t or l * (1 - t))
	end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		local vr, vg, vb = At(t)
		if abs(Lc(vr, vg, vb, sr, sg, sb)) >= lc then hi = t else lo = t end
	end
	return At(hi)
end

-- How much color a color carries, 0 (a grey) to 1: its strongest channel less its weakest. Unlike HSL saturation it
-- falls as a color nears white or black (a pale pink is nearly a white).
function Theme.Chroma(r, g, b)
	return max(r, g, b) - min(r, g, b)
end

-- WCAG 2.x relative luminance, for Theme.Contrast.
local function Linear(c)
	return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

local function Luminance(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

-- How far apart two colors stand in brightness: 1 (alike) to 21 (black on white). Text wants 4.5.
function Theme.Contrast(r1, g1, b1, r2, g2, b2)
	local a, b = Luminance(r1, g1, b1), Luminance(r2, g2, b2)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- A color that reads on a surface: the color itself when it stands `ratio` apart from it already, else
-- drawn toward the surface's ink (Theme.OnColor) just far enough, so it keeps as much of its hue as it can.
function Theme.Legible(r, g, b, sr, sg, sb, ratio)
	local Contrast = Theme.Contrast
	if Contrast(r, g, b, sr, sg, sb) >= ratio then return r, g, b end
	local ir, ig, ib = Theme.OnColor(sr, sg, sb)
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if Contrast(r + (ir - r) * t, g + (ig - g) * t, b + (ib - b) * t, sr, sg, sb) >= ratio then hi = t else lo = t end
	end
	return r + (ir - r) * hi, g + (ig - g) * hi, b + (ib - b) * hi
end

local function Put(t, r, g, b, a)
	t[1], t[2], t[3] = r, g, b
	if a then t[4] = a end
end

local function Blend(t, grey, accent, amount, a)
	Put(t, grey[1] + (accent[1] - grey[1]) * amount, grey[2] + (accent[2] - grey[2]) * amount,
		grey[3] + (accent[3] - grey[3]) * amount, a)
end

-- The palettes

local ui = {
	bg = {}, bgHot = {}, panel = {}, row = {}, rowEdge = {},   -- graphite surfaces
	hud = {}, hudStrip = {},                                    -- panel and bgHot at the opacity setting
	sheet = {},                                                 -- a window's body: what its content is read off
	tip = {},                                                   -- panel for tooltips and hovers: darker
	fill = {}, border = {}, hot = {},                           -- on / selected, edges, hover / focus
	text = {}, dim = {}, head = {},
	quiet = {}, quietAlert = {},      -- the text and the gold a tad quieter (Theme.Quiet): a row you may pass by
	alert   = { 1.00, 0.81, 0.38 },   -- gold: unread, waiting on you
	onAlert = { 0.16, 0.11, 0.02 },   -- text on gold
	onAccent = {},                    -- text on the accent: dark or light, whichever reads (Theme.InkOn)
	face = {}, onFace = {},           -- the accent as a face for words (Theme.FaceFor), and their ink
	onFill = {},                      -- text and marks on the fill (a primary button, a checked box)
	pick = {}, onPick = {}, onPickDim = {},   -- a picked row: the fill steeped into a row; its text, quiet text
	good  = { 0.40, 1.00, 0.78 },   -- done, full, yes
	bad     = { 1.00, 0.42, 0.38 },   -- no, declined
}
-- Tints multiply grey art, so these are lighter than the flat colors above.
local skin = {
	metal = {}, lit = {}, inset = {}, on = {}, well = {}, idle = {}, hudMetal = {},
	glyph = ui.head, hover = ui.hot, panel = ui.panel, strip = ui.bgHot, edge = ui.border, text = ui.head,
	hud = ui.hud, hudStrip = ui.hudStrip,
}
local ramp = { {}, {}, {} }
Theme.ui, Theme.skin, Theme.ramp = ui, skin, ramp
Theme.light, Theme.icon = {}, {}

local accent = { 0, 0, 0 }
local WHITE = { 1, 1, 1 }
local FILL_LUMA = 0.30   -- brightness cap for the fill
local PICK = 0.38        -- how much of the fill a picked row takes
local DIM_MORE = 8       -- contrast the quiet grey keeps above a label's, for housings that let the world through

Theme.STRENGTH = 55      -- default opacity, in percent
Theme.SHEET = 88         -- default opacity of the sheet a window's content is read off, in percent
local HOUSING = 0.25     -- how much more opaque a piece's strip and edge are than its fill
local glazed = -1        -- the opacity the palette was last built at
local sheeted = -1       -- and the sheet's, which is a setting of its own

function Theme.Strength()
	local db = core.db
	local percent = db and db.strength
	if type(percent) ~= "number" then percent = Theme.STRENGTH end
	return max(0, min(100, percent)) / 100
end

-- A window is two things with two settings, not one. The housing is the theme's work: its fill, its strip, its
-- edge and whatever its look lays round them, at Theme.Strength(). The sheet is what the content is read off --
-- a window's body, under its rows and words -- at its own, so the world can show through the frame of a window
-- without washing out what the window is for.
function Theme.Sheet()
	local db = core.db
	local percent = db and db.sheet
	if type(percent) ~= "number" then percent = Theme.SHEET end
	return max(0, min(100, percent)) / 100
end

-- Minimum opacity of tooltips and hovers, whatever the setting.
Theme.OVER = 0.88

function Theme.TipStrength()
	return Theme.OVER + (1 - Theme.OVER) * Theme.Strength()
end

local function Glaze()
	glazed, sheeted = Theme.Strength(), Theme.Sheet()
	local housing = min(1, glazed + HOUSING)
	Put(ui.tip, ui.panel[1], ui.panel[2], ui.panel[3], Theme.TipStrength())
	Put(ui.hud, ui.panel[1], ui.panel[2], ui.panel[3], glazed)
	Put(ui.hudStrip, ui.bgHot[1], ui.bgHot[2], ui.bgHot[3], housing)
	Put(ui.sheet, ui.panel[1], ui.panel[2], ui.panel[3], Theme.Sheet())
	Put(skin.hudMetal, skin.metal[1], skin.metal[2], skin.metal[3], housing)
end

local function Compute(r, g, b)
	Put(accent, r, g, b)
	local h, s, l = ToHSL(r, g, b)
	-- Lighter shades lean toward yellow or cyan, deeper ones away; a grey (priest white) has no hue.
	local lean = Lean(h, s)
	local hLight, hDeep = h + lean, h - lean / 2

	Put(ramp[1], FromHSL(hDeep, min(1, s * 1.05), l * 0.80))
	Put(ramp[2], r, g, b)
	Put(ramp[3], FromHSL(hLight, s, l + (1 - l) * 0.42))
	Blend(Theme.light, ramp[3], WHITE, 0.72)
	Blend(Theme.icon, accent, WHITE, 0.30)
	Put(ui.onAccent, Theme.OnColor(r, g, b))
	ui.onAccent[4] = 1
	Put(ui.face, Theme.FaceFor(r, g, b))
	ui.face[4] = 1
	Put(ui.onFace, Theme.InkOn(ui.face[1], ui.face[2], ui.face[3]))
	ui.onFace[4] = 1

	-- White text sits on the fill, so cap its perceived brightness (a rogue's yellow becomes old gold).
	local fr, fg, fb = FromHSL(hDeep, min(s, 0.85), max(0.24, min(0.40, l * 0.62)))
	local glare = (0.299 * fr + 0.587 * fg + 0.114 * fb) / FILL_LUMA
	if glare > 1 then fr, fg, fb = fr / glare, fg / glare, fb / glare end
	Put(ui.fill, fr, fg, fb, 1)
	Put(ui.onFill, Theme.InkOn(fr, fg, fb, Theme.LC_LABEL))
	ui.onFill[4] = 1
	Put(ui.hot, Theme.Hot(r, g, b))
	ui.hot[4] = 1
	Blend(ui.head, ramp[3], WHITE, 0.45)
	Blend(ui.text, WHITE, accent, 0.06)
	Blend(ui.border, { 0.23, 0.23, 0.25 }, accent, 0.14, 1)
	Blend(ui.rowEdge, { 0.17, 0.17, 0.19 }, accent, 0.10, 1)
	Blend(ui.bg, { 0.072, 0.072, 0.078 }, accent, 0.025, 0.90)
	Blend(ui.bgHot, { 0.125, 0.125, 0.135 }, accent, 0.04, 0.95)
	Blend(ui.panel, { 0.055, 0.055, 0.060 }, accent, 0.02, 0.96)
	Blend(ui.row, { 0.105, 0.105, 0.115 }, accent, 0.03, 0.78)
	-- The quiet grey of captions and counts: lifted until it reads as a label on the panel (a housing at low opacity
	-- shows the world through, so it needs this much to start with).
	Blend(ui.dim, { 0.56, 0.57, 0.60 }, accent, 0.10)
	Put(ui.dim, Theme.Readable(ui.dim[1], ui.dim[2], ui.dim[3], ui.panel[1], ui.panel[2], ui.panel[3], Theme.LC_LABEL + DIM_MORE))
	-- The text and the gold a tad quieter on the panel (a row you may pass by): words still a label's, the gold a mark's.
	Put(ui.quiet, Theme.Quiet(ui.text[1], ui.text[2], ui.text[3], ui.panel[1], ui.panel[2], ui.panel[3], Theme.LC_LABEL))
	Put(ui.quietAlert, Theme.Quiet(ui.alert[1], ui.alert[2], ui.alert[3], ui.panel[1], ui.panel[2], ui.panel[3], Theme.LC_MARK))
	-- The fill itself is too bright for two kinds of text; steeped into a row, the text and the quiet text
	-- are lifted until they read on it, whatever the color.
	Blend(ui.pick, ui.panel, ui.fill, PICK, 1)
	Put(ui.onPick, Theme.Readable(ui.text[1], ui.text[2], ui.text[3], ui.pick[1], ui.pick[2], ui.pick[3], Theme.LC_BODY))
	Put(ui.onPickDim, Theme.Readable(ui.dim[1], ui.dim[2], ui.dim[3], ui.pick[1], ui.pick[2], ui.pick[3], Theme.LC_LABEL))

	Blend(skin.metal, { 0.74, 0.74, 0.78 }, accent, 0.16)
	Blend(skin.lit, { 0.93, 0.93, 0.95 }, accent, 0.22)
	Blend(skin.inset, { 0.34, 0.34, 0.37 }, accent, 0.10)
	Blend(skin.well, { 0.16, 0.16, 0.17 }, accent, 0.05)
	Blend(skin.idle, { 0.40, 0.40, 0.43 }, accent, 0.08)
	Blend(skin.on, accent, Theme.light, 0.15)
	Glaze()
end

function Theme.Ramp(u)
	u = max(0, min(1, u)) * 2
	local i = min(2, floor(u) + 1)
	local a, b, f = ramp[i], ramp[i + 1], u - (i - 1)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

function Theme.Accent()
	return accent[1], accent[2], accent[3]
end

function Theme.AccentHolds()
	local face = ui.face
	return face[1] == accent[1] and face[2] == accent[2] and face[3] == accent[3]
end

-- The accent at a point, not in the ramp (a button's wash, a grip's stroke): buttons stay one color while a
-- gradient is worn; fading a wash must not pass through white from LayRamp's base texture.
function Theme.AccentSolid()
	return accent[1], accent[2], accent[3]
end

-- Fixed colors: a rogue's accent and energy are already yellow.
Theme.COMBO = {
	{ 1.00, 0.84, 0.32 },   -- gold
	{ 1.00, 0.66, 0.20 },   -- amber
	{ 1.00, 0.47, 0.14 },   -- orange
	{ 0.98, 0.29, 0.13 },   -- vermilion
	{ 0.92, 0.12, 0.16 },   -- crimson
}

function Theme.Combo(i, count)
	local heat = Theme.COMBO
	local u = count > 1 and (i - 1) / (count - 1) * (#heat - 1) or 0
	local low = max(1, min(#heat - 1, floor(u) + 1))
	local a, b, f = heat[low], heat[low + 1], u - (low - 1)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- Fixed colors for threat in a group, on every piece that shows it (nameplates, the threat meter): a margin
-- (Shy.Threat's) runs from held through slipping to lost; another tank's mob is theirs.
Theme.THREAT = {
	held     = { 0.24, 0.84, 0.40 },   -- as it should be, with room to spare
	slipping = { 0.98, 0.58, 0.16 },   -- halfway: about to change hands
	lost     = { 0.90, 0.20, 0.18 },   -- lost, or on you and you are no tank
	theirs   = { 0.42, 0.58, 0.76 },   -- another tank holds it
}

-- The threat color at a margin from 0 (lost) through 0.5 (slipping) to 1 (held).
function Theme.Threat(margin)
	local c = Theme.THREAT
	local lo, hi, t
	if margin < 0.5 then
		lo, hi, t = c.lost, c.slipping, margin * 2
	else
		lo, hi, t = c.slipping, c.held, (margin - 0.5) * 2
	end
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return lo[1] + (hi[1] - lo[1]) * t, lo[2] + (hi[2] - lo[2]) * t, lo[3] + (hi[3] - lo[3]) * t
end

-- Fixed colors by debuff type; keys are the game's dispel names (AuraUtil).
Theme.HARM = {
	None    = { 1.00, 0.20, 0.17 },   -- red
	Bleed   = { 1.00, 0.20, 0.17 },
	Poison  = { 0.25, 0.95, 0.35 },   -- green
	Curse   = { 0.74, 0.38, 1.00 },   -- purple
	Magic   = { 0.25, 0.62, 1.00 },   -- blue
	Disease = { 1.00, 0.66, 0.20 },   -- amber
}

function Theme.Harm(kind)
	local c = Theme.HARM[kind] or Theme.HARM.None
	return c[1], c[2], c[3]
end

-- Fixed colors by school mask (Enum.Damageclass.MaskPhysical ... MaskArcane); a multi-school mask averages.
Theme.SCHOOL = {
	[1]  = { 1.00, 0.97, 0.90 },   -- physical: white
	[2]  = { 1.00, 0.90, 0.50 },   -- holy: pale gold
	[4]  = { 1.00, 0.52, 0.16 },   -- fire: orange
	[8]  = { 0.45, 0.95, 0.40 },   -- nature: green
	[16] = { 0.50, 0.86, 1.00 },   -- frost: ice blue
	[32] = { 0.72, 0.52, 1.00 },   -- shadow: violet
	[64] = { 1.00, 0.52, 0.94 },   -- arcane: pink
}

function Theme.School(mask)
	local one = Theme.SCHOOL[mask]
	if one then return one[1], one[2], one[3] end
	local r, g, b, n = 0, 0, 0, 0
	for bit, c in pairs(Theme.SCHOOL) do
		if mask % (bit * 2) >= bit then r, g, b, n = r + c[1], g + c[2], b + c[3], n + 1 end
	end
	if n == 0 then one = Theme.SCHOOL[1] return one[1], one[2], one[3] end
	return r / n, g / n, b / n
end

-- Fixed colors by Enum.PowerType, lighter than the default bar colors so a thin line reads on dark art.
Theme.POWER = {
	[0] = { 0.38, 0.64, 1.00 },   -- mana
	[1] = { 1.00, 0.29, 0.22 },   -- rage
	[2] = { 1.00, 0.62, 0.30 },   -- focus
	[3] = { 1.00, 0.88, 0.30 },   -- energy
}

function Theme.Power(kind)
	local c = Theme.POWER[kind] or Theme.POWER[0]
	return c[1], c[2], c[3]
end

-- Fixed colors by way of getting about (Shy.Way's: "flight", "boat", ...), for their lines, marks and signs
-- wherever they are shown: teal where the way gets shorter, the sea's for a boat, ember for a zeppelin. An
-- airboat flies and the tram is the way's own: the flight's teal.
Theme.TRAVEL = {
	flight   = { 0.30, 0.86, 0.80 },   -- teal
	boat     = { 0.24, 0.48, 1.00 },   -- the sea's
	zeppelin = { 1.00, 0.44, 0.24 },   -- ember
}
Theme.TRAVEL.airboat, Theme.TRAVEL.tram, Theme.TRAVEL.portal = Theme.TRAVEL.flight, Theme.TRAVEL.flight, Theme.TRAVEL.flight

function Theme.Travel(by)
	local c = Theme.TRAVEL[by] or Theme.TRAVEL.flight
	return c[1], c[2], c[3]
end

-- The inks a note on the map (and what is drawn there) may wear, by name and in the order they are offered:
-- clear colors that read on the drawn map's parchment and on the terrain's darker ground.
Theme.NOTE = {
	{ key = "gold",   name = "Gold",   color = { 1.00, 0.80, 0.30 } },
	{ key = "red",    name = "Red",    color = { 1.00, 0.36, 0.30 } },
	{ key = "green",  name = "Green",  color = { 0.45, 0.95, 0.40 } },
	{ key = "teal",   name = "Teal",   color = { 0.30, 0.86, 0.80 } },
	{ key = "violet", name = "Violet", color = { 0.74, 0.56, 1.00 } },
	{ key = "white",  name = "White",  color = { 0.96, 0.96, 0.94 } },
}

function Theme.Note(key)
	for _, ink in ipairs(Theme.NOTE) do
		if ink.key == key then return ink.color end
	end
	return Theme.NOTE[1].color
end

function Theme.Hex(c)
	return format("%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

function Theme.Wrap(c, text)
	return "|cff" .. Theme.Hex(c) .. text .. "|r"
end

-- The gradient
--
-- The accent can be a ramp of colors instead of one. A ramp is stops along 0 to 1, each a hue, a saturation and
-- a lightness (any color: white and black too), and between two stops a midpoint, where the two are half and
-- half. Between stops the color runs straight in the screen's RGB, as a texture's SetGradient blends its
-- corners, so a region drawn a straight piece at a time shows the ramp exactly. Every region painted in the accent
-- itself (Theme.Paint, Tint or Ink with Theme.Accent) takes it ("Regions that follow the theme"):
--   spread "across"  the screen is one ramp: a region takes the colors where its two ends stand on it
--   spread "along"   each piece runs the whole ramp, left to right across the frame the region is on
-- Flow drifts the ramp slowly (off unless set, FLOW steps), running back from its end so it never jumps. What
-- stays one color (buttons, fills, the palettes, the icons) takes the ramp's key: its most colorful stop, held to
-- what reads as an accent. One color is a ramp of one stop, so with no ramp nothing changes.
--   g = { stops = { { at, h, s, l }, ... }, mids = { m, ... }, spread = "across" | "along", flow = 0 to FLOW }
local Grad = {}
Theme.Grad = Grad
Grad.MIN, Grad.MAX = 2, 8          -- stops in a ramp
Grad.MID = { 0.05, 0.95 }          -- how far a midpoint may lean toward either stop
Grad.FLOW = 10                     -- the flow's steps (0: still)
local SPREADS = { across = true, along = true }

local function Num(v, lo, hi, default)
	if type(v) ~= "number" or v ~= v then return default end
	return max(lo, min(hi, v))
end

-- A sound ramp from anything saved or given (a copy): 2 to MAX stops in order, each in range, a midpoint between
-- each two. nil when there is no ramp in it.
function Grad.Clean(g)
	if type(g) ~= "table" or type(g.stops) ~= "table" then return nil end
	local stops = {}
	for _, s in ipairs(g.stops) do
		if type(s) == "table" and #stops < Grad.MAX then
			stops[#stops + 1] = { at = Num(s.at, 0, 1, 0), h = Num(s.h, -1e6, 1e6, 0) % 360, s = Num(s.s, 0, 1, 0), l = Num(s.l, 0, 1, 0.5) }
		end
	end
	if #stops < Grad.MIN then return nil end
	for i = 2, #stops do   -- in order, stops at one place keeping theirs
		local j = i
		while j > 1 and stops[j].at < stops[j - 1].at do
			stops[j], stops[j - 1] = stops[j - 1], stops[j]
			j = j - 1
		end
	end
	local mids = {}
	for i = 1, #stops - 1 do mids[i] = Num(type(g.mids) == "table" and g.mids[i], Grad.MID[1], Grad.MID[2], 0.5) end
	return { stops = stops, mids = mids, spread = SPREADS[g.spread] and g.spread or "across", flow = floor(Num(g.flow, 0, Grad.FLOW, 0) + 0.5) }
end

function Grad.Color(stop)
	return FromHSL(stop.h, stop.s, stop.l)
end

-- The ramp's color at u (0 to 1): the first stop's before it, the last's after; between two, eased by their midpoint
-- so that it is half and half there. A ramp of one stop is that stop's color everywhere.
function Grad.Sample(g, u)
	local stops, mids = g.stops, g.mids
	u = max(0, min(1, u))
	local first = stops[1]
	if u <= first.at or #stops == 1 then return Grad.Color(first) end
	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]
		if u <= b.at then
			local span = b.at - a.at
			local t = span > 1e-9 and (u - a.at) / span or 1
			local m = mids and mids[i] or 0.5
			if t <= m then t = 0.5 * t / m else t = 0.5 + 0.5 * (t - m) / (1 - m) end
			local ar, ag, ab = Grad.Color(a)
			local br, bg, bb = Grad.Color(b)
			return ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t
		end
	end
	return Grad.Color(stops[#stops])
end

-- Where the ramp bends, in order: every stop, and every midpoint off the middle.
function Grad.Bends(g)
	local out = {}
	for _, s in ipairs(g.stops) do out[#out + 1] = s.at end
	for i, m in ipairs(g.mids or {}) do
		if abs(m - 0.5) > 1e-3 then
			local a, b = g.stops[i].at, g.stops[i + 1].at
			out[#out + 1] = a + (b - a) * m
		end
	end
	table.sort(out)
	return out
end

-- The flow's turn: past 1 the ramp runs back, so it never jumps from its end to its start.
function Grad.Fold(u)
	local v = u % 2
	return v <= 1 and v or 2 - v
end

-- The places strictly inside (u0, u1) where a region must be cut so each piece is one straight blend: where the
-- ramp bends (and its ends, where the flow turns), carried through the flow's `phase` (a bend p stands at
-- p - phase + 2k and at 2 - p - phase + 2k). In order, none twice.
function Grad.Breaks(g, u0, u1, phase)
	phase = phase or 0
	local points = Grad.Bends(g)
	points[#points + 1], points[#points + 2] = 0, 1
	local out, seen = {}, {}
	local lo, hi = floor((u0 + phase) / 2) - 1, floor((u1 + phase) / 2) + 1
	for _, p in ipairs(points) do
		for k = lo, hi do
			for _, x in ipairs({ p - phase + 2 * k, 2 - p - phase + 2 * k }) do
				local key = floor(x * 1e6 + 0.5)
				if x > u0 + 1e-6 and x < u1 - 1e-6 and not seen[key] then
					seen[key] = true
					out[#out + 1] = x
				end
			end
		end
	end
	table.sort(out)
	return out
end

-- A new stop at `at`, in the color the ramp has there; its two midpoints at the middle. Returns its index, or nil
-- when the ramp holds MAX already.
function Grad.Add(g, at)
	if #g.stops >= Grad.MAX then return nil end
	at = max(0, min(1, at))
	local h, s, l = ToHSL(Grad.Sample(g, at))
	local i = #g.stops + 1
	for k, stop in ipairs(g.stops) do
		if at < stop.at then
			i = k
			break
		end
	end
	table.insert(g.stops, i, { at = at, h = h, s = s, l = l })
	-- The segment it falls in becomes two (before the first stop or past the last: one more).
	if i == 1 then table.insert(g.mids, 1, 0.5)
	elseif i > #g.mids + 1 then g.mids[#g.mids + 1] = 0.5
	else
		g.mids[i - 1] = 0.5
		table.insert(g.mids, i, 0.5)
	end
	return i
end

-- Stop i moved to `at`: the stops kept in order. Returns where it stands now.
function Grad.Move(g, i, at)
	local stop = g.stops[i]
	if not stop then return i end
	stop.at = max(0, min(1, at))
	while i > 1 and g.stops[i - 1].at > stop.at do
		g.stops[i], g.stops[i - 1] = g.stops[i - 1], stop
		i = i - 1
	end
	while i < #g.stops and g.stops[i + 1].at < stop.at do
		g.stops[i], g.stops[i + 1] = g.stops[i + 1], stop
		i = i + 1
	end
	return i
end

-- Stop i taken out (never below MIN): the two segments round it become one, its midpoint at the middle. True when
-- it was.
function Grad.Remove(g, i)
	if #g.stops <= Grad.MIN or not g.stops[i] then return false end
	table.remove(g.stops, i)
	if i > #g.mids then
		table.remove(g.mids)
	else
		table.remove(g.mids, i)
		if i > 1 then g.mids[i - 1] = 0.5 end
	end
	return true
end

-- The ramp turned end for end.
function Grad.Reverse(g)
	local stops, mids = {}, {}
	for i = #g.stops, 1, -1 do
		local s = g.stops[i]
		stops[#stops + 1] = { at = 1 - s.at, h = s.h, s = s.s, l = s.l }
	end
	for i = #g.mids, 1, -1 do mids[#mids + 1] = 1 - g.mids[i] end
	g.stops, g.mids = stops, mids
end

-- The key: the hue, saturation and lightness of the stop with the most color in it, the one nearest the middle on a
-- tie (Theme.HueColor holds it to what reads as an accent).
function Grad.Key(g)
	local best, score
	for _, s in ipairs(g.stops) do
		local value = s.s * (1 - abs(2 * s.l - 1)) - abs(s.at - 0.5) * 1e-3
		if not score or value > score then best, score = s, value end
	end
	return best.h, best.s, best.l
end

-- One string for a ramp, the same for two that look the same (`shape`: its stops and midpoints alone).
function Grad.Sign(g, shape)
	if not g then return "" end
	local parts = {}
	for _, s in ipairs(g.stops) do parts[#parts + 1] = format("%.3f:%.1f:%.3f:%.3f", s.at, s.h, s.s, s.l) end
	for _, m in ipairs(g.mids) do parts[#parts + 1] = format("%.3f", m) end
	if not shape then parts[#parts + 1] = g.spread .. g.flow end
	return table.concat(parts, " ")
end

-- The ramps offered. A stop: { at, hue, saturation, lightness }.
local function Ramp(spread, list)
	local stops = {}
	for i, s in ipairs(list) do stops[i] = { at = s[1], h = s[2], s = s[3], l = s[4] } end
	return Grad.Clean({ stops = stops, spread = spread })
end
Theme.GRADIENTS = {
	{ key = "rainbow", name = "Rainbow Road", desc = "Every color of the rainbow, across your whole screen.",
		ramp = Ramp("across", { { 0, 352, 0.86, 0.64 }, { 0.17, 24, 0.92, 0.62 }, { 0.33, 48, 0.92, 0.60 }, { 0.5, 138, 0.62, 0.56 },
			{ 0.67, 192, 0.78, 0.60 }, { 0.83, 228, 0.86, 0.66 }, { 1, 282, 0.70, 0.68 } }) },
	{ key = "aurora", name = "Aurora", desc = "Jade into frost into violet, like the northern lights.",
		ramp = Ramp("across", { { 0, 158, 0.66, 0.54 }, { 0.5, 192, 0.74, 0.64 }, { 1, 274, 0.62, 0.70 } }) },
	{ key = "dusk", name = "Dusk", desc = "Gold, ember and crimson fading into violet.",
		ramp = Ramp("across", { { 0, 42, 0.88, 0.60 }, { 0.35, 18, 0.86, 0.58 }, { 0.7, 348, 0.72, 0.56 }, { 1, 274, 0.56, 0.62 } }) },
	{ key = "molten", name = "Molten", desc = "Gold running into ember and red on every piece.",
		ramp = Ramp("along", { { 0, 48, 0.95, 0.62 }, { 0.5, 20, 0.90, 0.56 }, { 1, 356, 0.80, 0.50 } }) },
	{ key = "fel", name = "Felfire", desc = "Deep green flaring into venom and yellow.",
		ramp = Ramp("along", { { 0, 150, 0.70, 0.40 }, { 0.5, 94, 0.92, 0.50 }, { 1, 66, 0.92, 0.62 } }) },
	{ key = "arcane", name = "Arcane", desc = "Frost blue through amethyst into rose.",
		ramp = Ramp("along", { { 0, 196, 0.80, 0.66 }, { 0.5, 274, 0.66, 0.68 }, { 1, 330, 0.76, 0.70 } }) },
	{ key = "valentine", name = "Valentine", desc = "Red, white, black, white and pink on every piece.",
		ramp = Ramp("along", { { 0, 354, 0.80, 0.54 }, { 0.25, 0, 0, 0.96 }, { 0.5, 0, 0, 0.06 }, { 0.75, 0, 0, 0.96 }, { 1, 334, 0.78, 0.74 } }) },
	{ key = "titan", name = "Titan", desc = "Gold warming to pale light and cooling to frost.",
		ramp = Ramp("along", { { 0, 42, 0.85, 0.60 }, { 0.5, 46, 0.40, 0.84 }, { 1, 192, 0.70, 0.68 } }) },
}
local GRADIENT = {}
for _, item in ipairs(Theme.GRADIENTS) do GRADIENT[item.key] = item end

local grad          -- the ramp in use (Grad.Clean's), nil for one color
local phase = 0     -- the flow's place along the ramp

-- Regions that follow the theme

-- region -> { kind, color, alpha, r, g, b, scope }; r, g, b are the values last applied.
local worn = setmetatable({}, { __mode = "k" })

-- Scopes: a frame whose regions take a palette of their own (Theme.Scope), made by Compute from its color as the
-- theme's is from the accent. A scope's `map` takes each of the theme's color tables (and Theme.Accent and
-- Theme.AccentSolid) to its own; a region worn under the frame is laid in those. Nothing in a scope wears the
-- ramp. Rebuilt in place when the theme changes (its opacity, the palette rules), so a region keeps its scope.
local scopes = setmetatable({}, { __mode = "k" })   -- frame -> scope
local scoped = 0                                     -- how many frames have one: none, and nothing is walked
local SCOPE_DEPTH = 24                               -- parents looked up for one
local colorTables                                    -- every table Compute writes (made on first use)

local function ColorTables()
	if colorTables then return colorTables end
	colorTables = {}
	local seen = {}
	local function Add(t)
		if type(t) == "table" and not seen[t] then
			seen[t] = true
			colorTables[#colorTables + 1] = t
		end
	end
	for _, t in pairs(ui) do Add(t) end
	for _, t in pairs(skin) do Add(t) end
	for _, t in ipairs(ramp) do Add(t) end
	Add(Theme.light)
	Add(Theme.icon)
	Add(accent)
	return colorTables
end

-- The palette of a color, into `into` (a scope) or a new one. The theme's own is computed again after.
local function Palette(r, g, b, into)
	local keep1, keep2, keep3 = accent[1], accent[2], accent[3]
	Compute(r, g, b)
	into = into or { map = {} }
	into.r, into.g, into.b = r, g, b
	local map = into.map
	for _, t in ipairs(ColorTables()) do
		local own = map[t] or {}
		own[1], own[2], own[3], own[4] = t[1], t[2], t[3], t[4]
		map[t] = own
	end
	local mine = map[accent]
	if not map[Theme.Accent] then
		local function Mine() return mine[1], mine[2], mine[3] end
		map[Theme.Accent], map[Theme.AccentSolid] = Mine, Mine
	end
	Compute(keep1, keep2, keep3)
	return into
end

-- The scope a region stands in: its nearest ancestor's. (A region on a restricted frame can't be asked: none.)
-- Every region painted anywhere is asked while a scope is worn, so the walk is guarded once, not at each step.
local function Climb(frame)
	for _ = 1, SCOPE_DEPTH do
		local parent = frame:GetParent()
		if not parent then return nil end
		local scope = scopes[parent]
		if scope then return scope end
		frame = parent
	end
end
local function ScopeOf(region)
	if scoped == 0 then return nil end
	local ok, scope = pcall(Climb, region)
	return ok and scope or nil
end

-- r, g, b, a, and whether the alpha is the color's own (a palette's opacity, which follows the theme).
local function Resolve(color, alpha)
	if type(color) == "function" then
		local r, g, b, a = color()
		return r, g, b, alpha or a or 1, alpha == nil and a ~= nil
	end
	return color[1], color[2], color[3], alpha or color[4] or 1, alpha == nil and color[4] ~= nil
end

local APPLY = {
	paint = function(region, r, g, b, a) region:SetColorTexture(r, g, b, a) end,
	tint = function(region, r, g, b, a) region:SetVertexColor(r, g, b, a) end,
	ink = function(region, r, g, b, a) region:SetTextColor(r, g, b, a) end,
}
-- A SetColorTexture color can't be read back.
local READ = { tint = "GetVertexColor", ink = "GetTextColor" }

-- In the ramp (The gradient). A region painted in the accent itself takes the ramp where it stands: words the color
-- at their middle, made to read on graphite; art (a tint) a straight blend between the colors at its two ends; a
-- flat stripe (a paint) the same, cut into pieces where the ramp bends (its slices: textures of their own on its
-- frame, laid over it while it stands clear, following its showing and its alpha). Marks are lifted just far
-- enough to show on graphite: a black stop is a dark grey line, never none. A region whose owner then sets its color
-- itself is let go (its hooks below), as one recolored directly always was. Where a region stands is looked at a
-- few times a second (Watch): one moved, or one laid out only now, takes the ramp where it is.
local painting = false   -- our own writes, which the hooks let by
local inRamp = setmetatable({}, { __mode = "k" })   -- region -> its worn entry, while it is in the ramp
local hooked = setmetatable({}, { __mode = "k" })
local sliced = setmetatable({}, { __mode = "k" })   -- region -> its slices, kept for when it is in the ramp again

-- The slices a flat stripe has been cut into (shown or not), in order along it.
function Theme.SlicesOf(region)
	return sliced[region] or {}
end

local function Mark(r, g, b)
	return Theme.Readable(r, g, b, ui.panel[1], ui.panel[2], ui.panel[3], Theme.LC_MARK)
end

-- The ramp sampled once each time it (or the palette a mark must read on) changes: LUT.N + 1 places from 0 to 1,
-- each its color, that color lifted to read as a mark on graphite and as a label, so a region's colors are read
-- from the table (a lerp between two samples) and never worked out again as the ramp flows. Filled by Refresh.
local LUT = { N = 256, r = { {}, {}, {} }, m = { {}, {}, {} }, l = { {}, {}, {} } }
local function Sampled()
	if not grad then return end
	local p, N = ui.panel, LUT.N
	local own, mark, label = LUT.r, LUT.m, LUT.l
	for i = 0, N do
		local r, g, b = Grad.Sample(grad, i / N)
		own[1][i], own[2][i], own[3][i] = r, g, b
		mark[1][i], mark[2][i], mark[3][i] = Theme.Readable(r, g, b, p[1], p[2], p[3], Theme.LC_MARK)
		label[1][i], label[2][i], label[3][i] = Theme.Readable(r, g, b, p[1], p[2], p[3], Theme.LC_LABEL)
	end
end

-- The ramp's color at u along it (the flow's phase added, folded back at its ends), from one of the samples'
-- tables: LUT.r its own, LUT.m lifted for a mark, LUT.l for a label.
local function Read(u, from)
	local v = Grad.Fold(u + phase) * LUT.N
	local i = floor(v)
	if i >= LUT.N then i = LUT.N - 1 elseif i < 0 then i = 0 end
	local f = v - i
	local R, G, B = from[1], from[2], from[3]
	return R[i] + (R[i + 1] - R[i]) * f, G[i] + (G[i + 1] - G[i]) * f, B[i] + (B[i + 1] - B[i]) * f
end
local function At(u) return Read(u, LUT.r) end

-- Where the ramp bends (its stops, its midpoints off the middle, its ends), worked out once a ramp, and the cuts a
-- region needs written into one list kept for it (nothing made as the ramp flows): Grad.Breaks without its tables.
local bends, bendsOf = {}, nil
local cuts = {}
local function Cuts(u0, u1)
	if bendsOf ~= grad then
		bendsOf = grad
		for i = #bends, 1, -1 do bends[i] = nil end
		for _, b in ipairs(Grad.Bends(grad)) do bends[#bends + 1] = b end
		bends[#bends + 1], bends[#bends + 2] = 0, 1
	end
	local n = 0
	local lo, hi = floor((u0 + phase) / 2) - 1, floor((u1 + phase) / 2) + 1
	for _, p in ipairs(bends) do
		for k = lo, hi do
			for side = 1, 2 do
				local x = side == 1 and p - phase + 2 * k or 2 - p - phase + 2 * k
				if x > u0 + 1e-6 and x < u1 - 1e-6 then
					-- In order, none twice: an insertion into the few there are.
					local at = n + 1
					local twice = false
					for j = 1, n do
						if abs(cuts[j] - x) < 1e-6 then twice = true break end
						if cuts[j] > x then at = j break end
					end
					if not twice then
						for j = n, at, -1 do cuts[j + 1] = cuts[j] end
						cuts[at] = x
						n = n + 1
					end
				end
			end
		end
	end
	for j = n + 1, #cuts do cuts[j] = nil end
	return n
end

-- A gradient written only when it differs from the one there (to a 255th of each channel), with the two colors
-- the texture keeps for it, set again rather than made anew.
local function Q(r, g, b, a)
	return floor(r * 255 + 0.5) * 16777216 + floor(g * 255 + 0.5) * 65536 + floor(b * 255 + 0.5) * 256 + floor((a or 1) * 255 + 0.5)
end
local function Blend2(t, r0, g0, b0, r1, g1, b1, a)
	local k0, k1 = Q(r0, g0, b0, a), Q(r1, g1, b1, a)
	if t.shyK0 == k0 and t.shyK1 == k1 then return end
	t.shyK0, t.shyK1 = k0, k1
	local c0, c1 = t.shyC0, t.shyC1
	if not c0 then
		c0, c1 = CreateColor(r0, g0, b0, a), CreateColor(r1, g1, b1, a)
		t.shyC0, t.shyC1 = c0, c1
	else
		c0:SetRGBA(r0, g0, b0, a)
		c1:SetRGBA(r1, g1, b1, a)
	end
	t:SetGradient("HORIZONTAL", c0, c1)
end

-- Where a region stands in the ramp: its two ends, 0 to 1 across the screen (or across its frame, along), and
-- its left and right as measured. nil while it has no place (not laid out, or measured as a secret).
local function Span(region)
	local left, right = region:GetLeft(), region:GetRight()
	if issecretvalue(left) or issecretvalue(right) or not (left and right) or right <= left then return nil end
	if grad.spread == "along" then
		local frame = region:GetParent()
		local fl, fr = frame and frame:GetLeft(), frame and frame:GetRight()
		if issecretvalue(fl) or issecretvalue(fr) or not (fl and fr) or fr <= fl then return nil end
		return (left - fl) / (fr - fl), (right - fl) / (fr - fl), left, right
	end
	local scale, screen = region:GetEffectiveScale(), Theme.ScreenWide()
	if not (scale and screen and screen > 0) then return nil end
	return left * scale / screen, right * scale / screen, left, right
end

-- The screen's width in pixels: measured once a watch's pass (and whenever asked outside one).
local screenWide, screenAt = 0, -1
function Theme.ScreenWide()
	local now = GetTime()
	if now ~= screenAt then
		screenAt = now
		screenWide = UIParent:GetWidth() * UIParent:GetEffectiveScale()
	end
	return screenWide
end

local function Slices(region, n)
	local list = sliced[region]
	if not list then
		list = {}
		sliced[region] = list
	end
	local frame = region:GetParent()
	local layer, sublevel = region:GetDrawLayer()
	for i = #list + 1, n do
		local t = frame:CreateTexture(nil, layer, nil, sublevel)
		t:SetColorTexture(1, 1, 1, 1)
		list[i] = t
	end
	return list
end

-- The slices shown as the region is, at its alpha; none beyond the `used` it has.
local function Mirror(region, w)
	local list = sliced[region]
	if not list then return end
	local shown, alpha = region:IsShown(), region:GetAlpha()
	for i, t in ipairs(list) do
		t:SetShown(shown and i <= (w.used or 0))
		t:SetAlpha(alpha)
	end
end

-- A tint on atlas art (a button's face slice): LayRamp uses SetGradient; leaving the ramp must put the file
-- back before SetVertexColor tints it, or the gradient and the tint fight and flash wrong for a frame.
local function RememberTex(region, w)
	if w.tex or w.kind ~= "tint" or not region.GetTexture then return end
	local path, wrap, filter = region:GetTexture()
	if not path then return end
	w.tex = { path, wrap, filter }
	if region.GetHorizTile then w.tile = { region:GetHorizTile(), region:GetVertTile() } end
end

local function Hook(region)
	if hooked[region] then return end
	hooked[region] = true
	-- Its owner set its color itself: theirs from now on, its slices put away. (A flat color set on it keeps the
	-- corners' blend under it, so that is put back to none; any other write set the corners itself.)
	local function Taken(method)
		if painting then return end
		local w = worn[region]
		if not (w and w.ramped) then return end
		worn[region] = nil
		inRamp[region] = nil
		w.ramped, w.used = nil, 0
		Mirror(region, w)
		if method == "SetColorTexture" then
			painting = true
			region:SetVertexColor(1, 1, 1, 1)
			painting = false
		end
	end
	for _, method in ipairs({ "SetVertexColor", "SetColorTexture", "SetTextColor", "SetGradient" }) do
		if region[method] then hooksecurefunc(region, method, function() Taken(method) end) end
	end
	local function Follow()
		local w = worn[region]
		if w then Mirror(region, w) end
	end
	for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAlpha" }) do
		if region[method] then hooksecurefunc(region, method, Follow) end
	end
end

local function LayRamp(region, w)
	Hook(region)
	RememberTex(region, w)
	local a = w.alpha or 1
	local u0, u1, left, right = Span(region)
	w.ramped, w.left, w.right = true, left, right
	inRamp[region] = w
	painting = true
	if not u0 then
		-- No place yet: the key color, until the watch finds it on screen.
		w.u0, w.u1, w.used, w.cut = nil, nil, 0, nil
		region.shyK0, region.shyK1 = nil, nil
		if w.kind ~= "ink" then region:SetVertexColor(1, 1, 1, 1) end
		APPLY[w.kind](region, accent[1], accent[2], accent[3], a)
	elseif w.kind == "ink" then
		w.u0, w.u1 = u0, u1
		local r, g, b = Read((u0 + u1) / 2, LUT.l)
		local k = Q(r, g, b, 1)
		if region.shyK0 ~= k then
			region.shyK0 = k
			region:SetTextColor(r, g, b)
		end
	else
		w.u0, w.u1 = u0, u1
		local n = w.kind == "paint" and Cuts(u0, u1) or 0
		if n == 0 then
			if w.used ~= 0 or w.cut ~= false then
				-- Whole again (or the first time): its own fill back, written afresh.
				w.used, w.cut = 0, false
				region.shyK0, region.shyK1 = nil, nil
				if w.kind == "paint" then region:SetColorTexture(1, 1, 1, 1) end
			end
			if region.shyFlat then
				-- One color, the ramp's at its middle (an animated alpha shows a gradient as white).
				local r, g, b = Read((u0 + u1) / 2, LUT.m)
				local k = Q(r, g, b, a)
				if region.shyK0 ~= k or region.shyK1 ~= false then
					region.shyK0, region.shyK1 = k, false
					region:SetVertexColor(r, g, b, a)
				end
			else
				local r0, g0, b0 = Read(u0, LUT.m)
				local r1, g1, b1 = Read(u1, LUT.m)
				Blend2(region, r0, g0, b0, r1, g1, b1, a)
			end
		else
			-- The region stands clear; a slice a straight piece, each from where the one before it ends.
			if w.cut ~= true then
				w.cut = true
				region.shyK0, region.shyK1 = nil, nil
				region:SetColorTexture(1, 1, 1, 0)
			end
			local list = Slices(region, n + 1)
			local wide = right - left
			local from, x0 = u0, 0
			for i = 1, n + 1 do
				local to = cuts[i] or u1
				local x1 = i == n + 1 and wide or (to - u0) / (u1 - u0) * wide
				local t = list[i]
				-- Laid again only when it moved by a part of a unit (or a slice came into use).
				if not t.shyX0 or abs(t.shyX0 - x0) > 0.05 or abs(t.shyX1 - x1) > 0.05 or t.shyLast ~= (i == n + 1) then
					t.shyX0, t.shyX1, t.shyLast = x0, x1, i == n + 1
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", region, "TOPLEFT", x0, 0)
					if i == n + 1 then t:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT") else t:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", x1, 0) end
				end
				local r0, g0, b0 = Read(from, LUT.m)
				local r1, g1, b1 = Read(to, LUT.m)
				Blend2(t, r0, g0, b0, r1, g1, b1, a)
				from, x0 = to, x1
			end
			w.used = n + 1
		end
	end
	painting = false
	Mirror(region, w)
end

-- A region in its color: in the ramp when it is painted in the accent and a ramp is worn, else as it always was.
-- `a`: the alpha it has now, kept when its color carries none (Repaint's).
local function Lay(region, w, a)
	local scope = w.scope
	if w.accent and grad and not scope then return LayRamp(region, w) end
	local r, g, b, na, own = Resolve(scope and scope.map[w.color] or w.color, w.alpha)
	if not own and type(a) == "number" and not issecretvalue(a) then na = a end
	w.r, w.g, w.b = r, g, b
	painting = true
	if w.ramped then
		w.ramped, w.used, w.u0, w.u1, w.cut = nil, 0, nil, nil, nil
		inRamp[region] = nil
		region.shyK0, region.shyK1 = nil, nil
		Mirror(region, w)
		if w.kind == "tint" and w.tex then
			region:SetTexture(unpack(w.tex))
			if w.tile and region.SetHorizTile then
				region:SetHorizTile(w.tile[1])
				region:SetVertTile(w.tile[2])
			end
		end
	end
	APPLY[w.kind](region, r, g, b, na)
	painting = false
end

local function Wear(kind, region, color, g, b, a)
	local alpha = g
	local w = worn[region]
	if not w then
		w = {}
		worn[region] = w
	end
	-- Plain numbers: kept in the region's own list, filled in place (regions are painted often: nothing is made).
	if type(color) == "number" then
		local own = w.numbers or {}
		w.numbers = own
		own[1], own[2], own[3], own[4] = color, g, b, a
		color, alpha = own, nil
	end
	w.kind, w.color, w.alpha, w.accent = kind, color, alpha, color == Theme.Accent
	w.scope = ScopeOf(region)
	RememberTex(region, w)
	Lay(region, w)
end

-- A frame's own colors: every region under it worn through the theme (Paint, Tint, Ink in a palette table or the
-- accent) takes the palette made from r, g, b as the theme's is made from the accent, now and when it is worn
-- later; nil gives the frame back to the theme. (Words colored in markup, and numbers read off the tables, stay
-- the theme's.)
-- Asking again for the color it has changes nothing: it returns at once (a frame may ask at every layout).
function Theme.Scope(frame, r, g, b)
	if r then
		local scope = scopes[frame]
		if scope and scope.r == r and scope.g == g and scope.b == b then return end
		if not scope then scoped = scoped + 1 end
		-- (A new table: what stood in the old one is laid again below.)
		scopes[frame] = Palette(r, g, b)
	elseif scopes[frame] then
		scopes[frame] = nil
		scoped = scoped - 1
	else
		return
	end
	for region, w in pairs(worn) do
		local scope = ScopeOf(region)
		if scope ~= w.scope then
			w.scope = scope
			-- The alpha it has now kept, as Repaint keeps it: a texture's tint and its alpha are one value, so a
			-- button's wash faded out would come back whole over its glyph.
			local reader, a = not w.ramped and READ[w.kind], nil
			if reader then
				local ok, _, _, _, now = pcall(region[reader], region)
				if ok then a = now end
			end
			Lay(region, w, a)
		end
	end
end

function Theme.Scoped(frame)
	local scope = scopes[frame]
	if scope then return scope.r, scope.g, scope.b end
end

function Theme.Paint(texture, ...) Wear("paint", texture, ...) end
function Theme.Tint(texture, ...) Wear("tint", texture, ...) end
function Theme.Ink(fontString, ...) Wear("ink", fontString, ...) end

-- A region worn again as it is: a color it was worn in by a function is asked again. One worn in `from` (a
-- color, or the accent function a piece took as it was made) wears `to` in its place, its alpha kept: what a
-- housing took its accent from follows UI.SetAccent. Nothing for a region the theme doesn't wear.
function Theme.Rewear(region, from, to)
	local w = worn[region]
	if not w then return end
	if from ~= nil and w.color == from then w.color, w.accent = to, to == Theme.Accent end
	Lay(region, w)
end

local function Near(a, b)
	return type(a) == "number" and not issecretvalue(a) and abs(a - b) < 0.006
end

local function Repaint()
	for region, w in pairs(worn) do
		local reader = not w.ramped and READ[w.kind]
		local ok, r, g, b, a = true, nil, nil, nil, nil
		-- A region that can't be read (nameplate, secret color) is dropped, like one recolored directly. (One in
		-- the ramp can't be read either: its hooks tell when its owner takes it.)
		if reader then ok, r, g, b, a = pcall(region[reader], region) end
		if reader and not (ok and Near(r, w.r) and Near(g, w.g) and Near(b, w.b)) then
			worn[region] = nil
			inRamp[region] = nil
		else
			-- A texture's tint and its alpha are one value: a new color keeps the alpha it has now (a button's
			-- wash faded out stays out), unless the color carries its own.
			Lay(region, w, a)
		end
	end
end

-- The watch: where every region in the ramp stands, looked at WATCH times a second, and one moved (or laid out only
-- now) laid again; with the flow on, every one shown laid again each TICK as the ramp drifts. It walks the regions in
-- the ramp alone (inRamp), reads their colors from the samples, and writes only what changed. Made once, the first
-- time a ramp is worn; it does nothing while none is.
local TICK, WATCH = 0.125, 4
local FLOW_SPEED = 0.008   -- of the ramp a second, for each step of the flow
local watching
local function Moved(region, w)
	local left, right = region:GetLeft(), region:GetRight()
	if issecretvalue(left) or issecretvalue(right) then return false end
	if not (left and right) then return w.u0 ~= nil end
	if not w.u0 then return true end
	if grad.spread == "along" then
		local u0, u1 = Span(region)
		return not u0 or abs(u0 - w.u0) > 1e-3 or abs(u1 - w.u1) > 1e-3
	end
	return abs(left - (w.left or 0)) > 0.25 or abs(right - (w.right or 0)) > 0.25
end
local function Watch()
	if watching then return end
	watching = true
	local last, beat = GetTime(), 0
	C_Timer.NewTicker(TICK, Shy.Clocked("theme: the ramp's watch", function()
		local now = GetTime()
		local dt = now - last
		last = now
		if not grad then return end
		local flowing = grad.flow > 0
		if flowing then phase = (phase + dt * grad.flow * FLOW_SPEED) % 2 end
		beat = beat + 1
		if not flowing and beat % floor(1 / (TICK * WATCH) + 0.5) ~= 0 then return end
		for region, w in pairs(inRamp) do
			if w.ramped and worn[region] == w then
				if region:IsVisible() and (flowing or Moved(region, w)) then LayRamp(region, w) end
			else
				inRamp[region] = nil
			end
		end
	end))
end

-- Icons: each addon icon has a grey copy (<name>Mono) that is tinted with the accent.

-- An addon's mark (a.mark, <Addon>Mark: its picture alone) is grey already and shows as it is. A mark also has a
-- sheet of itself drawn at each of FIT.sizes pixels (<Addon>MarkFit; laid left to right in rows a texel apart, as
-- FIT.cells): it is shown from the size nearest its own on screen, a texel a pixel, so it is never shrunk or
-- stretched (at a size between two the game's filtering breaks curves and slanted edges up). Larger than the
-- sheet holds, it is the mark's own file.
local FIT = { sizes = { 64, 56, 48, 44, 40, 36, 32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12 }, wide = 256, tall = 128,
	past = 1.12, cells = {}, fitted = setmetatable({}, { __mode = "k" }) }
do
	local x, y, row = 0, 0, 0
	for _, size in ipairs(FIT.sizes) do
		if x + size > FIT.wide then x, y, row = 0, y + row + 1, 0 end
		if row == 0 then row = size end
		FIT.cells[size] = { x, y }
		x = x + size + 1
	end
end

local function IsMark(path) return path:sub(-4) == "Mark" end
local function Grey(path) return IsMark(path) and path or path .. "Mono" end

-- Pixels a unit where a region stands, or nil while it can't be told.
local function PerUnit(region)
	local scale = region:GetEffectiveScale()
	if not scale or issecretvalue(scale) or scale <= 0 then return nil end
	return scale / PixelUtil.GetPixelToUIUnitFactor()
end

-- The sheet's size nearest `units` where `region` stands, and where it is on the sheet: size, x, y (texels), and
-- the pixels a unit there; nil where that can't be told or the mark is larger than the sheet holds.
local function Cell(units, region)
	local per = PerUnit(region)
	if not per or units * per > FIT.sizes[1] * FIT.past then return nil end
	local best
	for _, size in ipairs(FIT.sizes) do
		if not best or math.abs(size - units * per) < math.abs(best - units * per) then best = size end
	end
	return best, FIT.cells[best][1], FIT.cells[best][2], per
end

local function Fit(texture)
	local f = FIT.fitted[texture]
	local size, x, y, per = Cell(f.units, texture)
	if size then
		texture:SetTexture(f.path .. "Fit")
		texture:SetTexCoord(x / FIT.wide, (x + size) / FIT.wide, y / FIT.tall, (y + size) / FIT.tall)
	else
		texture:SetTexture(f.path)
		texture:SetTexCoord(0, 1, 0, 1)
	end
	-- (Its own size, where it has one: as large as the art, so a texel is a pixel.)
	if f.sized then
		local side = size and size / per or f.units
		texture:SetSize(side, side)
	end
end

-- units: how large the texture is where it fills something (an emblem); none: the texture's own size, which is
-- then set to the nearest the art is drawn at.
function Theme.Icon(texture, path, units)
	local was = FIT.fitted[texture]
	local own = units or (was and was.sized and was.units) or texture:GetWidth()
	if IsMark(path) and own and own > 0 then
		FIT.fitted[texture] = { path = path, units = own, sized = units == nil }
		Fit(texture)
	else
		Theme.Plain(texture)
		texture:SetTexture(Grey(path))
	end
	Theme.Tint(texture, Theme.icon)
end

-- A texture that showed a mark, before it shows something else: the whole picture again, at the size it is given.
function Theme.Plain(texture)
	if not FIT.fitted[texture] then return end
	FIT.fitted[texture] = nil
	texture:SetTexCoord(0, 1, 0, 1)
end

-- A mark as a menu row's picture (UI.Menu's item.icon), `units` large in a menu on `region`'s scale.
function Theme.MarkArt(path, units, region)
	local size, x, y = Cell(units, region or UIParent)
	if not size then return { path, Theme.icon } end
	return { path .. "Fit", Theme.icon,
		coords = { x / FIT.wide, (x + size) / FIT.wide, y / FIT.tall, (y + size) / FIT.tall } }
end

local refit = CreateFrame("Frame")
refit:RegisterEvent("UI_SCALE_CHANGED")
refit:RegisterEvent("DISPLAY_SIZE_CHANGED")
refit:SetScript("OnEvent", function()
	for texture in pairs(FIT.fitted) do Fit(texture) end
end)

function Theme.IconMarkup(path, size)
	size = size or 0
	local c = Theme.icon
	local r, g, b = floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)
	if IsMark(path) and size > 0 then
		local cell, x, y = Cell(size, UIParent)
		if cell then
			return format("|T%sFit:%d:%d:0:0:%d:%d:%d:%d:%d:%d:%d:%d:%d|t", path, size, size, FIT.wide, FIT.tall,
				x, x + cell, y, y + cell, r, g, b)
		end
	end
	-- The 64x64 is only for cropping; with the whole picture shown, any size works.
	return format("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t", Grey(path), size, size, r, g, b)
end

-- Accent source

-- A custom accent is a hue, a saturation and a lightness (0..1, the last two held to what reads as an accent
-- on graphite: never grey, never black, never white). The defaults are the family's original sapphire's.
Theme.SATURATION, Theme.LIGHTNESS = 0.85, 0.62
Theme.SAT_RANGE, Theme.LIGHT_RANGE = { 0.25, 1 }, { 0.40, 0.80 }
local function Held(v, range, default)
	if type(v) ~= "number" then return default end
	return max(range[1], min(range[2], v))
end

function Theme.HueColor(hue, sat, light)
	return FromHSL(hue, Held(sat, Theme.SAT_RANGE, Theme.SATURATION), Held(light, Theme.LIGHT_RANGE, Theme.LIGHTNESS))
end

local function ClassColor(class)
	class = class or UnitClassBase("player")
	local color = class and C_ClassColor.GetClassColor(class)
	if color then return color:GetRGB() end
end

-- The accents to pick from: your class's color (mode "class": it follows the character), any class's, a
-- few of our own, or a color made on the sliders (mode "hue", no preset). A preset is its own exact color;
-- the sliders show it, and moving one makes the color your own from there (Custom).
Theme.CURATED = {
	{ key = "sapphire", name = "Sapphire", hsl = { Theme.SAPPHIRE, 0.85, 0.62 } },
	{ key = "frost", name = "Frost", hsl = { 192, 0.70, 0.66 } },
	{ key = "jade", name = "Jade", hsl = { 158, 0.58, 0.52 } },
	{ key = "sage", name = "Sage", hsl = { 96, 0.32, 0.58 } },
	{ key = "gold", name = "Gold", hsl = { 42, 0.85, 0.58 } },
	{ key = "ember", name = "Ember", hsl = { 18, 0.86, 0.58 } },
	{ key = "crimson", name = "Crimson", hsl = { 354, 0.74, 0.56 } },
	{ key = "rose", name = "Rose", hsl = { 338, 0.72, 0.70 } },
	{ key = "amethyst", name = "Amethyst", hsl = { 274, 0.62, 0.68 } },
	{ key = "slate", name = "Slate", hsl = { 214, 0.25, 0.66 } },
	{ key = "venom", name = "Venom", hsl = { 94, 0.92, 0.50 } },
	{ key = "rust", name = "Rust", hsl = { 21, 0.62, 0.50 } },
	{ key = "tan", name = "Tan", hsl = { 34, 0.52, 0.60 } },
	{ key = "hazard", name = "Hazard", hsl = { 48, 0.95, 0.55 } },
	{ key = "phosphor", name = "Phosphor", hsl = { 128, 0.95, 0.52 } },
}
local CURATED = {}
for _, c in ipairs(Theme.CURATED) do CURATED[c.key] = c end

-- A preset's color: "class:WARRIOR" or a curated key. nil for none known.
local function PresetColor(key)
	if type(key) ~= "string" then return nil end
	local class = key:match("^class:(%u+)$")
	if class then return ClassColor(class) end
	local c = CURATED[key]
	if c then return FromHSL(c.hsl[1], c.hsl[2], c.hsl[3]) end
end

-- The ramp saved (Grad.Clean's), or nil for one color.
local function Saved()
	local db = core.db and core.db.theme
	return db and Grad.Clean(db.gradient)
end

local function Chosen()
	local db = core.db and core.db.theme
	local saved = Saved()
	if saved then return Theme.HueColor(Grad.Key(saved)) end   -- a ramp's key
	if db and db.mode == "hue" then
		local r, g, b = PresetColor(db.preset)
		if r then return r, g, b end
		return Theme.HueColor(db.hue, db.sat, db.light)
	end
	local r, g, b = ClassColor()
	if r then return r, g, b end
	return Theme.HueColor(Theme.SAPPHIRE)   -- before the player's class is known
end

Theme.PresetColor = PresetColor

-- The choices for a dropdown: { value, text } — your class, every class, ours, then Custom.
function Theme.Picks()
	local list = { { value = "class", text = "Class color (" .. (UnitClass("player") or "yours") .. ")" } }
	local names = LOCALIZED_CLASS_NAMES_MALE or {}
	for _, file in ipairs(CLASS_SORT_ORDER or {}) do
		if names[file] and C_ClassColor.GetClassColor(file) then list[#list + 1] = { value = "class:" .. file, text = names[file] } end
	end
	for _, c in ipairs(Theme.CURATED) do list[#list + 1] = { value = c.key, text = c.name } end
	list[#list + 1] = { value = "gradient", text = "Gradient" }
	list[#list + 1] = { value = "custom", text = "Custom" }
	return list
end

-- The one color picked, under any ramp worn: "class", a preset's key, or "custom".
function Theme.SolidPick()
	local db = core.db.theme
	if db.mode ~= "hue" then return "class" end
	if PresetColor(db.preset) then return db.preset end
	return "custom"
end

-- What the dropdown shows: "gradient" while a ramp is worn, else the one color (Theme.SolidPick).
function Theme.Pick()
	if Saved() then return "gradient" end
	return Theme.SolidPick()
end

-- The look

Theme.LOOKS = { "forged", "steel", "clear", "eclipse", "stitched", "riveted" }
local LOOKS = { forged = true, steel = true, clear = true, eclipse = true, stitched = true, riveted = true }
local looked = "forged"   -- the look the theme was last applied with

function Theme.LookChosen()
	local db = core.db and core.db.theme
	local look = db and db.look
	return LOOKS[look] and look or nil
end

function Theme.Look()
	return Theme.LookChosen() or "forged"
end

-- A look of its own file, offered after the others; `options` its option list (Theme.LookOption).
local OPTIONS = {}     -- look -> its options, as declared
local stamp = 0        -- moves on whenever a look option changes
function Theme.AddLook(look, options)
	if not LOOKS[look] then Theme.LOOKS[#Theme.LOOKS + 1] = look end
	LOOKS[look] = true
	OPTIONS[look] = options or {}
end

function Theme.LookOptions(look)
	return OPTIONS[look] or {}
end

local function Option(look, key)
	for _, o in ipairs(OPTIONS[look] or {}) do
		if o.key == key then return o end
	end
end

-- A value an option can't take (a choice no longer offered, a slider's out of range) is its default.
local function Fits(o, value)
	if value == nil then return false end
	if o.kind == "switch" then return type(value) == "boolean" end
	if o.kind == "slider" then return type(value) == "number" and value >= o.min and value <= o.max end
	for _, c in ipairs(o.choices or {}) do
		if c.value == value then return true end
	end
	return false
end

function Theme.LookOption(look, key)
	local o = Option(look, key)
	if not o then return nil end
	local db = core.db and core.db.theme
	local value = db and db.looks and db.looks[look] and db.looks[look][key]
	if Fits(o, value) then return value end
	return o.default
end

function Theme.LookStamp()
	return stamp
end

-- Saved without telling anyone (a preset sets several, then applies once).
local function KeepOption(look, key, value)
	local db = core.db.theme
	db.looks = db.looks or {}
	db.looks[look] = db.looks[look] or {}
	local o = Option(look, key)
	if o and Fits(o, value) and value ~= o.default then
		db.looks[look][key] = value
	else
		db.looks[look][key] = nil   -- (a switch's false is a value: never `and value or nil`)
	end
	if not next(db.looks[look]) then db.looks[look] = nil end
	stamp = stamp + 1
end

-- False when neither the accent, the opacity, the look, its options nor the ramp changed.
local worePlan = ""   -- the ramp the theme was last applied with (Grad.Sign)
local woreStamp = 0   -- the look options' stamp the theme was last applied with
local function Refresh()
	local r, g, b = Chosen()
	local look = Theme.Look()
	local saved = Saved()
	local plan = Grad.Sign(saved)
	if Near(r, accent[1]) and Near(g, accent[2]) and Near(b, accent[3]) and Near(Theme.Strength(), glazed)
		and Near(Theme.Sheet(), sheeted) and look == looked
		and plan == worePlan and stamp == woreStamp then return false end
	looked, worePlan, grad, woreStamp = look, plan, saved, stamp
	if grad then Watch() end
	Compute(r, g, b)
	Sampled()   -- the ramp sampled on the palette just made
	-- (A scope's palette follows the theme's opacity: made again in place.)
	for _, scope in pairs(scopes) do Palette(scope.r, scope.g, scope.b, scope) end
	Repaint()
	return true
end

function Theme.Apply()
	if Refresh() then Shy:Fire("SHY_THEME") end
end

-- Themed regions change at once; SHY_THEME (skins repainting) is throttled to 10/s so a slider drags smoothly.
local telling
local function Changed()
	if not Refresh() or telling then return end
	telling = true
	C_Timer.After(0.1, function()
		telling = false
		Shy:Fire("SHY_THEME")
	end)
end

local gradAsked = 0   -- Theme.SetGradientSoon's asks: a ramp or a color set at once outdates them

-- mode "class" or "hue"; hue 0..359, sat and light 0..1 (nil: kept as they are). Any of the three given
-- makes the color your own (a preset is let go of). A color set is one color: a ramp worn is put away.
function Theme.Set(mode, hue, sat, light)
	local db = core.db.theme
	gradAsked = gradAsked + 1
	db.gradient = nil
	db.mode = mode
	if hue then db.hue = hue end
	if sat then db.sat = Held(sat, Theme.SAT_RANGE, Theme.SATURATION) end
	if light then db.light = Held(light, Theme.LIGHT_RANGE, Theme.LIGHTNESS) end
	if hue or sat or light then db.preset = nil end
	Changed()
end

-- Picks one of Theme.Picks(): your class (it follows the character), a preset, "custom" (your own color, from
-- the one in use now) or "gradient" (the ramp you wore last, Rainbow Road the first time). The sliders are given
-- the color's hue, saturation and lightness. Any pick but the gradient is one color: a ramp worn is put away.
function Theme.SetPick(value)
	local db = core.db.theme
	if value == "gradient" then return Theme.SetGradientPick("kept") end
	local _, h, s, l = Theme.Mode()
	gradAsked = gradAsked + 1
	db.gradient = nil
	if value == "class" then
		db.mode, db.preset = "class", nil
	elseif value == "custom" then
		db.mode, db.preset = "hue", nil
	elseif PresetColor(value) then
		db.mode, db.preset = "hue", value
		h, s, l = ToHSL(PresetColor(value))
	else
		return
	end
	db.hue, db.sat, db.light = floor(h + 0.5) % 360, Held(s, Theme.SAT_RANGE, Theme.SATURATION), Held(l, Theme.LIGHT_RANGE, Theme.LIGHTNESS)
	Changed()
end

local strengthAsked = 0   -- Theme.StrengthSoon's asks: one set at once outdates them
function Theme.SetStrength(percent)
	strengthAsked = strengthAsked + 1
	core.db.strength = max(0, min(100, percent))
	Changed()
end

-- A color picked as a slider is dragged: every paint on screen follows a change, so none is applied while the
-- drag goes on. The last asked for goes on once the slider has rested REST seconds (let go, or held still).
local REST = 0.3
local pending
local asked = 0
function Theme.SetSoon(mode, hue, sat, light)
	pending = pending or {}
	pending.mode = mode
	pending.hue, pending.sat, pending.light = hue or pending.hue, sat or pending.sat, light or pending.light
	asked = asked + 1
	local mine = asked
	C_Timer.After(REST, function()
		if mine ~= asked then return end   -- moved again since
		local p = pending
		pending = nil
		Theme.Set(p.mode, p.hue, p.sat, p.light)
	end)
end

-- The Background strength the same way: the last asked for goes on once the slider has rested.
function Theme.StrengthSoon(percent)
	strengthAsked = strengthAsked + 1
	local mine = strengthAsked
	C_Timer.After(REST, function()
		if mine == strengthAsked then Theme.SetStrength(percent) end
	end)
end

-- The sheet a window's content is read off, the same way.
local sheetAsked = 0
function Theme.SetSheet(percent)
	sheetAsked = sheetAsked + 1
	core.db.sheet = max(0, min(100, percent))
	Changed()
end

function Theme.SheetSoon(percent)
	sheetAsked = sheetAsked + 1
	local mine = sheetAsked
	C_Timer.After(REST, function()
		if mine == sheetAsked then Theme.SetSheet(percent) end
	end)
end

-- The ramp. A ramp set is saved as Grad.Clean makes it (nil: one color), and kept as the one worn last.
function Theme.Gradient()
	return Saved()
end

-- Which of Theme.GRADIENTS the ramp in use is (its stops and midpoints, whatever its spread and flow), "own"
-- for one of your own, nil for one color.
function Theme.GradientPick()
	return Theme.GradientKey(Saved())
end

-- The same for any ramp `g` (a page's plan): its GRADIENTS key, "own", or nil for none.
function Theme.GradientKey(g)
	g = Grad.Clean(g)
	if not g then return nil end
	local shape = Grad.Sign(g, true)
	for _, item in ipairs(Theme.GRADIENTS) do
		if Grad.Sign(item.ramp, true) == shape then return item.key end
	end
	return "own"
end

local function SaveGradient(g)
	local db = core.db.theme
	db.gradient = Grad.Clean(g)
	if db.gradient then db.kept = Grad.Clean(db.gradient) end
	Changed()
end

function Theme.SetGradient(g)
	gradAsked = gradAsked + 1
	SaveGradient(g)
end

-- A ramp being made in the editor: none is applied while a drag goes on; the last asked for goes on once it has
-- rested REST seconds. (The editor draws its own ramp as it moves.)
function Theme.SetGradientSoon(g)
	gradAsked = gradAsked + 1
	local mine, copy = gradAsked, Grad.Clean(g)
	C_Timer.After(REST, function()
		if mine == gradAsked then SaveGradient(copy) end
	end)
end

-- key: one of Theme.GRADIENTS (as it is offered: its spread too), "kept" (the ramp worn last, Rainbow Road the
-- first time) or nil for one color.
function Theme.SetGradientPick(key)
	if key == nil then return Theme.SetGradient(nil) end
	if key == "kept" then return Theme.SetGradient(Grad.Clean(core.db.theme.kept) or GRADIENT.rainbow.ramp) end
	local item = GRADIENT[key]
	if item then Theme.SetGradient(item.ramp) end
end

-- The ramp in use; one color is a ramp of one stop.
function Theme.Stops()
	local g = Saved()
	if g then return g end
	local h, s, l = ToHSL(accent[1], accent[2], accent[3])
	return { stops = { { at = 0, h = h, s = s, l = l } }, mids = {}, spread = "across", flow = 0 }
end

function Theme.At(u)
	if grad then return At(u) end
	return accent[1], accent[2], accent[3]
end

-- The accent's source: its mode, then the hue, saturation and lightness of the color in use (a class's or a
-- preset's read off its color, a ramp's key, held to the sliders' ranges; your own as you made it).
function Theme.Mode()
	local db = core.db.theme
	if db.mode == "hue" and not PresetColor(db.preset) and not Saved() then
		return db.mode, db.hue or Theme.SAPPHIRE, Held(db.sat, Theme.SAT_RANGE, Theme.SATURATION), Held(db.light, Theme.LIGHT_RANGE, Theme.LIGHTNESS)
	end
	local h, s, l = ToHSL(Chosen())
	return db.mode, floor(h + 0.5) % 360, Held(s, Theme.SAT_RANGE, Theme.SATURATION), Held(l, Theme.LIGHT_RANGE, Theme.LIGHTNESS)
end

function Theme.SetLook(look)
	core.db.theme.look = LOOKS[look] and look or nil
	Changed()
end

function Theme.SetLookOption(look, key, value)
	if not Option(look, key) then return end
	KeepOption(look, key, value)
	Changed()
end

-- Presets

Theme.PRESETS = {
	{ key = "shy", house = true, desc = "The default: forged steel in your class color.",
		look = "forged", accent = "class", bar = "auto", slot = "auto", health = "class" },
	{ key = "monster", name = "Monster", desc = "Black hide, venom veins creeping in from its corners, a scar under every title.",
		look = "stitched", accent = "venom", bar = "auto", slot = "auto", health = "accent", options = { leather = "scaled" } },
	{ key = "grunge", name = "Grunge", desc = "Scrap steel streaked with rust, its paint chipped to the metal.",
		look = "salvage", accent = "rust", bar = "auto", slot = "sunken", health = "game", font = "stencil", options = { wear = "battered" } },
	{ key = "saddle", name = "Saddle", desc = "Tooled saddle leather sewn in tan, with a braided lace.",
		look = "stitched", accent = "tan", bar = "auto", slot = "auto", health = "class", font = "rye", options = { leather = "tooled" } },
	{ key = "oxblood", name = "Oxblood", desc = "Polished leather dyed crimson and tooled in gold, like a fine binding.",
		look = "stitched", accent = "crimson", bar = "auto", slot = "auto", health = "class", options = { leather = "bound" } },
	{ key = "ironclad", name = "Ironclad", desc = "Riveted brushed steel with a slate stripe.",
		look = "riveted", accent = "slate", bar = "auto", slot = "auto", health = "class", font = "staatliches" },
	{ key = "gunmetal", name = "Gunmetal", desc = "Riveted steel with an ember stripe, like a hot forge's door.",
		look = "riveted", accent = "ember", bar = "auto", slot = "auto", health = "class" },
	{ key = "dwarven", name = "Dwarven", desc = "Riveted steel trimmed in gold.",
		look = "riveted", accent = "gold", bar = "auto", slot = "auto", health = "class" },
	{ key = "midnight", name = "Midnight", desc = "A dark slab with an amethyst glow around it.",
		look = "eclipse", accent = "amethyst", bar = "auto", slot = "auto", health = "class" },
	{ key = "molten", name = "Molten", desc = "A dark slab backlit in ember, with glowing icons.",
		look = "eclipse", accent = "ember", bar = "auto", slot = "lit", health = "class" },
	{ key = "arctic", name = "Arctic", desc = "Frosted glass in pale frost blue.",
		look = "clear", accent = "frost", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1 },
	{ key = "emerald", name = "Emerald", desc = "Clear glass in a steel rim, lit in jade.",
		look = "steel", accent = "jade", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1 },
	{ key = "gilded", name = "Gilded", desc = "Forged steel in gold, rounded bars and banded icons.",
		look = "forged", accent = "gold", bar = "classic", slot = "band", health = "class" },
	{ key = "hellfire", name = "Hellfire", desc = "Charred wood smouldering in ember, with glowing icons.",
		look = "charred", accent = "ember", bar = "auto", slot = "lit", health = "class", font = "rocker", options = { embers = "few" } },
	{ key = "felwood", name = "Felwood", desc = "Wood scorched by fel fire, still burning green in the cracks.",
		look = "charred", accent = "venom", bar = "auto", slot = "sunken", health = "accent", font = "rocker", options = { embers = "many" } },
	{ key = "cinder", name = "Cinder", desc = "Burnt timber gone cold, a frost-blue fire deep in the char.",
		look = "charred", accent = "frost", bar = "auto", slot = "sunken", health = "class", font = "rocker", options = { embers = "few", glow = 40 } },
	{ key = "junkyard", name = "Junkyard", desc = "Bolted scrap plates with hazard paint worn half away.",
		look = "salvage", accent = "hazard", bar = "auto", slot = "sunken", health = "class", font = "stencil" },
	{ key = "toxic", name = "Toxic", desc = "Rusted scrap daubed in venom green.",
		look = "salvage", accent = "venom", bar = "auto", slot = "auto", health = "accent", font = "stencil" },
	{ key = "comic", name = "Comic", desc = "Inked panels with crimson caption boxes and speech balloons.",
		look = "comic", accent = "crimson", bar = "auto", slot = "auto", health = "class", font = "bangers", text = "outline" },
	{ key = "pulp", name = "Pulp", desc = "Hand-inked panels with gold captions, like an old pulp cover.",
		look = "comic", accent = "gold", bar = "auto", slot = "auto", health = "class", font = "bangers", text = "outline", options = { halftone = "heavy" } },
	{ key = "hero", name = "Hero", desc = "Bold ink and bright captions, straight off a hero's page.",
		look = "comic", accent = "sapphire", bar = "auto", slot = "auto", health = "accent", font = "bangers", text = "outline" },
	{ key = "matrix", name = "Matrix", desc = "Digital rain falling down a dark phosphor screen.",
		look = "matrix", accent = "phosphor", bar = "auto", slot = "auto", health = "class" },
	{ key = "grove", name = "Grove", desc = "A wild grove of vines and blossoms, a huge emerald in each corner.",
		look = "grove", accent = "jade", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "wild", gem = "Emerald" } },
	{ key = "deepwood", name = "Deepwood", desc = "Deep in the woods: bark and branches, toadstools and acorns, tigerseye in the knotholes.",
		look = "grove", accent = "tan", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "woods", gem = "Tigerseye" } },
	{ key = "bloom", name = "Bloom", desc = "A flower garden in full bloom, star rubies among the roses.",
		look = "grove", accent = "rose", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "flowers", gem = "StarRuby" } },
	{ key = "geode", name = "Geode", desc = "A cave of rare gems: crystals of sapphire blue crusting the rock, gems set in gold.",
		look = "grove", accent = "sapphire", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "cave", gem = "Sapphire" } },
	{ key = "moonwell", name = "Moonwell", desc = "A night garden in pale frost, moonstones among its blossoms.",
		look = "grove", accent = "frost", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "flowers", gem = "Moonstone" } },
	{ key = "arcanegarden", name = "Arcane Garden", desc = "A grove lit gold, arcane crystals glowing in its corners.",
		look = "grove", accent = "gold", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "wild", gem = "Arcane" } },
	{ key = "twilight", name = "Twilight", desc = "A cave of amethyst dusk, a shadowgem geode in every corner.",
		look = "grove", accent = "amethyst", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { garden = "cave", gem = "Shadowgem" } },
	{ key = "felbloom", name = "Felbloom", desc = "Woods gone wild with fel, its crystals burning green under the bark.",
		look = "grove", accent = "venom", bar = "auto", slot = "auto", health = "accent", text = "shadow", textStrength = 1, options = { garden = "woods", gem = "Fel" } },
	{ key = "galaxy", name = "Galaxy", desc = "A violet nebula inside glossy black glass, its edge lit in oil-slick colors.",
		look = "galaxy", accent = "amethyst", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1 },
	{ key = "supernova", name = "Supernova", desc = "A supernova in ember and gold, the glass glowing rose around it.",
		look = "galaxy", accent = "rose", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { sky = "bright", space = "ember" } },
	{ key = "cosmos", name = "Cosmos", desc = "A deep blue spiral galaxy turning in the glass, sapphire at its edge.",
		look = "galaxy", accent = "sapphire", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1, options = { space = "deep" } },
	{ key = "heritage", name = "Heritage", desc = "The game's own bronze frame, just as the login screen shows it.",
		look = "heritage", accent = "gold", bar = "auto", slot = "band", health = "game", font = "friz", options = { color = "game" } },
	{ key = "royal", name = "Royal", desc = "The game's own frame in polished crimson.",
		look = "heritage", accent = "crimson", bar = "auto", slot = "band", health = "class", font = "friz", options = { shine = 75, frame = "bold" } },
	-- In a ramp (accent "gradient", gradient a Theme.GRADIENTS key).
	{ key = "rainbowroad", name = "Rainbow Road", desc = "A dark slab glowing in every color of the rainbow, across your screen.",
		look = "eclipse", accent = "gradient", gradient = "rainbow", bar = "auto", slot = "lit", health = "class", text = "shadow", textStrength = 1 },
	{ key = "aurora", name = "Aurora", desc = "Frosted glass lit by the northern lights.",
		look = "clear", accent = "gradient", gradient = "aurora", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1 },
	{ key = "dusk", name = "Dusk", desc = "Forged steel in the colors of a sunset, with rounded bars.",
		look = "forged", accent = "gradient", gradient = "dusk", bar = "classic", slot = "band", health = "class", text = "shadow", textStrength = 1 },
	{ key = "forgefire", name = "Forgefire", desc = "Riveted steel trimmed in gold running to red on every piece.",
		look = "riveted", accent = "gradient", gradient = "molten", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1 },
	{ key = "felfire", name = "Felfire", desc = "Black hide glowing at its edges in fel green flaring to yellow.",
		look = "stitched", accent = "gradient", gradient = "fel", bar = "auto", slot = "auto", health = "accent", text = "shadow", textStrength = 1,
		options = { leather = "scaled" } },
	{ key = "spellglass", name = "Spellglass", desc = "Glass in a steel rim, lit from frost blue to rose.",
		look = "steel", accent = "gradient", gradient = "arcane", bar = "auto", slot = "auto", health = "class", text = "shadow", textStrength = 1 },
}
local PRESET = {}
for _, preset in ipairs(Theme.PRESETS) do PRESET[preset.key] = preset end
local PARTS = { "look", "accent", "bar", "slot", "health", "gradient", "font", "text", "textStrength" }

-- The Background strength and the Icon wells a look is at its best at (percents): a preset puts its look's on as it
-- goes on (or its own, `strength` and `wells` on the preset), so a theme is seen as it was made to be seen; the
-- sliders are yours from there (neither is part of what makes a preset the one worn). A look of its own file names
-- its on its kind (UI.LookKind: `strength`, `wells`); the core's are here. Forged names none: the default is its own.
Theme.LOOK_BEST = { steel = { strength = 50 }, clear = { strength = 55 }, eclipse = { strength = 65 }, riveted = { strength = 78 } }
local function Best(look, what)
	local kind = Shy.UI and Shy.UI.LOOK_KINDS and Shy.UI.LOOK_KINDS[look]
	local v = kind and kind[what]
	if v == nil then v = Theme.LOOK_BEST[look] and Theme.LOOK_BEST[look][what] end
	return v
end
function Theme.BestStrength(look) return Best(look or Theme.Look(), "strength") end
function Theme.BestWells(look) return Best(look or Theme.Look(), "wells") end

function Theme.PresetPicks()
	local list = {}
	for _, preset in ipairs(Theme.PRESETS) do list[#list + 1] = { value = preset.key, text = preset.name } end
	list[#list + 1] = { value = "own", text = "Your own" }
	return list
end

-- Its look's options as a preset would have them: what it says, the rest at their defaults.
local function PresetOptions(preset)
	local out = {}
	for _, o in ipairs(Theme.LookOptions(preset.look)) do
		local value = preset.options and preset.options[o.key]
		if value == nil then value = o.default end
		out[o.key] = value
	end
	return out
end

function Theme.PresetParts(key)
	local preset = PRESET[key]
	if not preset then return nil end
	local parts = {}
	for _, part in ipairs(PARTS) do parts[part] = preset[part] end
	parts.font = parts.font or Theme.FONT   -- a preset naming no font wears the default
	parts.text = parts.text or false        -- naming no text effect: the look's own
	parts.textStrength = parts.textStrength or 0
	parts.options = PresetOptions(preset)
	return parts
end

-- What is worn now, as a preset's parts.
local function Worn()
	return { look = Theme.Look(), accent = Theme.Pick(), bar = Shy.Skin.Bar(), slot = Shy.Slot.Style(), health = Shy.Skin.HealthColor(),
		gradient = Theme.GradientPick(), font = Theme.Font(), text = Theme.TextChosen() or false, textStrength = Theme.TextStrength() }
end

-- `parts.options` (the look's option values) is matched when given; else the options worn now. So are `parts.font`,
-- `parts.text` and `parts.textStrength`: else what is worn now. A preset naming no font wears the default, one naming
-- no text effect the look's own (false), at no strength.
function Theme.PresetWorn(parts)
	parts = parts or Worn()
	for _, preset in ipairs(Theme.PRESETS) do
		local all = true
		for _, part in ipairs(PARTS) do
			local have, want = parts[part], preset[part]
			if part == "font" then have, want = have or Theme.Font(), want or Theme.FONT end
			if part == "text" then
				if have == nil then have = Theme.TextChosen() or false end
				want = want or false
			end
			if part == "textStrength" then have, want = have or Theme.TextStrength(), want or 0 end
			if have ~= want then
				all = false
				break
			end
		end
		if all then
			for key, value in pairs(PresetOptions(preset)) do
				local now = parts.options and parts.options[key]
				if now == nil then now = Theme.LookOption(preset.look, key) end
				if now ~= value then
					all = false
					break
				end
			end
		end
		if all then return preset.key end
	end
	return "own"
end

function Theme.SetPreset(key)
	local preset = PRESET[key]
	if not preset then return end
	for k, value in pairs(PresetOptions(preset)) do KeepOption(preset.look, k, value) end
	Theme.SetLook(preset.look)
	if preset.gradient then Theme.SetGradientPick(preset.gradient) else Theme.SetPick(preset.accent) end
	Shy.Skin.SetBar(preset.bar)
	Shy.Slot.SetStyle(preset.slot)
	Shy.Skin.SetHealthColor(preset.health)
	Theme.SetFont(preset.font or Theme.FONT)
	core.db.theme.textStrength = (preset.textStrength or 0) > 0 and preset.textStrength or nil
	Theme.SetTextEffect(preset.text)   -- nil: the look's own
	-- Seen as it was made to be seen: its Background and its Icon wells.
	local strength = preset.strength or Theme.BestStrength(preset.look)
	if strength then Theme.SetStrength(strength) end
	local wells = preset.wells or Theme.BestWells(preset.look)
	if wells and Shy.Slot and Shy.Slot.SetWellArt then Shy.Slot.SetWellArt(wells) end
end

-- The font
--
-- Shy's own words (titles, headers, tabs, buttons, labels: Theme.Face) are set in the theme's font, a part of it as
-- the look and the accent are. Names and numbers and running text (chat) keep their readable faces whatever is
-- picked. A font has the Latin alphabet; Cyrillic falls back to its own `russian` file or the rounded font, Korean
-- and Chinese to Blizzard's (UI.TitleFont's family). The game's own fonts are used from the client, never shipped.
-- A lettering face cramps under `least` units (each judged at 9 to 16 at 1.22 pixels a unit): smaller words
-- (a button, a tab, a caption under a title) are set in its `pair` instead, the default unless it names one.
-- `ink`: how far its capitals' middle stands under the middle of the line the game sets it on, a share of its size.
-- The game puts a line's baseline at its ascender's share of the line (the font's hhea ascender and descender), so
-- ink = (ascender - cap height / 2) / (ascender + descender) - 0.5, from each file's own metrics (the game's two fonts,
-- read nowhere here, are taken as centred). Words centred on something are raised by it (UI.TitleLift).
Theme.FONT = "lilita"
Theme.FONTS = {
	{ key = "lilita", name = "Lilita One", desc = "Round and bold, the default lettering.", file = Shy.FONT, ink = 0.001 },
	{ key = "bangers", name = "Bangers", desc = "Comic book lettering, all in capitals.", file = Shy.MEDIA .. "Bangers.ttf", least = 14, ink = -0.018 },
	{ key = "stencil", name = "Saira Stencil", desc = "Sprayed through a stencil, like crates and hazard signs.", file = Shy.MEDIA .. "SairaStencilOne.ttf", least = 12,
		ink = 0.003 },
	{ key = "staatliches", name = "Staatliches", desc = "Tall capitals, like plates stamped in a foundry.", file = Shy.MEDIA .. "Staatliches.ttf", least = 13,
		ink = -0.018 },
	{ key = "rocker", name = "New Rocker", desc = "Rough-cut gothic, like a sign burnt into wood.", file = Shy.MEDIA .. "NewRocker.ttf", least = 13, ink = -0.031 },
	{ key = "rye", name = "Rye", desc = "Old western wood type, like a saddle maker's sign.", file = Shy.MEDIA .. "Rye.ttf", least = 13, ink = -0.014 },
	{ key = "friz", name = "Friz Quadrata", desc = "The game's own lettering.", file = "Fonts\\FRIZQT__.TTF", russian = "Fonts\\FRIZQT___CYR.TTF" },
	{ key = "morpheus", name = "Morpheus", desc = "The lettering of the game's quest titles.", file = "Fonts\\MORPHEUS.ttf", russian = "Fonts\\MORPHEUS_CYR.ttf",
		least = 14, pair = "friz" },
}
local FONT = {}
for _, f in ipairs(Theme.FONTS) do FONT[f.key] = f end
local previewing   -- the font shown for now (Theme.PreviewFont); nil: the one worn

function Theme.Font()
	local db = core.db and core.db.theme
	local key = db and db.font
	return FONT[key] and key or Theme.FONT
end

-- The font on screen: the one previewed, else the one worn.
function Theme.FontShown()
	return previewing or Theme.Font()
end

-- The `ink` of the face words of `size` are set in (the one on screen, or its pair under its `least`).
function Theme.FontInk(size)
	local f = FONT[Theme.FontShown()] or FONT[Theme.FONT]
	if size and f.least and size < f.least then f = FONT[f.pair or Theme.FONT] end
	return f.ink or 0
end

-- A font's files by alphabet ({ roman, russian }) and the key of the face they are; nil: the one on screen. With a
-- size: under the font's `least`, its pair's.
function Theme.FontFiles(key, size)
	local f = FONT[key or Theme.FontShown()] or FONT[Theme.FONT]
	if size and f.least and size < f.least then f = FONT[f.pair or Theme.FONT] end
	return { roman = f.file, russian = f.russian or Shy.FONT_ROUNDED }, f.key
end

-- Every font string set in the theme's font: font string -> { size, flags, the font object it was given }.
local faced = setmetatable({}, { __mode = "k" })
local Effect = {}   -- the text effect's state and steps ("The text effect" below)

-- A font object brings its own alignment, color and shadow: the string keeps its own.
local function Dress(fs, object)
	local h, v = fs:GetJustifyH(), fs:GetJustifyV()
	local r, g, b, a = fs:GetTextColor()
	local sx, sy = fs:GetShadowOffset()
	local sr, sg, sb, sa = fs:GetShadowColor()
	fs:SetFontObject(object)
	-- (Each put back only when it was read whole.)
	if type(h) == "string" then fs:SetJustifyH(h) end
	if type(v) == "string" then fs:SetJustifyV(v) end
	if type(r) == "number" and type(g) == "number" and type(b) == "number" then fs:SetTextColor(r, g, b, a) end
	if type(sx) == "number" and type(sy) == "number" then fs:SetShadowOffset(sx, sy) end
	if type(sr) == "number" and type(sg) == "number" and type(sb) == "number" then fs:SetShadowColor(sr, sg, sb, sa) end
end

-- Sets Shy's own words in the theme's font at `size` and `flags`, and keeps them in it when it changes. With `key`:
-- in that font, for good (a sample of it). Returns the font string.
function Theme.Face(fs, size, flags, key)
	local object = Shy.UI.TitleFont(size, flags, key)
	Dress(fs, object)
	faced[fs] = not key and { size = size, flags = flags, object = object } or nil
	Effect.Mark(fs, true)
	return fs
end

-- A font string given a title font another way (UI.TitleFont's object through a kit or a helper) follows the
-- theme's font from now on; any other font string is left alone.
function Theme.Follow(fs)
	local made = fs and Shy.UI.TitleFontMade(fs:GetFontObject())
	if made then
		faced[fs] = { size = made.size, flags = made.flags, object = fs:GetFontObject() }
		Effect.Mark(fs, false)
	end
end

-- Every followed string in the font on screen now. One given another font since keeps it and is let go.
local function Refont()
	for fs, f in pairs(faced) do
		if fs:GetFontObject() ~= f.object then
			faced[fs] = nil
		else
			f.object = Shy.UI.TitleFont(f.size, f.flags)
			Dress(fs, f.object)
		end
	end
	Effect.All()   -- a font outlined by the client is chosen again with the effect
	Shy:Fire("SHY_FONT", Theme.FontShown())
end

-- Saved and on screen at once (a preview is let go of).
function Theme.SetFont(key)
	if not FONT[key] then key = Theme.FONT end
	local was = Theme.FontShown()
	core.db.theme.font = key ~= Theme.FONT and key or nil
	previewing = nil
	if Theme.FontShown() ~= was then
		Refont()
		Shy:Fire("SHY_THEME")
	end
end

-- Everything on screen in `key` for now, nothing saved (a font hovered in a list); nil: the one worn again.
function Theme.PreviewFont(key)
	local was = Theme.FontShown()
	previewing = FONT[key] and key or nil
	if Theme.FontShown() ~= was then Refont() end
end

-- The text effect
--
-- What Shy's own words wear to stand off what is behind them: nothing, a shadow, or an outline as comics letter
-- (light words outlined in black). Every string set through Theme.Face or Theme.Follow wears it, any other of Shy's
-- own (a button's label) through Theme.Letter. A shadow is black under light words and a soft white under dark ones,
-- cast 1 to 2 units by its strength. The effect never changes a string's ink, but for words an owner letters for
-- their ground (a caption). The client outlines in black only (a font's OUTLINE flag): light words in the title font
-- take it; dark words take a shadow. A caption's words (Theme.Letter with a ground) take the ink that reads on it:
-- dark ones stand plain there, as letterers leave them; light ones not in the title font, at 14 units and up, are
-- outlined in copies: four black copies a pixel off each diagonal, under them, kept in step with the words (their
-- text, font, alignment, wrapping, alpha and showing), for Effect.MAX strings at most. A control's words (a button's,
-- a dropdown's value: Theme.Letter with no ground) wear a shadow at the most. A string is lettered the frame after it
-- is set, so what its owner gives it as it is made (a shadow of its own) is worn over; a later change of its own is
-- too.
Theme.TEXT = "shadow"
Theme.TEXTS = {
	{ key = "plain", name = "Plain", desc = "Plain letters." },
	{ key = "shadow", name = "Shadow", desc = "A shadow under the letters, for bright or busy backgrounds." },
	{ key = "outline", name = "Outline", desc = "Light letters outlined in black, like a comic." },
}
Effect.MAX = 256
Effect.COPY_LEAST = 14   -- under this size four copies read as a blur, not an outline
Effect.rank = {}
for i, t in ipairs(Theme.TEXTS) do Effect.rank[t.key] = i end
Effect.lettered = setmetatable({}, { __mode = "k" })   -- font string -> { own, least, ground, copies, hooked }
Effect.shades = setmetatable({}, { __mode = "k" })     -- font string -> its own shadow (Theme.ShadeOn)
Effect.byLook = {}   -- look -> the effect it is lettered in unless one is picked
Effect.copied = 0    -- sets of copies made
Effect.dirty = {}
Effect.DIAGONALS = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }
-- A string's own calls the copies follow at once; and those after which it is lettered again.
Effect.SYNC = { "SetText", "SetFormattedText", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetAlpha", "Show", "Hide", "SetShown" }
Effect.AGAIN = { "SetTextColor", "SetFontObject", "SetFont", "SetShadowOffset", "SetShadowColor" }

-- The effect picked, or nil when none is (the look's own is worn).
function Theme.TextChosen()
	local db = core.db and core.db.theme
	return db and Effect.rank[db.text] and db.text or nil
end

-- The effect on screen: a preview's, the one picked, the look's own, or a shadow.
function Theme.TextEffect()
	return Effect.preview or Theme.TextChosen() or Effect.byLook[Theme.Look()] or Theme.TEXT
end

-- How deep a shadow is, 0 (1 unit) to 1 (2 units).
function Theme.TextStrength()
	local db = core.db and core.db.theme
	local v = db and tonumber(db.textStrength)
	return v and max(0, min(1, v)) or 0
end

-- A look's own effect (UI.LookKind's `text`), worn while none is picked.
function Theme.SetLookText(look, key)
	Effect.byLook[look] = Effect.rank[key] and key or nil
end

-- Light ink wants a dark outline and shadow; dark ink a light one. Dark is near black (the ink on a bright caption):
-- a saturated color of middling brightness (an epic's purple, a rare's blue) is light here, since a pale shadow
-- under it reads as a second copy of the words, not as a shadow.
Effect.DARK = 0.06   -- linear luminance under which ink counts as dark
function Effect.Light(fs)
	local r, g, b = fs:GetTextColor()
	if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or type(r) ~= "number" then return true end
	return Luminance(r, g, b) > Effect.DARK
end

function Effect.Outlined(flags)
	flags = flags or ""
	if flags:find("OUTLINE", 1, true) then return flags end
	return flags == "" and "OUTLINE" or flags .. ", OUTLINE"
end

-- The copies take the words' make: text, font, alignment, wrapping, alpha and showing; in their own ink, unshadowed.
function Effect.Sync(fs)
	local l = Effect.lettered[fs]
	local copies = l and l.copies
	if not (copies and copies.on) then return end
	local object = fs:GetFontObject()
	local file, size, flags = fs:GetFont()
	local h, v = fs:GetJustifyH(), fs:GetJustifyV()
	local text = fs:GetText()
	local shown = fs:IsShown() and not issecretvalue(text)
	for _, c in ipairs(copies) do
		if object then c:SetFontObject(object) elseif type(file) == "string" then c:SetFont(file, size, flags) end
		if type(h) == "string" then c:SetJustifyH(h) end
		if type(v) == "string" then c:SetJustifyV(v) end
		c:SetWordWrap(fs:CanWordWrap() and true or false)
		c:SetTextColor(copies.ink, copies.ink, copies.ink, 1)
		c:SetShadowOffset(0, 0)
		c:SetText(shown and text or "")
		c:SetAlpha(fs:GetAlpha())
		c:SetShown(shown)
	end
end

-- Four copies a screen pixel off each diagonal, under the words, in `ink` (0 black, 1 white).
function Effect.Copy(fs, l, ink)
	local copies = l.copies
	if not copies then
		copies = {}
		local parent = fs:GetParent()
		local layer, sub = fs:GetDrawLayer()
		layer = type(layer) == "string" and layer or "OVERLAY"
		sub = type(sub) == "number" and sub or 0
		for i = 1, #Effect.DIAGONALS do
			local c = parent:CreateFontString(nil, layer)
			c:SetDrawLayer(layer, max(-8, sub - 1))
			copies[i] = c
		end
		l.copies = copies
		Effect.copied = Effect.copied + 1
	end
	copies.on, copies.ink = true, ink
	local scale = fs:GetEffectiveScale()
	local px = (not issecretvalue(scale) and type(scale) == "number" and scale > 0) and PixelUtil.GetPixelToUIUnitFactor() / scale or 1
	for i, c in ipairs(copies) do
		local d = Effect.DIAGONALS[i]
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", fs, "TOPLEFT", d[1] * px, d[2] * px)
		c:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", d[1] * px, d[2] * px)
	end
	Effect.Sync(fs)
end

function Effect.Uncopy(l)
	local copies = l.copies
	if not (copies and copies.on) then return end
	copies.on = false
	for _, c in ipairs(copies) do c:Hide() end
end

-- The size its words are set at (a title font's, else its own font's).
function Effect.Size(fs)
	local f = faced[fs]
	if f then return f.size end
	local _, size = fs:GetFont()
	return type(size) == "number" and not issecretvalue(size) and size or 0
end

-- What a lettered string wears: the effect, whether its ink is light, and whether the client outlines it.
function Effect.Worn(fs, l)
	-- Held plain by its owner (found words on badges: Theme.HoldPlain).
	if l.plain then return "plain", Effect.Light(fs), false end
	local effect = Theme.TextEffect()
	-- A control's words (a button's, a dropdown's value: lettered with no ground) wear a shadow at the most.
	if l.control then effect = (effect ~= "plain" or l.least) and "shadow" or "plain" end
	if not l.control and l.least and Effect.rank[l.least] > Effect.rank[effect] then effect = l.least end
	local light = Effect.Light(fs)
	-- Dark words on their caption stand plain, as a letterer leaves them: the face is held for their ink
	-- (Theme.FaceFor), and anything round them only thickens them (white copies swamp words at a title's size).
	if l.ground and not light then effect = "plain" end
	-- A string in the title font with light words is outlined by the client: its font with the OUTLINE flag.
	return effect, light, effect == "outline" and light and faced[fs] ~= nil
end

local function Letter(fs, l)
	local effect, light, native = Effect.Worn(fs, l)
	local f = faced[fs]
	if f and fs:GetFontObject() == f.object then
		local want = Shy.UI.TitleFont(f.size, native and Effect.Outlined(f.flags) or f.flags)
		if want ~= f.object then
			f.object = want
			Dress(fs, want)
		end
	end
	-- Any other outline is copied only round words an owner letters for their ground (a caption), large enough
	-- for four copies to read as an outline, while there is room; else the words wear a shadow.
	local copied = effect == "outline" and not native and l.own and l.ground ~= nil and Effect.Size(fs) >= Effect.COPY_LEAST
		and (l.copies ~= nil or Effect.copied < Effect.MAX)
	if effect == "outline" and not native and not copied then effect = "shadow" end
	local shade = effect == "shadow" and Effect.shades[fs]
	if shade then
		-- Words on a face of their own: the shadow it asks for (Theme.ShadeOn), as deep as the strength says.
		local dx, dy, r, g, b, a = shade(fs, Theme.TextStrength())
		fs:SetShadowOffset(dx, dy)
		fs:SetShadowColor(r, g, b, a)
	elseif effect == "shadow" then
		local o = 1 + Theme.TextStrength()
		fs:SetShadowOffset(o, -o)
		if light then fs:SetShadowColor(0, 0, 0, 1) else fs:SetShadowColor(1, 1, 1, 0.5) end
	else
		fs:SetShadowOffset(0, 0)
		fs:SetShadowColor(0, 0, 0, 0)
	end
	if copied then Effect.Copy(fs, l, light and 0 or 1) else Effect.Uncopy(l) end
end

-- Lettered now. (Its own calls made here are the effect's: the hooks let them be.)
function Effect.Apply(fs)
	local l = Effect.lettered[fs]
	if not l then return end
	Effect.busy = true
	local ok, err = pcall(Letter, fs, l)
	Effect.busy = false
	if not ok then geterrorhandler()(err) end
end

function Effect.All()
	for fs in pairs(Effect.lettered) do Effect.Apply(fs) end
end

-- Lettered the next frame (once, however often it is asked).
Effect.Late = Shy.Clocked("theme: words lettered", function()
	Effect.waiting = false
	local list = Effect.dirty
	Effect.dirty = {}
	for each in pairs(list) do Effect.Apply(each) end
end)
function Effect.Soon(fs)
	Effect.dirty[fs] = true
	if Effect.waiting then return end
	Effect.waiting = true
	C_Timer.After(0, Effect.Late)
end

-- (Shy's own strings only: their methods are wrapped where they stand, nothing of the game's is hooked.)
function Effect.Hook(fs, l)
	if l.hooked then return end
	l.hooked = true
	local function Wrap(name, after)
		local original = fs[name]
		fs[name] = function(self, ...)
			local a, b = original(self, ...)
			if not Effect.busy then after(self) end
			return a, b
		end
	end
	for _, name in ipairs(Effect.SYNC) do Wrap(name, Effect.Sync) end
	for _, name in ipairs(Effect.AGAIN) do Wrap(name, Effect.Soon) end
end

-- A string wears the effect from the next frame; one of Shy's own (`own`) is kept in it as it changes.
function Effect.Mark(fs, own)
	local l = Effect.lettered[fs]
	if not l then
		l = {}
		Effect.lettered[fs] = l
	end
	if own then l.own = true end
	if l.own then Effect.Hook(fs, l) end
	Effect.Soon(fs)
end

-- Words of Shy's own that are no title and no caption (a name, a figure, a line of a list: UI.Words and UI.Text
-- make them) wear the effect, at the least a shadow, so they read on any look's ground (a galaxy's sky, a bright
-- accent). Laid the frame after and again as the theme changes; nothing of the string is wrapped, so words set every
-- frame cost nothing more. Returns the font string.
function Theme.Wear(fs)
	Effect.Mark(fs, false)
	Effect.lettered[fs].least = "shadow"
	return fs
end

-- A string of Shy's own words wears the effect too, from now. Lettered with no ground it is a control's words (a
-- button's label, a dropdown's value): its ink is never touched and it wears a shadow at the most, never an outline.
-- opts.least: an effect it wears at the least ("shadow" on see-through ground), false: none again. opts.ground: the
-- color it stands on (a palette table or a function: a caption behind a title), its ink then the readable one on it
-- (Theme.OnColor): dark words stand plain on it, light ones are outlined in black, in copies where the client can't
-- (14 units and up); false lets go (its owner inks it again; a title is a title again). Returns the font string.
function Theme.Letter(fs, opts)
	Effect.Mark(fs, true)
	local l = Effect.lettered[fs]
	if opts and opts.least ~= nil then l.least = Effect.rank[opts.least] and opts.least or nil end
	l.control = not (opts and opts.ground ~= nil)
	if opts and opts.ground ~= nil then
		l.ground = opts.ground or nil
		local ground = l.ground
		if ground then
			Theme.Ink(fs, function()
				local r, g, b = Resolve(ground)
				return Theme.OnColor(r, g, b)
			end)
		end
	end
	Effect.Apply(fs)
	return fs
end

-- Words held plain for a while, whatever the effect: found words on badges, where a shadow or outline would muddy
-- the ink on them (UI.Marks). One effect serves a string's every word, so the whole string stands plain. on false:
-- the effect again. False for a string that wears no effect (its owner sets its shadow itself).
function Theme.HoldPlain(fs, on)
	local l = Effect.lettered[fs]
	if not l then return false end
	on = on and true or nil
	if l.plain ~= on then
		l.plain = on
		Effect.Apply(fs)
	end
	return true
end

-- Words that stand on a face of their own (a button's) wear the shadow it asks for wherever the effect is a shadow:
-- shade(fs, strength) -> dx, dy, r, g, b, a (strength the setting's, 0 to 1); nil lets go. Lettered again at once.
function Theme.ShadeOn(fs, shade)
	Effect.shades[fs] = shade
	Effect.Mark(fs, true)
	Effect.Apply(fs)
end

-- Saved and worn at once; nil: the look's own again (a preview is let go of).
function Theme.SetTextEffect(key)
	core.db.theme.text = Effect.rank[key] and key or nil
	Effect.preview = nil
	Effect.All()
	Shy:Fire("SHY_THEME")
end

-- Every string in `key` for now, nothing saved (an effect hovered in a list); nil: the one worn again.
function Theme.PreviewTextEffect(key)
	Effect.preview = Effect.rank[key] and key or nil
	Effect.All()
end

-- 0 to 1, saved and on screen at once (from a slider: everything else is told once it rests).
function Theme.SetTextStrength(v)
	v = max(0, min(1, tonumber(v) or 0))
	core.db.theme.textStrength = v > 0 and v or nil
	Effect.All()
	Effect.asked = (Effect.asked or 0) + 1
	local mine = Effect.asked
	C_Timer.After(REST, function()
		if mine == Effect.asked then Shy:Fire("SHY_THEME") end
	end)
end

-- A look's change (its own effect), an accent's (an ink turned light or dark): every string lettered again.
Shy:On("SHY_THEME", Effect.All)

-- Where letters stand
--
-- How the client stands a string's letters in the string's box (measured in game: strings in every font of the
-- theme's, with and without the outline, each on its box):
--   an outlined string's box is wider than the same words plain by the outline's room, half of it at each end, and,
--   set from the left in a box wider than its words, its letters begin that half in (a plain string's begin at its
--   left);
--   a box is wider than its letters' own run (their advances) by that room and by what the last letter leans past
--   its advance (a slanted face: 3 or 4 pixels after a digit), which is all at its right end;
--   so a string as wide as its words, set by its centre, stands its letters left of the point (1 to 2 pixels).
-- Words that must stand on a point are set from the left by their own run (Theme.Centre); an outlined line that must
-- begin where a plain one does is set its lead to the left (Theme.Lead).
--   Theme.Lead(fs) -> units             -- how far in from the string's left its letters begin, lettered as it is worn
--   Theme.Run(fs) -> run, wide          -- how long its letters' run is, and the string itself; nil where it can't be told
--   Theme.Centre(fs, to, x, y)          -- the string placed with the middle of its letters' run on to's middle, (x, y) off
Effect.rulers = setmetatable({}, { __mode = "k" })   -- a parent -> its hidden string, to measure with
Effect.ROOM = 8   -- a centred string's box, wider than its words by this

function Effect.Plain(flags)
	local kept = {}
	for flag in (flags or ""):gmatch("[^,%s]+") do
		if not flag:find("OUTLINE", 1, true) then kept[#kept + 1] = flag end
	end
	return table.concat(kept, ", ")
end

function Theme.Lead(fs)
	local file, size, flags = fs:GetFont()
	if type(file) ~= "string" or issecretvalue(file) or type(size) ~= "number" or issecretvalue(size) then return 0 end
	flags = (type(flags) == "string" and not issecretvalue(flags)) and flags or ""
	-- A title is lettered the frame after it is set: taken as it will be worn, not as it is this frame.
	local l, f = Effect.lettered[fs], faced[fs]
	local outlined
	if l and f then
		local _, _, native = Effect.Worn(fs, l)
		outlined = native or (f.flags or ""):find("OUTLINE", 1, true) ~= nil
	else
		outlined = flags:find("OUTLINE", 1, true) ~= nil
	end
	if not outlined then return 0 end
	-- Half of what the outline widens a string by, measured where the string stands (its parent's scale).
	local parent = fs:GetParent()
	local ruler = Effect.rulers[parent]
	if not ruler then
		ruler = parent:CreateFontString(nil, "BACKGROUND")
		ruler:Hide()
		Effect.rulers[parent] = ruler
	end
	local plain = Effect.Plain(flags)
	ruler:SetFont(file, size, Effect.Outlined(plain))
	ruler:SetText("0")
	local with = ruler:GetStringWidth()
	ruler:SetFont(file, size, plain)
	local without = ruler:GetStringWidth()
	if type(with) ~= "number" or type(without) ~= "number" or issecretvalue(with) or issecretvalue(without) then return 0 end
	return max(0, (with - without) / 2)
end

-- The words twice over are wider than the words once by their run alone: whatever room the client adds to a box
-- is in both.
function Theme.Run(fs)
	local text = fs:GetText()
	if text == nil or issecretvalue(text) or text == "" then return nil end
	local once, twice = fs:GetUnboundedStringWidthForText(text), fs:GetUnboundedStringWidthForText(text .. text)
	if type(once) ~= "number" or type(twice) ~= "number" or issecretvalue(once) or issecretvalue(twice) or twice <= once then return nil end
	return twice - once, once
end

function Theme.Centre(fs, to, x, y)
	local run, wide = Theme.Run(fs)
	fs:ClearAllPoints()
	if not run then
		-- (Words the game keeps to itself, or none: by the string's own middle.)
		fs:SetWidth(0)
		fs:SetJustifyH("CENTER")
		fs:SetPoint("CENTER", to, "CENTER", x or 0, y or 0)
		return
	end
	fs:SetJustifyH("LEFT")
	fs:SetWidth(wide + Effect.ROOM)
	fs:SetPoint("LEFT", to, "CENTER", (x or 0) - run / 2 - Theme.Lead(fs), y or 0)
end

-- The rest of the core needs colors at file load, before saved settings and the class are known.
Compute(Chosen())

Shy:On("SHY_ADDON_LOADED", function(addon)
	if addon == core then Theme.Apply() end
end)
Shy:On("SHY_LOGIN", Theme.Apply)
