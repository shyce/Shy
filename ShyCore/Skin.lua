-- Shy.Skin: restyle Blizzard's frames and restore them, and Shy.Slot, the frame around every icon.
--
-- A kit only changes regions (alpha, color, art, font) and adds textures. It never moves, resizes,
-- shows, hides or reparents a Blizzard frame, so it is safe on protected buttons and in combat.
-- It records each region's original state; kit:Restore() puts everything back.
--
--   local kit = Shy.Skin.NewKit()
--
--   kit:Hide(region)                    -- alpha 0
--   kit:HideRegions(frame)              -- every texture directly on a frame
--   kit:Fade(region, alpha)
--   kit:Tint(texture, color)            -- desaturate, then tint
--   kit:Tint(texture, color, true)      -- tint only
--   kit:Button(button, normal, pushed, hover)   -- tint a button's three textures (any may be nil)
--   kit:Regions(frame, color)           -- tint every texture directly on a frame
--   kit:Text(fontString, color)
--   kit:Font(fontString, file, size, flags)     -- size and flags default to the current ones
--   kit:FontObject(fontString, object)
--   kit:ButtonFont(button, object)      -- a game button's words, and the fonts its states give them back
--   kit:Justify(fontString, side)
--   kit:Unmask(texture, mask)           -- remove an icon's round mask
--   kit:Crop(texture, l, r, t, b)       -- tex coords (an icon's dark rim is its outer 8%)
--   kit:Place(region, w, h, point, ...) -- re-anchor a region (never a frame); each point is
--                                       -- { point, relativeTo, relativePoint, x, y }; w, h may be nil
--   kit:Bar(statusBar, opts)            -- hatch fill (keeps the bar's color) over a dark hatched track.
--                                       -- opts.track = false or a color. Returns the track's parts
--   kit:Track(statusBar, color)         -- the track alone (a cast bar, whose fill Blizzard keeps changing)
--   kit:Art(texture, art, opts)         -- replace the art of a texture Blizzard shows and hides itself.
--                                       -- art: a file or a color. opts: fit = region (x, y insets),
--                                       -- slice, color, blend, coords = { l, r, t, b }, tile = true
--
--   Skin.Hatch(texture)                 -- the hatch on our own texture (see "Bars")
--   Skin.DrainClip(d)                   -- d.fill clipped from the right by an unseen bar's edge (d.measure)
--   Skin.BarDrain(bar, tall)            -- a hatch clipped to a status bar's own fill; :AttachPip(pip, y)
--   Skin.Housing(frame, out)            -- the plate art a kit drew on a frame (Immersion fades it alone), and
--                                          what an owner reported with Skin.House; added to `out` when given
--   Skin.House(frame, regions)          -- plate art an owner drew on a frame outside a kit (ShySkin's spine):
--                                          housing too. regions: a list, or a function returning one when asked
--
--   kit:Tile(owner, opts)               -- a Shy.Slot on a Blizzard frame; opts are Slot.New's. Returns the slot
--   kit:Frame(owner, opts)              -- the square steel frame alone, for a bar. opts: x, y, to, color
--   kit:Lit(texture, button, color)     -- a pushed / checked texture of Blizzard's as the slot's glow
--   kit:Piece(texture, piece, to, opts) -- a texture Blizzard colors itself as a slot piece ("mark")
--   kit:Swipe(cooldown, opts)           -- cooldown swipe in the slot's shape (opts as Slot.Swipe's)
--   kit:Plate(owner, opts)              -- flat panel with a thin border, for buttons, tabs, edit boxes.
--                                       -- opts: key (more than one per frame), x, y or
--                                       -- inset = { left, top, right, bottom }, to = region to cover
--                                       -- instead of the owner, fill, border, hover = true,
--                                       -- title = strip height, label, labelSize,
--                                       -- band = height of a band of the accent's light along the
--                                       -- top, inside the border (a calendar page's head),
--                                       -- icon = a Skin.GLYPH (iconSize), over = true (border above
--                                       -- the frame's art).
--                                       -- panel = true: a UI.Panel look instead (windows);
--                                       -- brackets = false for none.
--                                       -- cap = true as well: a console piece; `title` is then the
--                                       -- header's full height; cap = "both" adds a bar along the foot.
--                                       -- hud = true: uses the opacity setting (C.hud, C.hudStrip, C.hudMetal)
--                                       -- A panel plate with hud or cap wears the theme's look (UI.lua, "The
--                                       -- looks") and is dressed again when the look changes.
--   kit:Head(owner, opts)               -- a Plate with the header of one of UI.HEAD's sizes, Blizzard's
--                                       -- title font string dressed and stood in its strip (see Kit:Head)
--   kit:HeadRail(set, pack)             -- UI.HeadRail.Pack on a :Head set (× and leading controls)
--   kit:Line(owner, under)              -- the accent line along the foot of a region
--   kit:Mark(owner, line, color)        -- a lit stretch of a plate's line (UI.LineMark) for a frame of the
--                                       -- game's (an open tab); .mark, spanned and shown by the caller
--
--   kit:Has(region)
--   kit:Restore()
--
-- Colors are { r, g, b } or { r, g, b, a }. A tint never changes alpha: Blizzard fades many textures itself.
-- Skin.colors changes in place with the theme, but painted regions keep their color: repaint on "SHY_THEME".
-- A texture whose color is secret can't be read back, so the kit leaves it alone.
-- Never draw on a frame that lays itself out (action bars, the bag bar, the micro menu): Blizzard
-- measures every region on those to size them. Draw on their buttons instead.
--
-- Shy.Slot: the frame every icon uses, in one of three shapes picked on the hub.
--
--   local slot = Shy.Slot.New(owner, opts)   -- see Slot.New
--   slot:Set(opts)
--   slot:Mark(r, g, b) / slot:Mark()    -- a meaning color (a debuff's kind, a state), or none
--   slot:Quality(quality) / slot:Quality()  -- the quality of the item in it (Enum.ItemQuality): a line of its color
--                                       -- round the rim and a light round the slot, a grey item's frame dull
--   slot:Dim(bool)                      -- not what is looked for: frame and quality faint
--   Shy.Slot.Pin(host, anchor, corner)  -- a pin on a slot's corner (a quest's item, junk, an upgrade): pin:Set(kind)
--   slot:Empty(empty)                   -- dim frame
--   slot:Bare(bare)                     -- no frame, well only
--   slot:Steel(color)                   -- frame color override
--   slot:Fresh(fresh)                   -- the "new item" line of light
--   slot:Clip(region)                   -- mask another region to the shape
--   slot:Light(texture, color)          -- a pushed texture as the shape's glow
--   slot:Count(fontString)              -- style and place a stack count, its text sized for the slot (Slot.COUNT)
--   Slot.CountSize(units), Slot.CountSeat()  -- a count of the game's on a slot, set through a kit: its text size for a
--                                       -- slot that wide, and where it stands in the shape worn (in from the right, up)
--   slot.well, .frame, .lip, .new, .hover   -- pieces: fade them, never color them
--
--   Slot.Shape() / Slot.Set(shape)      -- "now", "cut" or "pocket"; Slot.SHAPES for a dropdown
--   Slot.Style() / Slot.SetStyle(key)   -- the finish: "auto" (the look's own) or a key of Slot.STYLES (for a
--                                       -- dropdown); Slot.StyleFor(look, pick) the finish a look wears
--   opts.style, opts.look               -- a sample slot in a finish, or a look, of its own (a picker's card)
--   Slot.Follow(texture, piece, to, x, y, size)    -- any texture as a slot piece ("glow", "frame", "well",
--                                       -- "mark", or "mask" for a mask texture); Slot.Unfollow(texture). size: the
--                                       -- slot's width in units where `to` has none yet (else measured)
--   Slot.Swipe(cooldown, { inside, color, square, size }) / Slot.Unswipe(cooldown)
--   Slot.Ring(cooldown, { color, size })    -- the cooldown swipes the frame's band: a bezel running out
--   Slot.Square(point)                  -- is that corner of the shape square
--   Slot.Lipped()                       -- does the shape have a lip (a mark color goes on it)
--   Slot.WellArt() / Slot.SetWellArt(percent)   -- how opaque the wells are (the Icon wells setting), 0 to 1
--   Slot.MarkApart()                    -- does a mark color go on a piece of its own (a lip, an inked slot's
--                                       -- tone), the frame keeping its color
--
-- Every drawn piece is drawn for each of Slot.LEVELS (units across, 2 texels a unit, its lines whole texels) and
-- a slot wears the level nearest its width: opts.size, else measured from its region. Slot.Level(units) is that
-- pick. "SHY_SLOT" fires after a shape change,
-- "SHY_SLOT_STYLE" after a finish change.
--
-- Bars: every bar that shows an amount uses Skin.HATCH. It tiles horizontally at one texel per unit
-- (6 units per weave) and stretches vertically, so the weave is the same on every bar; a status bar
-- crops its fill rather than squeezing it, so fill and track stay aligned. No gloss goes on it. A bar on
-- the head's 34 unit plaque uses Skin.HATCH_TALL, the same weave drawn for that height (Skin.Hatch(t, true)).
-- Skin.BAR is the plain fill, for strips too thin for the weave.

local Shy = Shy
local B, UI = Shy.Brand, Shy.UI
local Skin = {}
Shy.Skin = Skin

Skin.FRAME = Shy.MEDIA .. "Frame"       -- beveled frame, grey: tint it
Skin.GLOW = Shy.MEDIA .. "FrameGlow"    -- the same frame as an inward glow
Skin.WELL = Shy.MEDIA .. "Well"         -- recessed background, grey: tint it
Skin.HATCH = Shy.MEDIA .. "Hatch"       -- bar fill: a crosshatch over a lit wave (Media\SOURCE.txt), seamless where it repeats;
                                        -- the look's file (Skin.HatchFor), kept current here
Skin.HATCH_TALL = Shy.MEDIA .. "HatchTall"   -- the same for the tall plaque: its weave at its own size
Skin.BAR = Shy.MEDIA .. "Bar"           -- plain fill, lit along the top
-- The family's single glyphs, one registry for every addon: white, tinted in game, each drawn for the units it is
-- shown at (in brackets). A glyph a new piece needs is drawn with these and named here, never kept in an addon's
-- own media.
Skin.GLYPH = {
	caret    = Shy.MEDIA .. "GlyphCaret",     -- opens a menu (10); turned, a submenu or a page
	gear     = Shy.MEDIA .. "GlyphGear",      -- settings (12)
	minus    = Shy.MEDIA .. "GlyphMinus",     -- collapse
	plus     = Shy.MEDIA .. "GlyphPlus",      -- expand
	tick     = Shy.MEDIA .. "GlyphCheckS",    -- a menu row's check (drawn for 12 units and under)
	funnel   = Shy.MEDIA .. "GlyphFunnel",    -- what is shown: filters (12)
	pin      = Shy.MEDIA .. "GlyphPin",       -- a pin of your own on a map (14)
	maximize = Shy.MEDIA .. "GlyphMaximize",  -- fill the screen (8)
	restore  = Shy.MEDIA .. "GlyphRestore",   -- back into its window (9)
	chevron  = Shy.MEDIA .. "GlyphChevron",   -- points onward (7)
	sword    = Shy.MEDIA .. "GlyphSword",     -- a fight: the damage meter's current segment (12)
	sum      = Shy.MEDIA .. "GlyphSum",       -- everything added up: the meter's overall segment (12)
	clock    = Shy.MEDIA .. "GlyphClock",     -- a time gone by: a fight picked from the meter's list (12)
	lock     = Shy.MEDIA .. "GlyphLock",      -- shut until something is met: a talent row's gate (10)
	invite   = Shy.MEDIA .. "GlyphInvite",    -- ask someone in: to your group, to be your friend (13)
	block    = Shy.MEDIA .. "GlyphBlock",     -- someone shut out: the ignore list (11)
	dot      = Shy.MEDIA .. "GlyphDot",       -- a status: online, away, busy (8)
	star     = Shy.MEDIA .. "GlyphStar",      -- a favorite (12)
	voice    = Shy.MEDIA .. "GlyphVoice",     -- a voice speaking: the quest window's voice key (12)
	lens     = Shy.MEDIA .. "GlyphLens",      -- looking for something: the minimap's tracking with nothing found (12)
}

-- Nine-slice margins, in texels.
local FRAME_SLICE, GLOW_SLICE, WELL_SLICE = 5, 12, 12
Skin.FRAME_SLICE, Skin.GLOW_SLICE = FRAME_SLICE, GLOW_SLICE

-- Tints multiply grey art, so these are lighter than the flat palette in UI.colors.
--   metal   borders and frames                  lit     the same, pressed or highlighted
--   inset   plates behind buttons, bar backgrounds
--   glyph   line-art icons                      hover   mouseover
--   on      checked, open, selected             panel   flat window backgrounds
--   well    behind an icon, and an empty slot (tints Skin.WELL)
--   idle    frame of an empty slot
--   strip   a window's title strip              edge    thin flat borders
--   text    titles that were gold
Skin.colors = Shy.Theme.skin
local C = Skin.colors

local NINE_SLICE = {
	"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

local function AnySecret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

-- False when the call errors or any result is secret.
local function Read(region, method)
	local ok, a, b, c, d = pcall(region[method], region)
	if not ok or AnySecret(a, b, c, d) or a == nil then return false end
	return true, a, b, c, d
end

local function Fit(region, owner, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -y)
	region:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -x, y)
end

local function Paint(texture, c)
	texture:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

local function AtlasOf(texture)
	local atlas = texture:GetAtlas()
	if atlas ~= "" then return atlas end
end

-- Tiles horizontally, stretches vertically. A file only tiles when loaded with "REPEAT" wrap.
local function Tile(texture, file)
	texture:SetTexture(file, "REPEAT", "CLAMP")
	texture:SetHorizTile(true)
end

-- The bars' fill: a design picked on /shy (core.db.bar: Skin.Bar / Skin.SetBar), or with none picked ("auto")
-- the look's own, in its material as its slots' wells are: Forged the hatch (the weave is the forge's), Glass liquid
-- in a glass tube, Frosted a soft frosted fill, Eclipse a dark slab lit from behind, Stitched tooled leather (the
-- hide's grain pressed into a padded fill), Riveted machined steel; a look of its own file names its own
-- (UI.LookKind's `bar`): Heritage the game's own kind of rounded bar, Salvage chipped paint, Charred char still
-- burning, Comic inked by hand. Every fill is our own and tiles across. Skin.HATCH and Skin.HATCH_TALL name the
-- files in use; every texture or bar given the fill through Skin.Hatch, Skin.HatchBar or kit:Bar is given the new
-- one when the pick or the look changes.
Skin.BARS = {
	{ key = "hatch", name = "Hatch", file = Shy.MEDIA .. "Hatch", tall = Shy.MEDIA .. "HatchTall" },
	{ key = "smooth", name = "Smooth", file = Shy.MEDIA .. "Bar" },
	{ key = "frosted", name = "Frosted", file = Shy.MEDIA .. "BarFrost" },
	{ key = "slab", name = "Slab", file = Shy.MEDIA .. "BarSlab" },
	{ key = "gloss", name = "Glossy", file = Shy.MEDIA .. "BarGloss" },
	{ key = "flat", name = "Flat", file = Shy.MEDIA .. "BarFlat" },
	{ key = "stripe", name = "Striped", file = Shy.MEDIA .. "BarStripe" },
	{ key = "brushed", name = "Brushed", file = Shy.MEDIA .. "BarBrushed" },
	{ key = "grain", name = "Leather", file = Shy.MEDIA .. "BarGrain" },
	{ key = "grit", name = "Worn", file = Shy.MEDIA .. "BarGrit" },
	{ key = "comic", name = "Cel", file = Shy.MEDIA .. "BarComic" },        -- one flat tone, lighter along its top third
	{ key = "inked", name = "Inked", file = Shy.MEDIA .. "BarInked" },      -- brushed by hand: ink along top and foot, a dry brush
	{ key = "glass", name = "Glass", file = Shy.MEDIA .. "BarGlass" },      -- liquid in a glass tube
	{ key = "backlit", name = "Backlit", file = Shy.MEDIA .. "BarBacklit" },   -- a dark core, light breaking round its edges
	{ key = "machined", name = "Machined", file = Shy.MEDIA .. "BarMachined" },   -- brushed steel, beveled, a groove along it
	{ key = "classic", name = "Classic", file = Shy.MEDIA .. "BarClassic" },   -- rounded: lit high, falling to its foot
	{ key = "chipped", name = "Chipped", file = Shy.MEDIA .. "BarChipped" },   -- paint chipped to the steel, rust run from it
	{ key = "ember", name = "Ember", file = Shy.MEDIA .. "BarEmber" },      -- char, fire in its cracks
	{ key = "scaled", name = "Scaled", file = Shy.MEDIA .. "BarScaled" },   -- reptile hide pressed into a padded fill
	{ key = "polished", name = "Polished", file = Shy.MEDIA .. "BarPolished" },   -- polished leather, a band of polish high on it
	{ key = "phosphor", name = "Phosphor", file = Shy.MEDIA .. "BarPhosphor" },   -- lit phosphor, scanlines across it
	{ key = "gem", name = "Gem", file = Shy.MEDIA .. "BarGem" },            -- a rod of cut gem, step facets along it
	{ key = "bark", name = "Bark", file = Shy.MEDIA .. "BarBark" },         -- a length of branch, its bark grooved along it
	{ key = "galaxy", name = "Galaxy", file = Shy.MEDIA .. "BarGalaxy" },   -- black glass, a highlight along its top, stars in it
}
local BAR_BY_KEY = {}
for _, bar in ipairs(Skin.BARS) do BAR_BY_KEY[bar.key] = bar end
-- A look of its own file says its own (UI.LookKind's `bar`: a key, or a function giving one by its options).
local function KindPick(look, field, known)
	local kind = Shy.UI.LOOK_KINDS[look]
	local pick = kind and kind[field]
	if type(pick) == "function" then pick = pick() end
	return known[pick] and pick or nil
end
local BAR_BY_LOOK = setmetatable({ forged = "hatch", steel = "glass", clear = "frosted", eclipse = "backlit", riveted = "machined" },
	{ __index = function(_, look) return KindPick(look, "bar", BAR_BY_KEY) end })
local hatched = setmetatable({}, { __mode = "k" })   -- texture -> tall?; status bar -> "bar"

-- The pick: a design's key, or "auto" (the look's own).
function Skin.Bar()
	local db = Shy.core.db
	local key = db and db.bar
	return BAR_BY_KEY[key] and key or "auto"
end

-- The design in use for a look: the pick, or the look's own.
function Skin.BarFor(look)
	local key = Skin.Bar()
	if key == "auto" then key = BAR_BY_LOOK[look] or "hatch" end
	return BAR_BY_KEY[key]
end

function Skin.HatchFor(look, tall)
	local bar = Skin.BarFor(look)
	return tall and (bar.tall or bar.file) or bar.file
end

-- The file a pick would give a look (a page showing a pick before it is made): "auto" is the look's own.
function Skin.BarFile(pick, look)
	local key = pick
	if key == nil or key == "auto" or not BAR_BY_KEY[key] then key = BAR_BY_LOOK[look] or "hatch" end
	return BAR_BY_KEY[key].file
end

-- Every fill given the design in use for the look, when it differs from the one they wear.
local function Refile()
	local look = Shy.Theme.Look()
	local file = Skin.HatchFor(look)
	if file == Skin.HATCH then return end
	Skin.HATCH, Skin.HATCH_TALL = file, Skin.HatchFor(look, true)
	for region, tall in pairs(hatched) do
		if tall == "bar" then
			region:SetStatusBarTexture(Skin.HATCH)
			local fill = region:GetStatusBarTexture()
			if fill then
				hatched[fill] = false
				Tile(fill, Skin.HATCH)
			end
		else
			Tile(region, tall and Skin.HATCH_TALL or Skin.HATCH)
		end
	end
end

function Skin.SetBar(key)
	if key ~= "auto" and not BAR_BY_KEY[key] then return end
	Shy.core.db.bar = key ~= "auto" and key or nil
	Refile()
	Shy:Fire("SHY_BAR", Skin.Bar())
end

function Skin.Hatch(texture, tall)
	hatched[texture] = tall and true or false
	Tile(texture, tall and Skin.HATCH_TALL or Skin.HATCH)
end

-- A status bar's fill: the hatch, tiled.
function Skin.HatchBar(statusBar)
	statusBar:SetStatusBarTexture(Skin.HATCH)
	hatched[statusBar] = "bar"
	Skin.Hatch(statusBar:GetStatusBarTexture())
end

Shy:On("SHY_THEME", Refile)
-- The saved pick is only known once the core's settings have loaded.
Shy:On("SHY_ADDON_LOADED", function(addon)
	if addon == Shy.core then Refile() end
end)

-- Your own health's color, on both your health bars (your frame's and the cockpit's under your character), picked
-- as the accent is: your class's (the default), your accent, the game's green, any class's, one of the theme's
-- own (Theme.CURATED), or one of your own made on hue, saturation and lightness sliders (a pick fills them;
-- moving one makes it Custom). "SHY_HEALTH" fires on a change; a drag is applied a few times a second.
--   Skin.HealthPicks() / Skin.HealthColor() / Skin.SetHealthColor(pick)   the dropdown's
--   Skin.HealthHSL() / Skin.SetHealthHSL(h, s, l)                         the sliders' (sets Custom)
--   Skin.HealthRGB(pick)                                                  the color
local GAME_GREEN = { 0.2, 0.85, 0.2 }

function Skin.HealthPicks()
	local list = { { value = "class", text = "Class color (" .. (UnitClass("player") or "yours") .. ")" },
		{ value = "accent", text = "Your accent" }, { value = "game", text = "The game's green" } }
	for _, item in ipairs(Shy.Theme.Picks()) do
		if item.value ~= "class" then list[#list + 1] = item end
	end
	return list
end

local function Known(key)
	return key == "class" or key == "accent" or key == "game" or key == "custom" or Shy.Theme.PresetColor(key) ~= nil
end

function Skin.HealthColor()
	local db = Shy.core.db
	local key = db and db.health
	return Known(key) and key or "class"
end

function Skin.HealthRGB(key)
	key = key or Skin.HealthColor()
	if key == "accent" then return Shy.Theme.Accent() end
	if key == "game" then return GAME_GREEN[1], GAME_GREEN[2], GAME_GREEN[3] end
	if key == "custom" then
		local own = Shy.core.db.healthHSL or {}
		return Shy.Theme.HueColor(own[1] or 120, own[2], own[3])
	end
	if key == "class" then
		local class = UnitClassBase("player")
		local color = class and C_ClassColor.GetClassColor(class)
		if color then return color:GetRGB() end
		return GAME_GREEN[1], GAME_GREEN[2], GAME_GREEN[3]
	end
	return Shy.Theme.PresetColor(key)
end

-- The hue, saturation and lightness of the color in use, held to the sliders' ranges.
function Skin.HealthHSL()
	local h, s, l = Shy.Theme.ToHSL(Skin.HealthRGB())
	local own = Skin.HealthColor() == "custom" and Shy.core.db.healthHSL
	if own then h, s, l = own[1], own[2], own[3] end
	local SR, LR = Shy.Theme.SAT_RANGE, Shy.Theme.LIGHT_RANGE
	return math.floor(h + 0.5) % 360, math.max(SR[1], math.min(SR[2], s)), math.max(LR[1], math.min(LR[2], l))
end

local function Told() Shy:Fire("SHY_HEALTH", Skin.HealthColor()) end

function Skin.SetHealthColor(key)
	if not Known(key) then return end
	local db = Shy.core.db
	if key == "custom" then db.healthHSL = { Skin.HealthHSL() } end
	db.health = key ~= "class" and key or nil
	Told()
end

local healthSoon
function Skin.SetHealthHSL(h, s, l)
	local db = Shy.core.db
	db.health, db.healthHSL = "custom", { h, s, l }
	if healthSoon then return end
	healthSoon = true
	C_Timer.After(0.08, function()
		healthSoon = nil
		Told()
	end)
end

-- A clipped hatch fill: an invisible status bar's edge narrows a window from the right (Top.Make.Drain).
function Skin.DrainClip(d)
	d.measure = CreateFrame("StatusBar", nil, d)
	d.measure:EnableMouse(false)
	d.measure:SetAllPoints()
	d.measure:SetStatusBarTexture(Skin.BAR)
	d.measureFill = d.measure:GetStatusBarTexture()
	d.measureFill:SetAlpha(0)
	d.window = CreateFrame("Frame", nil, d)
	d.window:SetClipsChildren(true)
	d.window:EnableMouse(false)
	d.window:SetPoint("TOPLEFT")
	d.window:SetPoint("BOTTOMRIGHT", d.measureFill, "BOTTOMRIGHT")
	d.fill = d.window:CreateTexture(nil, "ARTWORK")
	d.fill:SetPoint("TOPLEFT", d, "TOPLEFT")
	d.fill:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT")
end

-- A hatch clipped to a status bar's own fill. The game moves that texture (a secret timer included);
-- the weave and the pip share it, so nothing here reads or copies the value.
--   d = Skin.BarDrain(bar, tall); d:AttachPip(pip [, y])
function Skin.BarDrain(bar, tall)
	local d = CreateFrame("Frame", nil, bar)
	d:SetAllPoints(bar)
	d:EnableMouse(false)
	d.window = CreateFrame("Frame", nil, d)
	d.window:SetClipsChildren(true)
	d.window:EnableMouse(false)
	d.fill = d.window:CreateTexture(nil, "ARTWORK")
	d.fill:SetPoint("TOPLEFT", d, "TOPLEFT")
	d.fill:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT")
	Skin.Hatch(d.fill, tall)
	function d:Bind()
		local edge = bar:GetStatusBarTexture()
		if not edge then return end
		self.edge = edge
		self.window:ClearAllPoints()
		self.window:SetPoint("TOPLEFT", self, "TOPLEFT")
		self.window:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT")
		if self.pip then
			self.pip:ClearAllPoints()
			self.pip:SetPoint("CENTER", edge, "RIGHT", 0, self.pipY or -1)
		end
	end
	function d:AttachPip(pip, yOff)
		if not pip then return self end
		self.pip, self.pipY = pip, yOff or -1
		self:Bind()
		return self
	end
	d:Bind()
	hooksecurefunc(bar, "SetStatusBarTexture", Shy.Clocked("skin: a bar's fill set by the game", function() d:Bind() end))
	return d
end

-- The weave on a round face: the bars' crosshatch as a disc, strongest in the middle and fading evenly to
-- the rim, on the face's own middle. One face's weave is the one look every circle wears, in the color of
-- what it holds: Skin.Weave makes it (a diameter a disc is made for: HatchDisc<N> in Media), Skin.WeaveTint
-- colors it as its face.
function Skin.Weave(parent, diameter, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	t:SetTexture(Shy.MEDIA .. "HatchDisc" .. diameter)
	t:SetSize(diameter, diameter)
	t:SetPoint("CENTER")
	return t
end

function Skin.WeaveTint(t, color)
	UI.Tint(t, color, 0.9)
end

local Kit = {}
Kit.__index = Kit

function Skin.NewKit()
	return setmetatable({ seen = {}, own = {} }, Kit)
end

local function Entry(kit, region)
	local e = kit.seen[region]
	if not e then
		e = {}
		kit.seen[region] = e
	end
	return e
end

function Kit:Has(region)
	return self.seen[region] ~= nil
end

-- Changing Blizzard's regions

function Kit:Tint(texture, color, keepColors)
	if not texture then return end
	local e = Entry(self, texture)
	if e.color == false then return end   -- secret color: left alone
	local ok, r, g, b, a = Read(texture, "GetVertexColor")
	if not ok then
		if e.color == nil then e.color = false end
		return
	end
	if e.color == nil then
		if not keepColors then
			local okGray, wasGray = Read(texture, "IsDesaturated")
			if not okGray then
				e.color = false
				return
			end
			e.gray = wasGray
		end
		e.color = { r, g, b }
	end
	if e.gray ~= nil then texture:SetDesaturated(true) end
	texture:SetVertexColor(color[1], color[2], color[3], a)
end

function Kit:Button(button, normal, pushed, hover, keepColors)
	if normal then self:Tint(button:GetNormalTexture(), normal, keepColors) end
	if pushed then self:Tint(button:GetPushedTexture(), pushed, keepColors) end
	if hover then self:Tint(button:GetHighlightTexture(), hover, keepColors) end
end

-- Every texture of the game's on the frame; ours (a kit's, a look's) keep their own colors.
function Kit:Regions(frame, color, keepColors)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and not Skin.IsOwn(region) then self:Tint(region, color, keepColors) end
	end
end

function Kit:NineSlice(nine, color)
	for _, piece in ipairs(NINE_SLICE) do self:Tint(nine[piece], color) end
end

function Kit:Text(fontString, color)
	if not fontString then return end
	local e = Entry(self, fontString)
	if e.text == false then return end
	local ok, r, g, b, a = Read(fontString, "GetTextColor")
	if not ok then
		if e.text == nil then e.text = false end
		return
	end
	if e.text == nil then e.text = { r, g, b } end
	fontString:SetTextColor(color[1], color[2], color[3], a)
end

function Kit:Justify(fontString, side)
	if not fontString then return end
	local e = Entry(self, fontString)
	if not e.justify then e.justify = fontString:GetJustifyH() end
	fontString:SetJustifyH(side)
end

function Kit:Fade(region, alpha)
	if not region then return end
	local e = Entry(self, region)
	if e.alpha == false then return end
	if e.alpha == nil then
		local ok, was = Read(region, "GetAlpha")
		if not ok then
			e.alpha = false
			return
		end
		e.alpha = was
	end
	region:SetAlpha(alpha)
end

function Kit:Hide(region)
	self:Fade(region, 0)
end

-- Every texture of Blizzard's directly on the frame; a kit's own art (Own) is left alone, so a repaint
-- doesn't fade the plate it drew the time before.
function Kit:HideRegions(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and not Skin.IsOwn(region) then self:Fade(region, 0) end
	end
end

local function KeepFont(kit, fontString)
	local e = Entry(kit, fontString)
	if not e.font then
		local file, size, flags = fontString:GetFont()
		e.font = { object = fontString:GetFontObject(), file = file, size = size, flags = flags }
	end
	return e.font
end

-- Font strings only. A font-carrying frame (edit box, message frame) returns itself from
-- GetFontObject; restoring that makes it its own parent and the client crashes with a stack overflow.
local function HasOwnFont(fontString)
	return fontString:IsObjectType("Frame") == true
end

function Kit:Font(fontString, file, size, flags)
	if not fontString or HasOwnFont(fontString) then return end
	local was = KeepFont(self, fontString)
	fontString:SetFont(file, size or was.size, flags or was.flags)
end

function Kit:FontObject(fontString, object)
	if not fontString or HasOwnFont(fontString) then return end
	KeepFont(self, fontString)
	fontString:SetFontObject(object)
	UI.Follow(fontString)   -- a title font keeps up with the theme's (Theme.Follow)
end

-- A game button's words in a font object for good: its text's font and the font its states put back (a button
-- with a NormalFont gives its text that font again as it is let go of, over whatever was set on the text).
function Kit:ButtonFont(button, object)
	local text = button and button:GetFontString()
	if not text then return end
	local e = Entry(self, button)
	if not e.states then e.states = { button:GetNormalFontObject(), button:GetHighlightFontObject(), button:GetDisabledFontObject() } end
	if e.states[1] then button:SetNormalFontObject(object) end
	if e.states[2] then button:SetHighlightFontObject(object) end
	if e.states[3] then button:SetDisabledFontObject(object) end
	self:FontObject(text, object)
end

-- Shy's own words on a game region: the theme's font at `size` (its own size when nil) and `flags`, kept up.
function Kit:Title(fontString, size, flags)
	if not fontString or HasOwnFont(fontString) then return end
	local was = KeepFont(self, fontString)
	size = math.floor((size or was.size or UI.TITLE_SIZE) + 0.5)
	self:FontObject(fontString, UI.TitleFont(size, flags))
end

function Kit:Unmask(texture, mask)
	if not (texture and mask) then return end
	Entry(self, texture).mask = mask
	texture:RemoveMaskTexture(mask)
end

function Kit:Crop(texture, left, right, top, bottom)
	if not texture then return end
	local e = Entry(self, texture)
	if not e.crop then e.crop = { texture:GetTexCoord() } end
	texture:SetTexCoord(left, right, top, bottom)
end

-- GetPoint of an anchor that named no relative point (<Anchor point="RIGHT" x="-8"/>) returns the
-- offset where the relative point belongs. SetPoint then refuses it: the offset is not a point name.
-- A secret anchor can't be put back either. Nil: leave the region where it is.
local function NormalizePoint(region, point, relativeTo, relativePoint, x, y)
	if not canaccessvalue(point, relativeTo, relativePoint, x, y) then return nil end
	if issecretvalue(point) or issecretvalue(relativeTo) or issecretvalue(relativePoint)
		or issecretvalue(x) or issecretvalue(y) then
		return nil
	end
	if type(point) ~= "string" then return nil end
	if type(relativeTo) == "number" then
		y, x = relativePoint, relativeTo
		relativeTo, relativePoint = region:GetParent(), point
	elseif type(relativePoint) == "number" then
		y, x = x, relativePoint
		relativePoint = point
	end
	if type(relativePoint) ~= "string" then relativePoint = point end
	if type(x) ~= "number" then x = 0 end
	if type(y) ~= "number" then y = 0 end
	return { point, relativeTo, relativePoint, x, y }
end

local function ReadPoints(region)
	local n = region:GetNumPoints()
	if issecretvalue(n) or type(n) ~= "number" then return nil end
	local points = {}
	for i = 1, n do
		local ok, point, to, rel, x, y = pcall(region.GetPoint, region, i)
		if not ok then return nil end
		local anchor = NormalizePoint(region, point, to, rel, x, y)
		if not anchor then return nil end
		points[i] = anchor
	end
	return points
end

local function KeepPlace(e, region)
	if e.points then return end
	e.points = ReadPoints(region) or false   -- false: unreadable, so nothing was moved to put back
	local ok, w, h = pcall(region.GetSize, region)
	e.size = (ok and type(w) == "number" and type(h) == "number" and not issecretvalue(w) and not issecretvalue(h)) and { w, h } or { 0, 0 }
end

function Kit:HeadRail(set, pack)
	pack = pack or {}
	if pack.moveClose == nil and set.headTo then pack.moveClose = true end
	UI.HeadRail.Pack(set, pack, self)
end

-- Regions only (textures, font strings): never a Blizzard frame.
function Kit:Place(region, width, height, ...)
	if not region then return end
	KeepPlace(Entry(self, region), region)
	region:ClearAllPoints()
	for i = 1, select("#", ...) do region:SetPoint(unpack((select(i, ...)))) end
	if width then region:SetWidth(width) end
	if height then region:SetHeight(height) end
end

function Kit:Bar(statusBar, opts)
	if not statusBar then return end
	local e = Entry(self, statusBar)
	if not e.bar then
		local fill = statusBar:GetStatusBarTexture()   -- nil on a bar that has none yet
		if fill then
			e.bar = AtlasOf(fill) or fill:GetTexture()
			e.barTiled = fill:GetHorizTile()
		end
	end
	Skin.HatchBar(statusBar)
	local track = opts and opts.track
	if track ~= false then return self:Track(statusBar, track) end
end

local NO_OPTS = {}   -- read only
function Kit:Art(texture, art, opts)
	if not texture then return end
	opts = opts or NO_OPTS
	local e = Entry(self, texture)
	-- Blizzard may have changed the atlas since the last call: restore to the current one. (The entry's own
	-- record of an atlas is written again in place: art the game sets anew at every refresh makes nothing here.)
	local atlas = AtlasOf(texture)
	if atlas then
		local was = e.art
		if was and was.atlas and Skin.FirstArt[texture] ~= was then was.atlas = atlas else e.art = { atlas = atlas } end
	elseif not e.art then
		-- The game's own, as the first kit to change it found it: a second kit finds it already painted (a flat color
		-- has no file), and putting that back would leave the game's art a block of its tint.
		e.art = Skin.FirstArt[texture] or { file = texture:GetTexture(), coords = { texture:GetTexCoord() } }
		Skin.FirstArt[texture] = e.art
	end
	if type(art) == "table" then
		Paint(texture, art)
	else
		if opts.tile then
			if e.tiled == nil then e.tiled = texture:GetHorizTile() end
			Tile(texture, art)
		else
			texture:SetTexture(art)
			if e.tiled ~= nil then texture:SetHorizTile(false) end   -- tiled by an earlier call
		end
		if opts.coords then
			texture:SetTexCoord(unpack(opts.coords))
		else
			texture:SetTexCoord(0, 1, 0, 1)
		end
	end
	if opts.slice then
		e.sliced = true
		texture:SetTextureSliceMargins(opts.slice, opts.slice, opts.slice, opts.slice)
	end
	if opts.blend then
		if not e.blend then e.blend = texture:GetBlendMode() end
		texture:SetBlendMode(opts.blend)
	end
	if opts.fit then
		KeepPlace(e, texture)
		Fit(texture, opts.fit, opts.x or 0, opts.y or 0)
	end
	if opts.color then self:Tint(texture, opts.color, true) end
end

-- Shy.Slot

local Slot = {}
Shy.Slot = Slot

Slot.SIZE, Slot.GAP = 37, 5   -- a bag slot and the gap between two
-- The sizes the drawn pieces are drawn for, in units: neighbours at most 1.23 times
-- apart, so a slot is never more than about a tenth off its drawing and its lines stay whole pixels.
Slot.LEVELS = { 18, 22, 26, 30, 37, 45 }
-- The sizes a slot is built at, by name: each a level, so its art is drawn exactly for it. Build with these,
-- never a number of your own.
Slot.SIZES = { tiny = 18, small = 22, compact = 26, medium = 30, bag = 37, button = 45 }
-- A stack count's text at each level: read on the picture without covering it (Slot.CountSize, slot:Count).
Slot.COUNT = { [18] = 9, [22] = 9, [26] = 10, [30] = 10, [37] = 11, [45] = 12 }
Slot.HALO = 3                 -- how far the halo reaches past the slot, in units (drawn into the halo piece)
Slot.INSIDE = 3               -- how far inside its slot an action button's cooldown sits (drawn into swipeIn)
-- A level's drawing stands in the top left of a power-of-two canvas: the share of it the drawing holds, for a
-- piece (2 texels a unit) and for a halo (the slot and its reach).
local DRAWN, HALO_DRAWN = {}, {}
for _, level in ipairs(Slot.LEVELS) do
	for _, out in ipairs({ { DRAWN, 2 * level }, { HALO_DRAWN, 2 * (level + 2 * Slot.HALO) } }) do
		local side, canvas = out[2], 32
		while canvas < side do canvas = canvas * 2 end
		out[1][level] = side / canvas
	end
end

-- The level a slot `units` across wears: the nearest by ratio.
function Slot.Level(units)
	local best, off = Slot.SIZE, math.huge
	for _, level in ipairs(Slot.LEVELS) do
		local d = math.abs(math.log(units / level))
		if d < off then best, off = level, d end
	end
	return best
end

-- A stack count's text size for a slot `units` across (a count of your own, beside a slot).
function Slot.CountSize(units)
	return Slot.COUNT[Slot.Level(units)]
end

Slot.SHAPES = {
	{ value = "now", text = "Square" },
	{ value = "cut", text = "Cut corners" },
	{ value = "pocket", text = "Pocket" },
}
Slot.DESC = "Square is the plain frame. Cut corners trims two opposite corners. Pocket has a rounded foot and shows quality and debuff colors on its top lip only."

-- The slot's finish: the look's own (Slot.Style() "auto"), or one picked from these on /shy or in the setup's
-- theme section (Slot.SetStyle). Each its own make, told apart at a glance: the frame piece (a shape's, see
-- SHAPES: the beveled frame, a glass rim, an obsidian bezel, an engraved line, a polished bezel, beveled
-- brackets, a sunken socket, or none), its color at rest and when the slot is empty (a name in Skin.colors,
-- "accent", a color, or a function giving one), the well's color when not the theme's, and when the halo of your color hugs the slot
-- ("rest", "hover": under the mouse alone, or never). Every one is modelled (lit from the top left), none a flat
-- line. By look: Forged the beveled steel frame, Glass a glass rim in steel, Frosted the engraved line in light,
-- Eclipse dark through and through (an obsidian bezel and a dark well, a filled slot the one bright thing; the
-- halo under the mouse), Stitched by its leather (a neon line in black hide, a saddle stitch, a gilt rule), Riveted a bezel of brushed steel with a
-- rivet at each corner (plain steel: the color is the icon's), Comic inked round by hand as its panels are (a
-- stroke a side, swelling and thinning, heavier down the shadow sides, crossing at the corners; your color's halo
-- under the mouse), Grove three vines braided round it in their own colors. A finish whose frame can't carry a mark
-- color (Inked's black ink a tint can't color; the Phosphor, Neon and Gilt frames' lines too fine to read, the Vine
-- frame's own colors) names the piece its mark goes on instead (`mark`: Inked's flat tone
-- inside the ink, the others' glowing band just inside the outline). The well under any finish is the look's own (GROUNDS).
local SLAB_WELL = { 0.05, 0.05, 0.06 }
-- Obsidian's tint: the art keeps its body near black and its rim light, so the tint is a mid grey.
local OBSIDIAN, OBSIDIAN_IDLE = { 0.62, 0.62, 0.68 }, { 0.42, 0.42, 0.46 }
local PLAIN_STEEL, PLAIN_STEEL_IDLE = { 0.80, 0.81, 0.84 }, { 0.52, 0.53, 0.56 }
-- Laced: the cord your color deepened, as the housings' lace is (it would crowd a bar of icons at full strength).
local function Laced()
	local r, g, b = Shy.Theme.Accent()
	return { r * 0.7, g * 0.7, b * 0.7 }
end
-- Gilt: the art's hide is dark and its rule light, so the tint is the gold itself.
local GILT, GILT_IDLE = { 0.88, 0.70, 0.34 }, { 0.55, 0.44, 0.22 }
-- Vine: drawn in its own colors (tinted white), a little dimmer round an empty slot.
local VINED, VINED_IDLE = { 1, 1, 1 }, { 0.72, 0.72, 0.72 }
-- Inked: the art is the ink alone, white, and its tint is the ink's own black (full or empty), so an item's
-- quality can color it as it does any frame. Black itself, nothing near it: the screen shows a dark tint lighter
-- than its number (0.03 came out a tenth, a grey line where the ink was black). Its well is your color deepened
-- toward a comic panel's night, so the ink reads round an empty slot as round a full one.
local INKED = { 0, 0, 0 }
local INK_WELL = { night = { 0.07, 0.072, 0.09 }, deep = 0.45 }
function INK_WELL.color()
	local r, g, b = Shy.Theme.Accent()
	local n, k = INK_WELL.night, INK_WELL.deep
	return { r + (n[1] - r) * k, g + (n[2] - g) * k, b + (n[3] - b) * k }
end
-- The wells, each the floor of a look's own material as its bars are (GROUND_BY_LOOK: whatever finish frames it).
-- Each is drawn in `hands` hands (a slot wears one, picked when it is made, so a grid of empty slots never repeats a
-- mark). Its art's body stands at `body` of its color, so the color is the theme's well lifted (lift) to put the body
-- where the plain well was and let the material's light show over it, or a color of its own: Eclipse's and
-- Charred's your color deepened (light leaking round a dark slab, fire in the cracks of char), Comic's your
-- color toward a panel's night, Salvage's a neutral grey (its rust is drawn in its own colors).
local function Lifted(k)
	return function()
		local w = Shy.Skin.colors.well
		return { math.min(1, w[1] * k), math.min(1, w[2] * k), math.min(1, w[3] * k) }
	end
end
local function Deepened(k)
	return function()
		local r, g, b = Shy.Theme.Accent()
		return { r * k, g * k, b * k }
	end
end
local GROUNDS = {
	forged = { file = "WellForged", hands = 1, body = 0.5, color = Lifted(2.0) },      -- a knurled steel floor
	glass = { file = "WellGlass", hands = 1, body = 0.45, color = Lifted(2.2) },       -- dark glass, a sheen across it
	frost = { file = "WellFrost", hands = 2, body = 0.42, color = Lifted(2.4) },       -- frosted glass, lit from the top
	obsidian = { file = "WellObsidian", hands = 1, body = 0.12, color = Deepened(0.62) },   -- a dark slab, your color round its edge
	hide = { file = "WellHide", hands = 1, body = 0.38, color = Lifted(2.6) },         -- padded leather, its grain pressed in
	brushed = { file = "WellBrushed", hands = 1, body = 0.5, color = Lifted(2.0) },    -- brushed steel, sunk under its bezel
	bronze = { file = "WellBronze", hands = 2, body = 0.5, color = Lifted(2.0) },      -- hammered bronze
	rust = { file = "WellRust", hands = 3, body = 0.36, color = { 0.50, 0.49, 0.48 } },   -- scrap steel, rust blooming on it
	char = { file = "WellChar", hands = 3, body = 0.15, color = Deepened(0.55) },      -- char, fire in its cracks
	ink = { file = "WellInk", hands = 3, body = 0.64, color = INK_WELL.color },        -- brushed, a dry glint across it
	scales = { file = "WellScales", hands = 1, body = 0.42, color = Lifted(2.6) },     -- black reptile hide
	bound = { file = "WellBound", hands = 1, body = 0.42, color = Deepened(0.5) },     -- polished leather, dyed deep
	rain = { file = "WellRain", hands = 3, body = 0.12, color = Deepened(0.6) },       -- a dark screen, a little rain in it
	moss = { file = "WellMoss", hands = 3, body = 0.4, color = { 0.40, 0.62, 0.36 } }, -- dark loam, moss grown over it
	galaxy = { file = "WellGalaxy", hands = 3, body = 0.5, color = { 0.5, 0.5, 0.5 } },  -- deep space in black glass (in its own colors)
}
Slot.GROUNDS = GROUNDS
-- A look of its own file says its own (UI.LookKind's `ground`: a key, or a function giving one by its options).
local GROUND_BY_LOOK = setmetatable({ forged = "forged", steel = "glass", clear = "frost", eclipse = "obsidian", riveted = "brushed" },
	{ __index = function(_, look)
		local kind = Shy.UI.LOOK_KINDS[look]
		local pick = kind and kind.ground
		if type(pick) == "function" then pick = pick() end
		return GROUNDS[pick] and pick or nil
	end })
Slot.STYLES = {
	{ key = "bevel", name = "Beveled", piece = "frame", color = "metal", empty = "idle" },
	{ key = "hairline", name = "Glass rim", piece = "glass", color = "metal", empty = "idle" },
	{ key = "etched", name = "Etched", piece = "double", color = "lit", empty = "idle" },
	{ key = "dark", name = "Dark", piece = "obsidian", color = OBSIDIAN, empty = OBSIDIAN_IDLE, well = SLAB_WELL, halo = "hover" },
	{ key = "lit", name = "Lit", piece = "obsidian", color = OBSIDIAN, empty = OBSIDIAN_IDLE, well = SLAB_WELL, halo = "rest" },
	{ key = "band", name = "Steel band", piece = "band", color = "metal", empty = "idle" },
	{ key = "corners", name = "Corners", piece = "corners", color = "accent", empty = "accent" },
	{ key = "sunken", name = "Sunken", piece = "inset", color = "metal", empty = "idle", well = SLAB_WELL },
	{ key = "stitched", name = "Stitched", piece = "stitch", color = "accent", empty = "accent", well = SLAB_WELL },
	{ key = "laced", name = "Laced", piece = "lace", color = Laced, empty = Laced, well = SLAB_WELL },
	{ key = "saddle", name = "Saddle stitch", piece = "saddle", color = "accent", empty = "accent", well = SLAB_WELL },
	{ key = "gilt", name = "Gilt", piece = "gilt", color = GILT, empty = GILT_IDLE, well = SLAB_WELL, mark = "markBand" },
	{ key = "neon", name = "Neon", piece = "neon", color = "accent", empty = Laced, well = SLAB_WELL, mark = "markBand" },
	{ key = "phosphor", name = "Phosphor", piece = "phosphor", color = "accent", empty = Laced, well = SLAB_WELL, mark = "markBand" },
	{ key = "vine", name = "Vine", piece = "vine", color = VINED, empty = VINED_IDLE, well = SLAB_WELL, mark = "markBand", own = true },
	{ key = "riveted", name = "Riveted", piece = "plate", color = PLAIN_STEEL, empty = PLAIN_STEEL_IDLE },
	{ key = "inked", name = "Inked", piece = "ink", color = INKED, empty = INKED, well = INK_WELL.color, halo = "hover", mark = "inkTone" },
	{ key = "none", name = "No frame", piece = false, color = "metal", empty = "idle" },
}
local STYLE_BY_KEY = {}
for _, style in ipairs(Slot.STYLES) do STYLE_BY_KEY[style.key] = style end
-- A look of its own file says its own (UI.LookKind's `slot`).
local STYLE_BY_LOOK = setmetatable({ forged = "bevel", steel = "hairline", clear = "etched", eclipse = "dark", riveted = "riveted" },
	{ __index = function(_, look)
		local kind = Shy.UI.LOOK_KINDS[look]
		local pick = kind and kind.slot
		if type(pick) == "function" then pick = pick() end
		return STYLE_BY_KEY[pick] and pick or nil
	end })

local MEDIA = Shy.MEDIA
local SOLID = "Interface\\Buttons\\WHITE8X8"
local SHADE = { 0, 0, 0, 0.64 }   -- the default swipe color (CooldownFrameTemplate)

-- A shape's pieces (a drawn one's file is its name and a level, Slot.LEVELS):
--   frame, well, glow   nine slices, or art drawn for the shape
--   flat                hairline frame, for display-only slots (a remembered slot: a print of the hardware)
--   new                 the "new item" line inside the frame
--   lip                 takes the mark color instead of the frame
--   mask                clips the icon
--   swipe, swipeIn      cooldown swipe: filling the slot, or 3 units inside it
--   ring                the frame's band alone: a bezel that runs out
--   halo                light round the slot, past it by Slot.HALO
--   count               stack count offset from the bottom right, in a 37-unit slot
--   square              which corners are square
--   band, glass, obsidian, double, corners, inset, stitch, plate, ink, lace, saddle, gilt   the finishes' frames
--                       (Slot.STYLES): a polished bezel, a glass rim, an obsidian bezel, an engraved line, beveled
--                       brackets, a sunken socket, a band of hide sewn round, a riveted bezel, a line inked by hand, a
--                       cord laced over hide, a saddle stitch, a gilt rule in polished hide, a neon line in black hide
--   inkTone             the flat color inside the ink, where an inked slot's mark (a debuff's kind) shows
--   markBand            a glowing band just inside the outline, where a fine-lined finish's mark shows
--   quality, glint      an item's quality (slot:Quality): a line of its color round the slot's outer edge, and the
--                       light that line catches (the pocket has no line: its lip carries the color)
local EVERY = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
local DRAWN_PIECES = { "flat", "new", "ring", "halo", "band", "glass", "obsidian", "double", "corners", "inset", "stitch", "plate", "ink", "inkTone",
	"lace", "saddle", "gilt", "neon", "phosphor", "vine", "markBand", "quality", "glint" }
local FILES = { flat = "Flat", new = "New", ring = "Ring", halo = "Halo", band = "Band", glass = "Glass", obsidian = "Obsidian",
	double = "Double", corners = "Corners", inset = "Inset", stitch = "Stitch", plate = "Plate", ink = "Ink", inkTone = "InkTone",
	lace = "Lace", saddle = "Saddle", gilt = "Gilt", neon = "Neon", phosphor = "Phosphor", vine = "Vine", markBand = "MarkBand",
	quality = "Quality", glint = "Glint",
	frame = "Frame", well = "Well", glow = "Glow", mask = "Mask", swipe = "Swipe", swipeIn = "SwipeIn", lip = "Lip" }
-- A themed well's hands: pieces "ground<key>", "ground<key>2", ... (files <Shape><file>, <Shape><file>2, ...).
local function GroundPiece(key, hand)
	return "ground" .. key .. (hand > 1 and hand or "")
end
for key, ground in pairs(GROUNDS) do
	for hand = 1, ground.hands do
		local piece = GroundPiece(key, hand)
		DRAWN_PIECES[#DRAWN_PIECES + 1] = piece
		FILES[piece] = ground.file .. (hand > 1 and hand or "")
	end
end
local function Pieces(name, own)
	local shape = own
	for _, piece in ipairs(DRAWN_PIECES) do shape[piece] = MEDIA .. name .. FILES[piece] end
	for _, piece in ipairs({ "frame", "well", "glow", "mask", "swipe", "swipeIn" }) do
		if shape[piece] == true then shape[piece] = MEDIA .. name .. FILES[piece] end
	end
	return shape
end
local SHAPES = {
	now = Pieces("SlotNow", { frame = Skin.FRAME, well = Skin.WELL, glow = Skin.GLOW, count = { 3, 2 }, square = EVERY }),
	cut = Pieces("SlotCut", { frame = true, well = true, glow = true, mask = true, swipe = true, swipeIn = true,
		count = { 5, 2 }, square = { TOPRIGHT = true, BOTTOMLEFT = true } }),
	pocket = Pieces("SlotPocket", { frame = true, well = true, glow = true, mask = true, swipe = true, swipeIn = true,
		lip = MEDIA .. "SlotPocketLip", count = { 5, 3 }, square = { TOPLEFT = true, TOPRIGHT = true } }),
}
local SLICE = { [Skin.FRAME] = FRAME_SLICE, [Skin.WELL] = WELL_SLICE, [Skin.GLOW] = GLOW_SLICE }

local slots = setmetatable({}, { __mode = "k" })       -- every slot, for shape changes
-- A slot lives as long as its pieces do: a caller may keep no hold of the slot it made, and the game never
-- collects a texture, so the slot is kept by its well (weak keys; the slot itself is held).
local heldBy = setmetatable({}, { __mode = "k" })
local following = setmetatable({}, { __mode = "k" })   -- texture -> { piece, to, x, y, size }
local shaded = setmetatable({}, { __mode = "k" })      -- cooldown -> its swipe settings

function Slot.Shape()
	local db = Shy.core.db
	local key = db and db.slot
	return SHAPES[key] and key or "now"
end

-- The finish picked: a key of Slot.STYLES, or "auto" (the look's own).
function Slot.Style()
	local db = Shy.core.db
	local key = db and db.slotStyle
	return STYLE_BY_KEY[key] and key or "auto"
end

-- The finish a look wears: the pick (or `pick`, one shown before it is made), or with "auto" the look's own.
function Slot.StyleFor(look, pick)
	local key = pick or Slot.Style()
	if key == "auto" or not STYLE_BY_KEY[key] then key = STYLE_BY_LOOK[look or Shy.Theme.Look()] or "bevel" end
	return STYLE_BY_KEY[key]
end

-- The well a look's slots have under whatever finish frames them: a key of Slot.GROUNDS, or nil for the plain well.
function Slot.GroundFor(look)
	return GROUND_BY_LOOK[look or Shy.Theme.Look()]
end

local function Shape()
	return SHAPES[Slot.Shape()]
end

function Slot.Lipped()
	return Shape().lip ~= nil
end

-- Where a stack count stands in a slot of the shape worn: in from its right edge, up from its foot (slot:Count seats
-- its own there; a count of the game's is placed there through a kit).
function Slot.CountSeat()
	local at = Shape().count
	return at[1], at[2]
end

-- The piece a mark color goes on when it isn't the frame: the shape's lip, else the finish's own (nil: the frame).
-- A slot showing only a print of itself (flat) or no frame at all keeps it on the frame.
local function MarkPiece(shape, style, flat)
	if shape.lip then return "lip" end
	if flat or style.piece == false then return nil end
	return style.mark
end

-- Does a mark color go on a piece of its own (a lip, an inked slot's tone), the frame keeping its own color?
function Slot.MarkApart()
	return MarkPiece(Shape(), Slot.StyleFor()) ~= nil
end

function Slot.Square(point)
	return Shape().square[point] == true
end

-- Without `to` the region keeps its anchors.
local function Over(region, to, x, y)
	if not to then return end
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", to, "TOPLEFT", x, -y)
	region:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -x, y)
end

-- The level of a slot covering `to` inset by x: the size it was told (its caller knows it before the game has laid
-- the region out), else its measured width, else a bag slot's.
local function LevelOf(to, x, size)
	if size then return Slot.Level(size) end
	local ok, width = Read(to, "GetWidth")
	width = (ok and width or 0) - 2 * (x or 0)
	return Slot.Level(width > 0 and width or Slot.SIZE)
end

-- A nine slice is fitted to the region. A drawn piece shows its level's drawing (the top left of its canvas)
-- stretched over the region, so the shape keeps its proportions and its lines their width.
local function Lay(texture, shape, piece, to, x, y, level)
	if piece == "mark" then piece = MarkPiece(shape, Slot.StyleFor()) or "frame" end
	-- Art following a slot's frame wears the finish's own frame (none for no frame).
	if piece == "frame" then
		local finish = Slot.StyleFor().piece
		if not finish then
			texture:SetTexture(nil)
			return
		end
		piece = finish
	end
	local file = shape[piece]
	local slice = SLICE[file]
	Over(texture, to, x, y)
	if slice then
		texture:SetTexture(file)
		texture:SetTexCoord(0, 1, 0, 1)
		texture:SetTextureSliceMargins(slice, slice, slice, slice)
	else
		texture:SetTexture(file .. level)
		texture:ClearTextureSlice()
		local d = (piece == "halo" and HALO_DRAWN or DRAWN)[level]
		texture:SetTexCoord(0, d, 0, d)
	end
end

-- A mask shows its level's drawing as the pieces do. The square shape has none, so a solid texture stands in.
local function LayMask(mask, shape, to, x, y, level)
	if shape.mask then
		mask:SetTexture(shape.mask .. level, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetTexCoord(0, DRAWN[level], 0, DRAWN[level])
	else
		mask:SetTexture(Skin.WELL, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetTexCoord(0, 1, 0, 1)
	end
	Over(mask, to, x, y)
end

local function LayFollower(texture, f)
	local shape = Shape()
	local level = LevelOf(f.to or texture, f.x, f.size)
	if f.piece == "mask" then
		LayMask(texture, shape, f.to, f.x, f.y, level)
	else
		Lay(texture, shape, f.piece, f.to, f.x, f.y, level)
	end
end

-- piece: "glow", "frame", "well", "mark" (whichever piece takes a color: the frame, a lip, an inked slot's tone) or
-- "mask".
-- to: region to cover, inset by x, y; nil keeps the texture's anchors. size: the slot's width in units (else
-- measured).
function Slot.Follow(texture, piece, to, x, y, size)
	local f = { piece = piece, to = to, x = x or 0, y = y or 0, size = size }
	following[texture] = f
	LayFollower(texture, f)
end

function Slot.Unfollow(texture)
	following[texture] = nil
end

-- The swipe shows its level's drawing (the cooldown's own size) through the cooldown's texture coordinates.
local WHOLE, ORIGIN = nil, nil
local function Shade(cooldown, f)
	local shape = Shape()
	local file = (f.ring and shape.ring) or (f.inside and shape.swipeIn) or (not f.inside and shape.swipe) or nil
	if not file and not f.ours and not f.square then return end   -- square shape and still the default swipe
	f.ours = file ~= nil or f.square ~= nil
	ORIGIN = ORIGIN or CreateVector2D(0, 0)
	if file then
		local level = LevelOf(cooldown, f.inside and -Slot.INSIDE or 0, f.size)   -- an inside one: the slot round it
		cooldown:SetSwipeTexture(file .. level, f[1], f[2], f[3], f[4])
		cooldown:SetTexCoordRange(ORIGIN, CreateVector2D(DRAWN[level], DRAWN[level]))
	else
		WHOLE = WHOLE or CreateVector2D(1, 1)
		cooldown:SetSwipeTexture(f.square or SOLID, f[1], f[2], f[3], f[4])
		cooldown:SetTexCoordRange(ORIGIN, WHOLE)
	end
end

-- What a cooldown was told, kept for the next change of shape.
local function Shaded(cooldown, opts)
	local f = shaded[cooldown] or {}
	shaded[cooldown] = f
	local color = opts.color or SHADE
	f[1], f[2], f[3], f[4] = color[1], color[2], color[3], color[4] or 1
	f.size = opts.size or f.size
	return f
end

-- The cooldown's shade in the slot's shape. opts (all optional):
--   inside  the cooldown sits Slot.INSIDE units inside its button (action buttons)
--   color   { r, g, b, a } (the game's own dark)
--   square  the swipe's art for the square shape, which has none of its own (else a solid one)
--   size    the slot's width in units, kept until another is given (else the cooldown's, measured)
-- A swipe texture can't be read back, so restoring sets the solid default.
function Slot.Swipe(cooldown, opts)
	opts = opts or {}
	local f = Shaded(cooldown, opts)
	f.inside, f.ring, f.square = opts.inside, nil, opts.square
	Shade(cooldown, f)
end

-- A bezel: the cooldown swipes the slot frame's band alone, so the frame itself runs out round the icon
-- (for the time left, leave the cooldown unreversed). opts: color { r, g, b, a }, size (as Slot.Swipe's).
-- Follows shape changes as Slot.Swipe does.
function Slot.Ring(cooldown, opts)
	local f = Shaded(cooldown, opts)
	f.ring, f.inside = true, nil
	Shade(cooldown, f)
end

function Slot.Unswipe(cooldown)
	local f = shaded[cooldown]
	if not f then return end
	shaded[cooldown] = nil
	if f.ours then
		cooldown:SetSwipeTexture(SOLID, f[1], f[2], f[3], f[4])
		cooldown:SetTexCoordRange(CreateVector2D(0, 0), CreateVector2D(1, 1))
	end
end

-- Keeps the region's alpha. Only a slot's own pieces come here: what each was last given is kept on it,
-- and the same color isn't set twice.
local function Tinted(region, c)
	local r, g, b = c[1], c[2], c[3]
	if region.shyR == r and region.shyG == g and region.shyB == b then return end
	region.shyR, region.shyG, region.shyB = r, g, b
	local alpha = region:GetAlpha()
	region:SetVertexColor(r, g, b)
	region:SetAlpha(alpha)
end

local SlotMixin = {}
SlotMixin.__index = SlotMixin

-- The slot wears the finish (Slot.STYLES: the look's own, or the one picked). The mark and the steel colors
-- still go on the frame. The halo is light round the outside of the slot (its own piece, reaching Slot.HALO past
-- it, nothing over the picture), added to what is under it: on the slot's own layer when the finish has it at
-- rest, on the highlight layer when under the mouse alone.
local HALO_ALPHA = 0.7

local function Look()
	return Shy.Theme.Look()
end

local function StyleOf(slot)
	return slot.style or Slot.StyleFor(slot.lookFixed or Look(), slot.styleKey)
end

-- The frame's piece for the finish: nil for none.
local function FrameFor(slot, style)
	if style.piece == false then return nil end
	if slot.flat then return "flat" end
	return style.piece
end

-- A finish's color: a name in the theme's colors, your accent, or a color of its own.
local function Hue(c)
	if c == "accent" then return { Shy.Theme.Accent() } end
	if type(c) == "function" then return c() end
	if type(c) == "string" then return C[c] end
	return c
end

-- A glazed slot's well (opts.glazed) is as clear as the Background setting makes the pieces round it, never
-- clearer than GLAZE: an empty slot still reads on a clear piece.
local GLAZE = 0.35

-- A frame wearing no mark carries no more color than the steel does (CALM: the most chroma it keeps, the steel's
-- share of your color at most), drawn toward its own grey: hues belong to the marks, so a plain item never reads as
-- a green, blue or gold one whatever your color or the finish.
local CALM = 0.16
local calm = {}
local function Calm(c)
	local r, g, b = c[1], c[2], c[3]
	local chroma = math.max(r, g, b) - math.min(r, g, b)
	if chroma <= CALM then return c end
	local y, k = 0.299 * r + 0.587 * g + 0.114 * b, CALM / chroma
	calm[1], calm[2], calm[3] = y + (r - y) * k, y + (g - y) * k, y + (b - y) * k
	return calm
end

-- An item's quality (slot:Quality). The picture is the star, so a quality is said at the slot's rim and outside it:
-- from uncommon up a line of the color round the outer edge (the `quality` piece) with the light it catches (`glint`,
-- added, in a lighter tint), the frame inside it leaning to the quality's color a shade deeper (tone, depth), and a
-- soft light round the slot (the halo, in the color), stronger the rarer (bloom, from uncommon). A white item's
-- frame is the theme's steel a little under its full light (white: the share it keeps, so the frame stands back
-- from the picture); a grey one's that steel gone dull and dark (dull: the color it keeps; worn: how far it goes
-- to pewter). So a border says white, grey, green, blue in every look alike: an item's frame wears its
-- quality over steel whatever the finish wears empty (the Comic look's ink is black round an empty slot, light
-- round a white item). Every finish's frame takes it: a frame is art in one color (a finish drawn in several,
-- `own`, keeps them under the line). The pocket carries the color on its lip; a print (flat) on its hairline.
local QUALITY = {
	glint = 0.55, light = 0.55, tone = 0.55, depth = 0.78, white = 0.8, dull = 0.5, worn = 0.9, pewter = { 0.15, 0.15, 0.17 },
	bloom = { 0.16, 0.30, 0.42, 0.55 },
	faint = 0.42, faintNew = 0.22,   -- a dimmed slot's pieces (slot:Dim)
	colors = {},                     -- quality -> { line = the color as worn, light = the glint's tint }
}

-- The game's color for a quality (the player's own, if they changed it) as the line wears it: its hue, its
-- strongest channel whole, so rare's deep blue reads on graphite. Nil for a quality with no color of its own.
function QUALITY.Jewel(quality)
	local data = ColorManager.GetColorDataForBagItemQuality(quality)
	if not data then return nil end
	local r, g, b = data.r, data.g, data.b
	local c = QUALITY.colors[quality]
	if not c then
		c = { line = {}, light = {} }
		QUALITY.colors[quality] = c
	end
	if c.r ~= r or c.g ~= g or c.b ~= b then
		c.r, c.g, c.b = r, g, b
		local most = math.max(r, g, b)
		local k = most > 0 and 1 / most or 1
		local line, light = c.line, c.light
		line[1], line[2], line[3] = r * k, g * k, b * k
		for i = 1, 3 do light[i] = line[i] + (1 - line[i]) * QUALITY.light end
	end
	return c
end

-- The frame's color under a quality: leaning to the line's color and deeper; (white) a white item's, the steel a
-- little under its light; or (neither: a grey item's) dull and dark.
function QUALITY.Frame(slot, base, line, white)
	local out = slot.toned or {}
	slot.toned = out
	if line then
		for i = 1, 3 do out[i] = (base[i] + (line[i] - base[i]) * QUALITY.tone) * QUALITY.depth end
	elseif white then
		for i = 1, 3 do out[i] = base[i] * QUALITY.white end
	else
		local y = 0.299 * base[1] + 0.587 * base[2] + 0.114 * base[3]
		for i = 1, 3 do
			local c = y + (base[i] - y) * QUALITY.dull
			out[i] = c + (QUALITY.pewter[i] - c) * QUALITY.worn
		end
	end
	return out
end

-- The line and its glint, made when a slot first has a quality to show, and laid again with the slot.
function QUALITY.Lay(slot)
	if not slot.gem then
		slot.gem = slot.owner:CreateTexture(nil, "OVERLAY", nil, -8)
		slot.glint = slot.owner:CreateTexture(nil, "OVERLAY", nil, -7)
		slot.glint:SetBlendMode("ADD")
		slot[#slot + 1], slot[#slot + 2] = slot.gem, slot.glint
	end
	local shape = slot.shape
	if not shape.lip then Lay(slot.gem, shape, "quality", slot.to, slot.x, slot.y, slot.level) end
	Lay(slot.glint, shape, "glint", slot.to, slot.x, slot.y, slot.level)
end

-- The mark color goes on a piece of its own when there is one (the shape's lip, an inked slot's tone; slot.lip
-- wears it), else on the frame.
local function Colors(slot)
	local shape, mark, off = slot.shape, slot.mark, slot.off
	local style = StyleOf(slot)
	-- A mark speaks first; a quality only on a slot that shows its frame.
	local quality = not mark and not slot.bare and not off and slot.quality or nil
	local jewel = quality and quality > Enum.ItemQuality.Common and QUALITY.Jewel(quality) or nil
	local apart = jewel ~= nil and slot.markPiece ~= nil and shape.lip ~= nil
	local lined = jewel ~= nil and not apart and not slot.flat
	local lipped = (mark ~= nil or apart) and slot.markPiece ~= nil
	-- The look's well in its own color; a color the caller asked for lifted as the art's body asks (the body where
	-- that color would be); with no well of the look's, the finish's or the theme's.
	local ground = slot.ground and GROUNDS[slot.ground]
	local well = slot.fill or (ground and ground.color) or style.well or C.well
	if type(well) == "function" then well = well() end
	if slot.fill and ground then
		local k = 1 / ground.body
		slot.lifted = slot.lifted or {}
		slot.lifted[1], slot.lifted[2], slot.lifted[3] = math.min(1, well[1] * k), math.min(1, well[2] * k), math.min(1, well[3] * k)
		well = slot.lifted
	end
	Tinted(slot.well, well)
	-- As opaque as the Icon wells setting asks (Slot.WellArt), and a glazed one as clear as the Background makes it.
	slot.well:SetAlpha((slot.glazed and GLAZE + (1 - GLAZE) * Shy.Theme.Strength() or 1) * Slot.WellArt())
	local frame = (mark and not lipped and mark) or slot.steel
	if not frame then
		frame = Calm((slot.empty and Hue(style.empty)) or Hue(style.color))
		if quality ~= nil and not slot.empty then
			-- A slot holding an item says its quality on its frame, in every finish alike: the frame wears the theme's
			-- steel (a white item's: a little under its light), that steel dull and dark (a grey one's) or leaning to the quality's color,
			-- whatever color the finish wears empty (the ink's black, a look's own color). A finish drawn in several
			-- colors keeps them, dulled for a grey item.
			local steel = style.own and frame or C.metal
			if jewel and slot.flat then
				frame = jewel.line
			elseif lined and not style.own then
				frame = QUALITY.Frame(slot, steel, jewel.line)
			elseif quality == Enum.ItemQuality.Poor then
				frame = QUALITY.Frame(slot, steel)
			elseif style.own then
				frame = steel
			else
				frame = QUALITY.Frame(slot, steel, nil, true)
			end
		end
	end
	Tinted(slot.frame, frame)
	Tinted(slot.hover, C.hover)
	Tinted(slot.new, UI.colors.hot)
	if lipped then Tinted(slot.lip, mark or jewel.line) end
	slot.well:SetShown(not off and slot.showWell)
	slot.frame:SetShown(not off and not slot.bare and style.piece ~= false)
	slot.hover:SetShown(not off and slot.showHover)
	slot.lip:SetShown(not off and lipped and not slot.bare)
	slot.new:SetShown(not off and slot.fresh == true)
	-- The quality's line (none on a pocket: its lip has the color) and the light on it.
	local lit = jewel ~= nil and not slot.flat and (lined or shape.lip ~= nil)
	if lit and not slot.gem then QUALITY.Lay(slot) end
	if slot.gem then
		if lit then
			Tinted(slot.gem, jewel.line)
			Tinted(slot.glint, jewel.light)
			slot.gem:SetAlpha(slot.dim and QUALITY.faint or 1)
			slot.glint:SetAlpha(slot.dim and 0 or QUALITY.glint)
		end
		slot.gem:SetShown(lined)
		slot.glint:SetShown(lit)
	end
	-- The halo: the finish's, in your color; a quality's light round the slot comes before it, in the quality's.
	local bloom = lit and not slot.dim and QUALITY.bloom[math.min(quality - Enum.ItemQuality.Common, #QUALITY.bloom)] or nil
	local halo = style.halo
	Tinted(slot.halo, bloom and jewel.line or { Shy.Theme.Accent() })
	slot.halo:SetAlpha(bloom or HALO_ALPHA)
	if halo == "hover" and not bloom then slot.halo:SetDrawLayer("HIGHLIGHT", 1) else slot.halo:SetDrawLayer("ARTWORK", 6) end
	slot.halo:SetShown(not off and not slot.bare and (bloom ~= nil or (halo ~= nil and (halo ~= "hover" or slot.showHover))))
end

local function PlaceCount(slot)
	local count, at = slot.count, slot.shape.count
	if not count then return end
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", slot.to, "BOTTOMRIGHT", -at[1] - slot.x, at[2] + slot.y)
end

-- slot.clipped: region -> whether it has the mask now.
local function Clip(slot)
	local shape = slot.shape
	local on = shape.mask ~= nil and not slot.off
	if on then LayMask(slot.mask, shape, slot.to, slot.x, slot.y, slot.level) end
	-- Under pcall: some Blizzard textures refuse a mask (some target auras) and stay square.
	for region, wears in pairs(slot.clipped) do
		if on and not wears then
			slot.clipped[region] = pcall(region.AddMaskTexture, region, slot.mask)
		elseif wears and not on then
			pcall(region.RemoveMaskTexture, region, slot.mask)
			slot.clipped[region] = false
		end
	end
end

local function Dress(slot)
	local shape = Shape()
	local to, x, y, level = slot.to, slot.x, slot.y, slot.level
	local look = slot.lookFixed or Look()
	local style = Slot.StyleFor(look, slot.styleKey)
	slot.shape, slot.look, slot.style = shape, look, style
	-- The well: the look's own in the slot's hand, else the plain one.
	slot.ground = GROUND_BY_LOOK[look]
	local ground = slot.ground and GROUNDS[slot.ground]
	Lay(slot.well, shape, ground and GroundPiece(slot.ground, (slot.hand - 1) % ground.hands + 1) or "well", to, x, y, level)
	local piece = FrameFor(slot, style)
	if piece then Lay(slot.frame, shape, piece, to, x, y, level) end
	Lay(slot.new, shape, "new", to, x, y, level)
	Lay(slot.hover, shape, "glow", to, x, y, level)
	Lay(slot.halo, shape, "halo", to, x - Slot.HALO, y - Slot.HALO, level)
	-- The piece a mark goes on, when not the frame: the lip or the finish's own (under Blizzard's overlays either way).
	slot.markPiece = MarkPiece(shape, style, slot.flat)
	if slot.markPiece then Lay(slot.lip, shape, slot.markPiece, to, x, y, level) end
	if slot.gem then QUALITY.Lay(slot) end
	Clip(slot)
	PlaceCount(slot)
	Colors(slot)
end

--   local slot = Shy.Slot.New(owner, opts)
-- Textures only, so a protected Blizzard button is a safe owner. opts (all optional; slot:Set takes the same):
--   to           region to cover instead of the owner (an icon inside a bigger button)
--   x, y         inset
--   icon         the icon texture: masked to the shape
--   size         its width in units (else measured from the region): picks the level drawn for it
--   flat         hairline frame, for display-only slots
--   well, hover  false for none
--   color        frame color override
--   fill         well color
--   style        a finish of its own (a key of Slot.STYLES) whatever the look's
--   glazed       the well as clear as the Background setting makes the pieces round it (a slot on a piece that
--                follows that setting: the bags), never clearer than GLAZE
-- The hand a new slot's well is drawn in: a sequence that wanders (Park and Miller's), so neighbours made one after
-- another in a grid don't fall into a pattern.
local HANDS = { seed = 20261108, a = 16807, m = 2147483647, of = 6 }
local function NextHand()
	HANDS.seed = HANDS.seed * HANDS.a % HANDS.m
	return HANDS.seed % HANDS.of + 1
end

function Slot.New(owner, opts)
	local slot = setmetatable({ owner = owner, clipped = {}, hand = NextHand() }, SlotMixin)
	local function Piece(name, layer, sublevel)
		local t = owner:CreateTexture(nil, layer, nil, sublevel)
		slot[#slot + 1] = t   -- array part: a kit shows and hides the pieces through it
		slot[name] = t
		return t
	end
	Piece("well", "BACKGROUND", -8)
	-- Above the icon, below Blizzard's own overlays (quality, equipped, new).
	Piece("frame", "ARTWORK", 7)
	Piece("lip", "OVERLAY", -8)
	Piece("new", "OVERLAY", -7)
	Piece("hover", "HIGHLIGHT", 0):SetBlendMode("BLEND")
	local halo = Piece("halo", "ARTWORK", 6)
	halo:SetBlendMode("ADD")
	halo:SetAlpha(HALO_ALPHA)
	slot.mask = owner:CreateMaskTexture()
	slots[slot] = true
	heldBy[slot.well] = slot
	slot:Set(opts)
	return slot
end

-- Set again as it stands (the skins set every slot again on each update of the game's buttons), it lays
-- nothing out again.
function SlotMixin:Set(opts)
	opts = opts or {}
	local to, x, y = opts.to or self.owner, opts.x or 0, opts.y or 0
	local flat = opts.flat and true or false
	-- The level drawn nearest its width: measured, else the size it was told.
	local level = LevelOf(to, x, opts.size)
	local showWell, showHover = opts.well ~= false, opts.hover ~= false
	local look = opts.look or Look()
	local glazed = opts.glazed and true or false
	local same = self.dressed and not self.off and self.shape == Shape() and self.look == look and self.to == to and self.x == x and self.y == y
		and self.flat == flat and self.level == level and self.showWell == showWell and self.showHover == showHover
		and self.steel == opts.color and self.fill == opts.fill and (not opts.icon or self.clipped[opts.icon] ~= nil)
		and self.lookFixed == opts.look and self.styleKey == opts.style and self.glazed == glazed
	if same then return end
	self.to, self.x, self.y, self.flat, self.level, self.glazed = to, x, y, flat, level, glazed
	self.showWell, self.showHover = showWell, showHover
	self.steel, self.fill = opts.color, opts.fill
	self.lookFixed, self.styleKey = opts.look, opts.style
	self.off = false
	if opts.icon and self.clipped[opts.icon] == nil then self.clipped[opts.icon] = false end
	Dress(self)
	self.dressed = true
end

function SlotMixin:Mark(r, g, b)
	local mark = self.mark
	if r == nil then
		if mark == nil then return end
		self.mark = nil
	elseif mark and mark[1] == r and mark[2] == g and mark[3] == b then
		return
	elseif mark then
		mark[1], mark[2], mark[3] = r, g, b   -- its own list, written in place
	else
		self.mark = { r, g, b }
	end
	Colors(self)
end

-- An item's quality (Enum.ItemQuality), or nil for none: see QUALITY. A value the game keeps back says nothing.
function SlotMixin:Quality(quality)
	if quality ~= nil and (issecretvalue(quality) or type(quality) ~= "number") then quality = nil end
	if self.quality == quality then return end
	self.quality = quality
	Colors(self)
end

-- Dimmed: what the slot holds is not what is looked for (a search, a bag in focus). Its frame goes grey and
-- faint, its quality keeps a faint line and gives up its light.
function SlotMixin:Dim(dim)
	dim = dim and true or false
	if self.dim == dim then return end
	self.dim = dim
	local faint = dim and QUALITY.faint or 1
	self.frame:SetDesaturated(dim)
	self.frame:SetAlpha(faint)
	self.lip:SetAlpha(faint)
	self.new:SetAlpha(dim and QUALITY.faintNew or 1)
	Colors(self)
end

function SlotMixin:Steel(color)
	if self.steel == color then return end
	self.steel = color
	Colors(self)
end

function SlotMixin:Empty(empty)
	empty = empty and true or false
	if self.empty == empty then return end
	self.empty = empty
	Colors(self)
end

function SlotMixin:Bare(bare)
	bare = bare and true or false
	if self.bare == bare then return end
	self.bare = bare
	Colors(self)
end

function SlotMixin:Fresh(fresh)
	fresh = fresh and true or false
	if self.fresh == fresh then return end
	self.fresh = fresh
	Colors(self)
end

function SlotMixin:Clip(region)
	if self.clipped[region] ~= nil then return end
	self.clipped[region] = false
	Clip(self)
end

function SlotMixin:Light(texture, color)
	texture:SetBlendMode("BLEND")
	Slot.Follow(texture, "glow", self.to, self.x, self.y, self.level)
	if color then UI.Tint(texture, color) end
end

-- Its text sized for the slot's level (Slot.COUNT).
function SlotMixin:Count(fontString)
	self.count = fontString
	fontString:SetFont(Shy.FONT_ROUNDED, Slot.COUNT[self.level], "OUTLINE")
	PlaceCount(self)
end

-- Called by Kit:Restore: hides every piece and removes the masks.
function SlotMixin:Undress()
	self.off = true
	self.mark, self.quality, self.empty, self.bare, self.fresh = nil, nil, false, false, false
	Clip(self)
	wipe(self.clipped)
	Colors(self)
end

-- Pins: what stands on a slot's corner to say something of the thing in it. Each is one small picture in its own
-- colors with nothing under it (SlotPins.tga, a cell each), so the picture shows all round it; every addon's marks
-- on an icon are these. A quest's stone is one mark in three states, each a shape of its own (never told apart by
-- color alone): whole and gold (quest, needed), gold in outline (ahead), broken and red (over).
--   local pin = Shy.Slot.Pin(host, anchor, corner, size)   -- a texture on `host` (never a frame: a bag's slot is a
--                                       -- protected button), on that corner of `anchor` (the host's own);
--                                       -- corner nil: the kind's own. size: Slot.PIN units by default
--   pin:Set(kind)                       -- a key of Slot.PINS, or nil for none
--   pin.parts                           -- its textures, for a slot's :Clip and a caller's alpha
Slot.PIN, Slot.PIN_SEAT = 16, 7   -- a pin's cell in units, and its middle in from the corner's two sides
Slot.PINS = {
	quest = { 1, "TOPRIGHT" },      -- a quest's item
	needed = { 1, "TOPRIGHT" },     -- no quest item, but a quest needs it
	starter = { 2, "TOPRIGHT" },    -- it starts a quest
	over = { 3, "TOPRIGHT" },       -- no quest wants it any more: the stone broken, in red
	junk = { 4, "BOTTOMLEFT" },     -- a vendor's
	boe = { 5, "BOTTOMLEFT" },      -- binds once worn: still to trade or sell
	upgrade = { 6, "TOPLEFT" },     -- better than what you wear
	later = { 7, "TOPLEFT" },       -- better, at a level to come
	sell = { 8, "BOTTOMLEFT" },     -- worth the most to sell
	ahead = { 9, "TOPRIGHT" },      -- a quest will want it later: the stone in outline
}
local PIN = { file = MEDIA .. "SlotPins", across = 4, down = 4, x = { TOPLEFT = 1, BOTTOMLEFT = 1, TOPRIGHT = -1, BOTTOMRIGHT = -1 },
	y = { TOPLEFT = -1, TOPRIGHT = -1, BOTTOMLEFT = 1, BOTTOMRIGHT = 1 } }
local PinMixin = {}
PinMixin.__index = PinMixin

function PinMixin:Set(kind)
	local cell = kind and Slot.PINS[kind]
	if self.kind == kind then return end
	self.kind = cell and kind or nil
	local texture = self.texture
	if cell then
		local corner = self.corner or cell[2]
		if self.at ~= corner then
			self.at = corner
			local seat = Slot.PIN_SEAT * self.size / Slot.PIN
			texture:ClearAllPoints()
			texture:SetPoint("CENTER", self.anchor, corner, PIN.x[corner] * seat, PIN.y[corner] * seat)
		end
		local column, row = (cell[1] - 1) % PIN.across, math.floor((cell[1] - 1) / PIN.across)
		texture:SetTexCoord(column / PIN.across, (column + 1) / PIN.across, row / PIN.down, (row + 1) / PIN.down)
	end
	texture:SetShown(cell ~= nil)
end

function Slot.Pin(host, anchor, corner, size)
	local texture = host:CreateTexture(nil, "OVERLAY", nil, 6)
	texture:SetTexture(PIN.file)
	texture:SetSize(size or Slot.PIN, size or Slot.PIN)
	texture:Hide()
	return setmetatable({ texture = texture, parts = { texture }, anchor = anchor or host, corner = corner, size = size or Slot.PIN }, PinMixin)
end

-- Under pcall: a slot on one of the game's aura buttons can't be touched in a fight, and must not stop the rest.
local function Redress()
	for slot in pairs(slots) do pcall(Dress, slot) end
	for texture, f in pairs(following) do pcall(LayFollower, texture, f) end
	for cooldown, f in pairs(shaded) do pcall(Shade, cooldown, f) end
end

function Slot.Set(key)
	if not SHAPES[key] or key == Slot.Shape() then return end
	Shy.core.db.slot = key
	Redress()
	Shy:Fire("SHY_SLOT", key)
end

-- How opaque the wells are, 0 to 1 (core.db.wellArt, a percent: the Icon wells setting): its art whole at 100, what
-- is behind showing through it lower.
Slot.WELL_ART = 100
function Slot.WellArt()
	local db = Shy.core.db
	local v = db and db.wellArt
	return (type(v) == "number" and v >= 0 and v <= 100 and v or Slot.WELL_ART) / 100
end

function Slot.SetWellArt(percent)
	percent = math.max(0, math.min(100, math.floor(percent + 0.5)))
	if percent == math.floor(Slot.WellArt() * 100 + 0.5) then return end
	Shy.core.db.wellArt = percent ~= Slot.WELL_ART and percent or nil
	for slot in pairs(slots) do pcall(Colors, slot) end
	Shy:Fire("SHY_SLOT_WELL", percent)
end

function Slot.SetStyle(key)
	if key ~= "auto" and not STYLE_BY_KEY[key] then return end
	if key == Slot.Style() then return end
	Shy.core.db.slotStyle = key ~= "auto" and key or nil
	Redress()
	Shy:Fire("SHY_SLOT_STYLE", key)
end

-- The saved shape is only known once the core's settings have loaded.
Shy:On("SHY_ADDON_LOADED", function(addon)
	if addon == Shy.core then Redress() end
end)
-- The accent: colors again. The look or its options: every slot dressed again (its frame or its well another piece).
local lookWas, stampWas = "forged", nil
Shy:On("SHY_THEME", function()
	local look, stamp = Look(), Shy.Theme.LookStamp()
	if look ~= lookWas or stamp ~= stampWas then
		lookWas, stampWas = look, stamp
		Redress()
	else
		for slot in pairs(slots) do pcall(Colors, slot) end
	end
end)

-- Our own art on Blizzard's frames

-- Created once per frame and reused: skin, restore and skin again returns the same textures.
local made = setmetatable({}, { __mode = "k" })

local owned = setmetatable({}, { __mode = "k" })   -- every region a kit made (Skin.IsOwn)

function Skin.IsOwn(region)
	return owned[region] == true
end

-- A region of ours made on a frame of the game's outside a kit (a look's line extras, UI.LookWear): a kit's sweep
-- over that frame's regions never takes it for the game's art.
function Skin.Claim(region)
	owned[region] = true
end

-- The game's art on a texture as the first kit to change it found it (Kit:Art), for every kit after.
Skin.FirstArt = setmetatable({}, { __mode = "k" })

-- The housing a kit drew on a frame: every plate's art (fill, edges, brackets, caps, strip, gloss,
-- line, hover), not a plate's glyph or label. The faded HUD's watch (Immersion) fades these alone.
local HOUSE = { "fill", "edge", "strip", "gloss", "line" }

-- Art an owner drew on a frame outside a kit, reported as housing (Skin.House): frame -> lists or functions.
local housed = setmetatable({}, { __mode = "k" })

function Skin.House(frame, regions)
	local list = housed[frame]
	if not list then
		list = {}
		housed[frame] = list
	end
	list[#list + 1] = regions
end

-- `out`: a list to add them to (the immersion's watch gathers them ten times a second and keeps one list);
-- else a new one.
local HOUSE_LISTS = { "edges", "hot", "brackets", "caps" }
function Skin.Housing(frame, out)
	out = out or {}
	local own, sets = housed[frame], made[frame]
	if own then
		for _, regions in ipairs(own) do
			if type(regions) == "function" then regions = regions() end
			for _, region in ipairs(regions) do out[#out + 1] = region end
		end
	end
	if not sets then return out end
	for _, set in pairs(sets) do
		if set.plate then
			for _, key in ipairs(HOUSE) do
				if set[key] then out[#out + 1] = set[key] end
			end
			-- In this order, up to the first the plate doesn't have.
			for _, name in ipairs(HOUSE_LISTS) do
				local list = set[name]
				if not list then break end
				for _, t in ipairs(list) do out[#out + 1] = t end
			end
			if set.line and set.line.shyTrim then out[#out + 1] = set.line.shyTrim end
			if set.look then UI.LookParts(set.look, out) end
		end
	end
	return out
end

-- Plates wearing the theme's look, dressed again when it changes (a set is dropped with its owner). A plate its
-- owner has put away (its fill hidden: ShyChat's wing for a width no longer used) is left so: dressing it would
-- show it again, a dark slab past the housing in use. Brought back (kit:Plate), it is dressed in the look then.
-- Its colors follow every change of the theme (the Background strength, the accent): most owners paint their plates
-- again on SHY_THEME, so once they have, a plate none painted for this theme (set.paintedAt) is dressed again.
local looked = setmetatable({}, { __mode = "k" })
local themed = 0   -- SHY_THEMEs so far: a plate painted since the last one is in its colors
local function Unpainted()
	for set in pairs(looked) do
		if set.paintedAt ~= themed and set.fill:IsShown() then set.redress() end
	end
end
Shy:On("SHY_THEME", function()
	themed = themed + 1
	local look = Shy.Theme.Look()
	for set in pairs(looked) do
		local wore = set.look and set.look.look or set.wore
		local stale = set.look and set.look.stamp ~= Shy.Theme.LookStamp()   -- a look option changed since
		if (wore ~= look or stale) and set.fill:IsShown() then
			set.redress()
		elseif set.look and set.fill:IsShown() then
			UI.LookRestore(set.look)   -- its art given back, whatever a sweep over the game's frame did to it
		end
	end
	C_Timer.After(0, Unpainted)   -- (after every listener of this one has had its turn)
end)

local function Own(kit, owner, key, build)
	local sets = made[owner]
	if not sets then
		sets = {}
		made[owner] = sets
	end
	local set = sets[key]
	if not set then
		set = build()
		sets[key] = set
		for _, region in ipairs(set) do owned[region] = true end
	end
	kit.own[set] = true
	for _, region in ipairs(set) do region:Show() end
	return set
end

-- Blended, not additive like Blizzard's, so the color holds over a bright icon.
function Kit:Lit(texture, button, color, x, y)
	self:Piece(texture, "glow", button, { x = x, y = y, color = color, blend = "BLEND" })
end

-- piece and to as in Slot.Follow. opts: x, y, size, color, blend.
function Kit:Piece(texture, piece, to, opts)
	if not texture then return end
	opts = opts or {}
	self:Art(texture, Skin.FRAME, { fit = to, x = opts.x, y = opts.y, slice = FRAME_SLICE, color = opts.color, blend = opts.blend })
	Entry(self, texture).follows = true
	Slot.Follow(texture, piece, to, opts.x, opts.y, opts.size)
end

function Kit:Number(fontString)
	self:Font(fontString, Shy.FONT_ROUNDED, nil, "OUTLINE")
end

-- opts as Slot.Swipe's.
function Kit:Swipe(cooldown, opts)
	if not cooldown then return end
	Entry(self, cooldown).shaded = true
	Slot.Swipe(cooldown, opts)
end

local function Add(set, name, region)
	set[#set + 1] = region
	set[name] = region
	return region
end

local function Sliced(owner, layer, sublevel, file, margin)
	local t = owner:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(file)
	t:SetTextureSliceMargins(margin, margin, margin, margin)
	return t
end

-- Repainting keeps the slot's state (mark, empty, bare); Restore clears it.
-- A tile the kit already holds is only set again (Own would show the pieces its colors hid).
function Kit:Tile(owner, opts)
	local sets = made[owner]
	local slot = sets and sets.tile
	if slot and self.own[slot] then
		slot:Set(opts)
		return slot
	end
	slot = Own(self, owner, "tile", function() return Slot.New(owner, opts) end)
	-- (Every piece just shown: dressed again in full.)
	slot.dressed = false
	slot:Set(opts)
	return slot
end

-- A key's label on a button of the game's that never fills its own (a stance button's): a font string of the kit's,
-- in the font the game gives its keys (it has the "in range" dot), at the top right where an action button has its
-- key. One per button, put away with the kit's other art. text nil: hidden. Returns the font string.
function Kit:KeyLabel(owner, text)
	local set = Own(self, owner, "keylabel", function()
		local s = {}
		local label = Add(s, "label", owner:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray"))
		label:SetJustifyH("RIGHT")
		label:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -2, -3)
		return s
	end)
	set.label:SetText(text or "")
	set.label:SetShown(text ~= nil and text ~= "")
	return set.label
end

function Kit:Frame(owner, opts)
	opts = opts or {}
	local set = Own(self, owner, "frame", function()
		local s = {}
		Add(s, "frame", Sliced(owner, "ARTWORK", 7, Skin.FRAME, FRAME_SLICE))
		return s
	end)
	Fit(set.frame, opts.to or owner, opts.x or 0, opts.y or 0)
	local c = opts.color or C.metal
	set.frame:SetVertexColor(c[1], c[2], c[3])
	return set
end

local EDGES = {
	{ "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
	{ "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
}

-- inset: { left, top, right, bottom }.
local function Corner(region, point, owner, inset)
	local x = point:find("LEFT") and inset[1] or -inset[3]
	local y = point:find("TOP") and -inset[2] or inset[4]
	region:SetPoint(point, owner, point, x, y)
end

local function Border(owner, layer, inset, to)
	local edges = {}
	for i, def in ipairs(EDGES) do
		local t = owner:CreateTexture(nil, layer)
		Corner(t, def[1], to, inset)
		Corner(t, def[2], to, inset)
		t[def[3]](t, 1)
		edges[i] = t
	end
	return edges
end

local function LightLine(band)
	band:SetGradient("HORIZONTAL", CreateColor(B.Ramp(0)), CreateColor(B.Ramp(1)))
end

-- The header's line along `under`'s foot: every header's make (UI.HeadLine), worn by the look as every header's
-- line is (UI.LookLine: the riveted trim, a look kind's own, `under` its strip). An owner may lay it elsewhere,
-- or set its thickness itself (UI.LineFit(line, false) first).
function Kit:Line(owner, under)
	local set = Own(self, owner, "line", function()
		local s = {}
		Add(s, "line", UI.HeadLine(owner, under))
		return s
	end)
	UI.LookLine(owner, set.line, Shy.Theme.Look(), under)
	return set
end

-- A lit stretch of a plate's line (UI.LineMark) for a frame of the game's: an open tab's. One per frame and
-- line, put away with the kit's other art. Returns the set; .mark is the mark (shown: the caller says when).
function Kit:Mark(owner, line, color)
	return Own(self, owner, line, function()
		local s = {}
		Add(s, "mark", UI.LineMark(line:GetParent(), line, color))
		return s
	end)
end

-- A dark hatch over the whole bar, aligned with the fill. It is put one sublevel under the fill in
-- the fill's own draw layer, which varies (ARTWORK by default; a unit frame's health bar uses BACKGROUND).
function Kit:Track(statusBar, color)
	local set = Own(self, statusBar, "track", function()
		local s = {}
		local track = Add(s, "track", statusBar:CreateTexture(nil, "ARTWORK", nil, -1))
		track:SetAllPoints(statusBar)
		Skin.Hatch(track)
		return s
	end)
	local fill = statusBar:GetStatusBarTexture()
	if fill then
		local ok, layer, sublevel = Read(fill, "GetDrawLayer")
		if ok then set.track:SetDrawLayer(layer, math.max(-8, sublevel - 1)) end
	end
	local c = color or C.well
	set.track:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	return set
end

-- A panel's beveled edge and four corner brackets.
local function PanelArt(s, owner, layer, inset, to, brackets)
	local edge = Add(s, "edge", owner:CreateTexture(nil, layer))
	edge:SetTexture(UI.EDGE)
	edge:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
	Corner(edge, "TOPLEFT", to, inset)
	Corner(edge, "BOTTOMRIGHT", to, inset)
	s.brackets = {}
	if brackets == false then return end
	for i, def in ipairs(UI.BRACKETS) do
		local t = Add(s, "bracket" .. i, owner:CreateTexture(nil, layer, nil, 1))
		t:SetTexture(UI.BRACKET)
		t:SetTexCoord(def[2], def[3], def[4], def[5])
		t:SetSize(UI.BRACKET_SIZE, UI.BRACKET_SIZE)   -- always this size; a number in opts.brackets is ignored
		Corner(t, def[1], to, inset)
		s.brackets[i] = t
	end
end

-- A cap bar along the top of `to` (or flipped along its foot): fixed ends, stretched middle,
-- one unit outside the insets.
local function CapArt(s, owner, layer, inset, to, foot)
	local e = UI.CAP_END / 96
	local v0, v1 = 0, 1
	if foot then v0, v1 = 1, 0 end
	local side = foot and "BOTTOM" or "TOP"
	local name = foot and "foot" or "cap"
	local left = Add(s, name .. "Left", owner:CreateTexture(nil, layer, nil, 2))
	left:SetTexCoord(0, e, v0, v1)
	local right = Add(s, name .. "Right", owner:CreateTexture(nil, layer, nil, 2))
	right:SetTexCoord(1 - e, 1, v0, v1)
	local bar = Add(s, name .. "Bar", owner:CreateTexture(nil, layer, nil, 2))
	bar:SetTexCoord(e, 1 - e, v0, v1)
	local proud = { inset[1] - 1, inset[2] - 1, inset[3] - 1, inset[4] - 1 }
	Corner(left, side .. "LEFT", to, proud)
	Corner(right, side .. "RIGHT", to, proud)
	bar:SetPoint("TOPLEFT", left, "TOPRIGHT")
	bar:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	for _, t in ipairs({ left, right, bar }) do
		t:SetTexture(UI.CAP)
		s.caps[#s.caps + 1] = t
	end
	left:SetSize(UI.CAP_END, UI.CAP_H)
	right:SetSize(UI.CAP_END, UI.CAP_H)
end

function Kit:Plate(owner, opts)
	opts = opts or {}
	local x, y = opts.x or 0, opts.y or 0
	local inset = opts.inset or { x, y, x, y }
	-- A panel plate on screen during play, or a window's (window = true), wears the theme's look: its fill, strip
	-- and gloss stand a few sublevels up, leaving the look's shade and halo room under them (UI.lua, "The
	-- looks"). looks = false: an inner piece of a housing, none; looks = { to, inset, fill, head }: fitted to that rect (a
	-- plate whose housing is the whole window; `fill` the fill's own inset when it stops short of the edge's); a
	-- window keeps its solid fill.
	local looks = opts.panel and opts.looks ~= false and (opts.hud or opts.cap or opts.window or opts.looks) and true or false
	local set = Own(self, owner, opts.key or "plate", function()
		local s = { edges = {}, hot = {}, brackets = {}, caps = {}, plate = true }
		local to = opts.to or owner
		local fill = Add(s, "fill", owner:CreateTexture(nil, "BACKGROUND", nil, looks and -6 or -8))
		Corner(fill, "TOPLEFT", to, inset)
		Corner(fill, "BOTTOMRIGHT", to, inset)
		local layer = opts.over and "OVERLAY" or "BORDER"
		s.bounds = { owner = owner, to = to, inset = inset }   -- for Kit.Outline
		if opts.panel then
			-- A console piece has brackets only when it has a title.
			local brackets = opts.brackets
			if opts.cap and brackets == nil then brackets = opts.title and UI.BRACKET_SIZE or false end
			PanelArt(s, owner, layer, inset, to, brackets)
			if opts.cap == "both" then CapArt(s, owner, layer, inset, to, true) end
		else
			for i, t in ipairs(Border(owner, layer, inset, to)) do s.edges[i] = Add(s, "edge" .. i, t) end
		end
		if opts.hover then
			for i, t in ipairs(Border(owner, "HIGHLIGHT", inset, to)) do s.hot[i] = Add(s, "hot" .. i, t) end
		end
		if opts.title then
			local strip = Add(s, "strip", owner:CreateTexture(nil, "BACKGROUND", nil, looks and -2 or -7))
			-- Inside the border: 1 for the thin line, 2 for a panel's rim (must match UI.Panel).
			local rim = opts.panel and 2 or 1
			strip:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + rim, -inset[2] - rim)
			strip:SetPoint("TOPRIGHT", to, "TOPRIGHT", -inset[3] - rim, -inset[2] - rim)
			-- A console piece's `title` is its whole header height, top edge to line.
			strip:SetHeight((opts.panel and opts.cap) and opts.title - rim or opts.title)
			-- Its middle (UI.OnHead), from `to`'s top: a piece on screen keeps a console piece's lip, a window a
			-- window's (opts.lip: kit:Head's).
			s.headTo = to
			local stripH = strip:GetHeight()
			s.headStripTop = inset[2] + rim
			s.headStripH = stripH
			s.headLine = s.headStripTop + stripH
			-- (From the plate's own top edge, which stands inset[2] under `to`'s: above it where the plate grows up.)
			s.headY = inset[2] + UI.HeadMiddle(rim, stripH,
				opts.lip or ((opts.cap or opts.hud) and UI.HEAD.piece.lip or UI.HEAD.window.lip))
			if opts.panel then
				local gloss = Add(s, "gloss", owner:CreateTexture(nil, "BACKGROUND", nil, looks and -1 or -6))
				gloss:SetAllPoints(strip)
				gloss:SetTexture(UI.GLOSS)
			end
			Add(s, "line", UI.HeadLine(owner, strip))
		end
		if opts.band then
			local band = Add(s, "band", owner:CreateTexture(nil, "BACKGROUND", nil, looks and -2 or -7))
			band:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + 1, -inset[2] - 1)
			band:SetPoint("TOPRIGHT", to, "TOPRIGHT", -inset[3] - 1, -inset[2] - 1)
			band:SetHeight(opts.band)
			band:SetColorTexture(1, 1, 1, 1)
		end
		if opts.icon then
			local icon = Add(s, "icon", owner:CreateTexture(nil, "ARTWORK"))
			icon:SetPoint("CENTER", fill, "CENTER", 0, 0)
		end
		if opts.label then
			local label = Add(s, "label", owner:CreateFontString(nil, "OVERLAY"))
			UI.TitleFace(label, opts.labelSize or 14)
			label:SetPoint("CENTER", fill, "CENTER", 0, 0)
			label:SetText(opts.label)
		end
		-- The other looks' regions last, after the forged make's (whose places in the set are kept).
		if looks then
			local fit = type(opts.looks) == "table" and opts.looks or nil
			s.look = UI.LookBuild(owner, fit and fit.to or to, fit and fit.inset or inset, function(name, region)
				Add(s, "look" .. name, region)
				owned[region] = true   -- (a rivet is made when the plate's size calls for it, after the set is owned)
			end)
			local forged = { s.edge }
			for _, t in ipairs(s.brackets) do forged[#forged + 1] = t end
			for _, t in ipairs(s.caps) do forged[#forged + 1] = t end
			s.look.forged = forged
			s.look.solid = not (opts.hud or opts.cap)
			s.look.mini = opts.mini == true   -- the look's mini border (its own simpler, smaller make: h.mini)
			-- (`fill`: the fill's own inset in the plate's rect, when it stops short of the edge's: under a head.)
			if fit then s.look.fitTo, s.look.fitInset = to, fit.fill or inset end
			-- Its head (the zones, UI.LOOK_ZONES): its strip down to its line's foot (a console piece's `title` is
			-- the whole header, edge to line); a plate fitted to another rect says its own (`looks.head`).
			local rim = opts.panel and 2 or 1
			s.look.zoneHead = (fit and fit.head) or (opts.title and not fit and ((opts.panel and opts.cap) and opts.title or rim + opts.title) + UI.LINE) or 0
		end
		return s
	end)
	-- hud: fill at the opacity setting; edge, strip and gloss slightly stronger (Theme.lua).
	local hud = opts.hud and true or false
	set.paintedAt = themed
	-- With a look, the fill, strip and gloss take the look's opacity (UI.LookAlpha) and are dressed again when it changes.
	-- An inner piece on screen (the damage meter's head) takes its housing's, the theme's look, as every header does.
	local inner = hud and opts.panel and opts.looks == false
	local look = (set.look or inner) and Shy.Theme.Look() or "forged"
	local function Alpha(a)
		if set.look then return set.look.solid and a or UI.LookAlpha(look, a) end
		if inner then return UI.LookAlpha(look, a) end
		return a
	end
	local fill = opts.fill or (hud and C.hud) or (opts.panel and C.panel) or UI.colors.bg
	set.fill:SetColorTexture(UI.LookFill(look, fill[1], fill[2], fill[3], Alpha(fill[4] or 1)))
	for _, t in ipairs(set.edges) do Paint(t, opts.border or C.edge) end
	if set.edge then
		local c = opts.border or (hud and C.hudMetal) or C.metal
		set.edge:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		-- The bracket art is white, so the accent is used untinted (as in UI.Panel).
		local r, g, b = Shy.Theme.Accent()
		for _, t in ipairs(set.brackets) do t:SetVertexColor(r, g, b, c[4] or 1) end
		for _, t in ipairs(set.caps) do t:SetVertexColor(C.metal[1], C.metal[2], C.metal[3], c[4] or 1) end
		if set.look then
			UI.LookDress(set.look, look, { fill = set.fill, fitTo = set.look.fitTo, fitInset = set.look.fitInset, forged = set.look.forged, metal = c,
				gloss = set.gloss, line = set.line, strip = set.strip })
			set.redress = function()
				if self.own[set] then self:Plate(owner, opts) end
			end
			looked[set] = true
		elseif opts.panel and opts.looks == false then
			-- An inner piece of a housing wearing a look: its forged make (edge, brackets, caps) is the housing's,
			-- put away with it in the other looks; in Forged its owner says what shows.
			local wear = Shy.Theme.Look()
			if wear ~= "forged" then
				set.edge:Hide()
				for _, t in ipairs(set.brackets) do t:Hide() end
				for _, t in ipairs(set.caps) do t:Hide() end
			end
			-- Its strip and its line are the housing's too (painted below, by the housing's look).
			if set.line then UI.LookLine(owner, set.line, wear, set.strip) end
			set.wore = wear
			-- Dressed again with the look, as the housing is.
			set.redress = function()
				if self.own[set] then self:Plate(owner, opts) end
			end
			looked[set] = true
		end
	end
	for _, t in ipairs(set.hot) do Paint(t, C.hover) end
	-- The title strip by look (UI.LookStrip): a plate wearing one, or an inner piece of a housing wearing one.
	local stripLook = set.look and look or (opts.panel and opts.looks == false and Shy.Theme.Look()) or "forged"
	if set.strip then
		local c = hud and C.hudStrip or C.strip
		local r, g, b, a = UI.LookStrip(stripLook, c[1], c[2], c[3], Alpha(c[4] or 1))
		set.strip:SetColorTexture(r, g, b, a)
	end
	if set.gloss then
		set.gloss:SetAlpha(Alpha(hud and C.hudStrip[4] or 1))
		set.gloss:SetShown((select(5, UI.LookStrip(stripLook, 0, 0, 0, 1))))
	end
	-- A plate wearing no look of its own (a list's panel) still wears the theme's line.
	if set.line and not set.look and not (opts.panel and opts.looks == false) then
		UI.LookLine(owner, set.line, Shy.Theme.Look(), set.strip)
	end
	if set.band then LightLine(set.band) end
	if set.label then set.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end
	if set.icon then
		set.icon:SetTexture(opts.icon)
		set.icon:SetSize(opts.iconSize or 12, opts.iconSize or 12)
		set.icon:SetVertexColor(C.glyph[1], C.glyph[2], C.glyph[3])
	end
	return set
end

-- A button of the game's in the family's make (UI.Button's): the face, gloss and edge under its words, and in
-- its HIGHLIGHT layer, which the game shows under the mouse while it is in use, the hot edge, the accent's
-- wash and light along its top. Held, the face darkens (a post-hook, idle once the kit lets it go).
-- primary = true: the accent's deep shade in the hot edge, lit along its top; on = true: lit at rest (a tool in
-- use), the hot edge and a softer light. opts: inset, key, primary, on,
-- size = the plate a square this size whatever the button's own (the game's are 24, 28, 32 or a frame's width), its
-- middle at the middle of the inset's rect: the inset then only places it. Buttons standing together (a header's) take
-- one size this way, never one worked out from each button's art.
-- icon = a glyph's file in the middle (iconSize, 12): dim at rest, the head's ink under the mouse (a twin in
-- the HIGHLIGHT layer). The set's .icon and .iconHot are those two; set:Turn(radians) turns both and
-- set:Stand(point, ...) stands both elsewhere. label = words in the middle instead (labelSize, 12), the same way.
local KEY_LIGHT, KEY_GLOW, KEY_WASH = 0.9, 0.35, 0.14

local function KeyLight(s, name, owner, layer, sub, plate)
	local t = Add(s, name, owner:CreateTexture(nil, layer, nil, sub))
	t:SetTexture(UI.LIGHT)
	t:SetBlendMode("ADD")
	t:SetPoint("TOPLEFT", plate, "TOPLEFT", 3, 1)
	t:SetPoint("TOPRIGHT", plate, "TOPRIGHT", -3, 1)
	t:SetHeight(9)
	return t
end

local function KeyFace(s)
	local make = s.shyKeyMake or UI.KeyMake(Shy.Theme.Look())
	local fill = s.primary and UI.colors.fill or UI.colors.bgHot
	-- The face in the look's make (leaning, clear, the primary its own way), held darker.
	Shy.Theme.Tint(s.fill, UI.KeyFace(make, fill, s.primary, s.held))
	-- (The gloss's strength in its tint: the region's own alpha is what fades it.)
	local gloss = type(make.gloss) == "number" and make.gloss or 0.18
	s.gloss:SetVertexColor(1, 1, 1, s.held and gloss / 3 or gloss)
	s.gloss:SetShown(make.gloss and true or false)   -- the look's finish: glossed or matte
	s.inset:SetShown(s.held == true)                 -- held: the face pushed below its edge
end

-- The look's button make on a game button's set (UI.KEY_MAKES): the edge and its hot twin in the make's art, its
-- face's texture, the light round it (the eclipse's) and its brackets in the HIGHLIGHT layer the game shows under
-- the mouse, its seam and rivets at rest; the edge's color at rest the make's. Again whenever the look changes.
local keys = setmetatable({}, { __mode = "k" })   -- set -> the kit holding it

-- A forged button's brackets: in the hot color under the mouse and on the primary or a button on, at rest dim in
-- the steel (as its make keeps them).
local function KeyBrackets(set)
	local make = set.shyKeyMake
	local hot = set.over or set.primary or set.on
	for _, t in ipairs(set.brackets or {}) do
		t:SetShown(make ~= nil and make.trim == "bracket" and (hot or make.bracketRest ~= nil))
		if hot then Shy.Theme.Tint(t, UI.colors.hot, 1) else Shy.Theme.Tint(t, Shy.Theme.skin.metal, make and make.bracketRest or 0) end
	end
end

-- A make's pieces on a set, made the first time a make wears them: a texture over the face and the riveted sheen,
-- the eclipse's light round it and the forged brackets (in the HIGHLIGHT layer: under the mouse), a seam, rivets.
-- Each is the set's own (put away with it on Restore, shown again when the kit takes it back).
local function KeyPiece(set, name, layer, sub)
	local t = set[name]
	if not t then
		t = Add(set, name, set.owner:CreateTexture(nil, layer, nil, sub))
		owned[t] = true
	end
	return t
end
local function KeyPieces(set, make)
	local M, fill = UI.KEY_MEASURES, set.fill
	if (make.grain or make.brushed or make.frost) and not set.face then
		local face = KeyPiece(set, "face", "BACKGROUND", -7)
		face:SetPoint("TOPLEFT", fill, "TOPLEFT", M.FACE_IN, -M.FACE_IN)
		face:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -M.FACE_IN, M.FACE_IN)
	end
	if make.brushed and not set.sheen then
		local sheen = KeyPiece(set, "sheen", "BACKGROUND", -6)
		sheen:SetAllPoints(set.face)
		sheen:SetTexture(UI.LookArt.METAL_SHEEN)
		sheen:SetVertexColor(1, 1, 1, 0.35)
	end
	if make.halo and not set.halo then
		local halo = KeyPiece(set, "halo", "HIGHLIGHT", -1)
		halo:SetTexture(UI.KEY_HALO)
		halo:SetTextureSliceMargins(M.HALO_SLICE, M.HALO_SLICE, M.HALO_SLICE, M.HALO_SLICE)
		halo:SetPoint("TOPLEFT", fill, "TOPLEFT", -M.HALO, M.HALO)
		halo:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", M.HALO, -M.HALO)
		halo:SetBlendMode("ADD")
		Shy.Theme.Tint(halo, Shy.Theme.Accent, 0.55)
	end
	if make.trim == "bracket" and not set.brackets then
		set.brackets = {}
		for i, corner in ipairs(UI.BRACKETS) do
			local t = KeyPiece(set, "bracket" .. i, "BORDER", 3)
			t:SetTexture(UI.KEY_BRACKET)
			t:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
			t:SetSize(M.BRACKET, M.BRACKET)
			t:SetPoint(corner[1], fill, corner[1])
			set.brackets[i] = t
		end
		-- Lit under the mouse, dim in the steel at rest (KeyBrackets).
		set.owner:HookScript("OnEnter", function(b)
			if set.kit.own[set] then
				set.over = b:IsEnabled()
				KeyBrackets(set)
			end
		end)
		set.owner:HookScript("OnLeave", function()
			if set.kit.own[set] then
				set.over = false
				KeyBrackets(set)
			end
		end)
	end
	if make.foot and not set.footBand then
		local band = KeyPiece(set, "footBand", "BACKGROUND", -6)
		band:SetColorTexture(1, 1, 1, 1)
		band:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", M.FACE_IN, M.FACE_IN)
		band:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -M.FACE_IN, M.FACE_IN)
		band:SetHeight(M.FOOT)
	end
	if make.trim == "rivet" and not set.shyStuds then
		set.shyStuds = {}
		for i = 1, 4 do
			local t = KeyPiece(set, "stud" .. i, "BORDER", 2)
			t:SetTexture(UI.LookArt.RIVET)
			set.shyStuds[i] = t
		end
	end
end

-- A game button's glyph and words held to read on its face (the contrast floor: at rest the dim ink on the face,
-- under the mouse the head's on the face under the accent's wash and the hover's lift, the color where it stands),
-- its glyph's shadow as dark as the look lifts it.
local function KeyInks(set)
	local Theme, M = Shy.Theme, UI.KEY_MEASURES
	local make = set.shyKeyMake or UI.KeyMake(Theme.Look())
	local face = UI.KeyFace(make, set.primary and UI.colors.fill or UI.colors.bgHot, set.primary, false)
	local rest = UI.KeySeen(set.owner, face, 0)
	local hot = UI.KeySeen(set.owner, face, KEY_WASH + (UI.KeyHover(make).lift or 0))
	-- (The ink keeps the side, light or dark, its face wants at rest: under the mouse it never flips.)
	local polar = UI.KeyPolar(rest)
	if set.icon then
		Theme.Tint(set.icon, UI.KeyFloor(UI.colors.dim, rest, M.GLYPH_LC, polar))
		Theme.Tint(set.iconHot, UI.KeyFloor(UI.colors.head, hot, M.GLYPH_LC, polar))
		local lift = UI.KeyLift(make)
		set.iconShade:SetVertexColor(0, 0, 0, lift)
		set.iconShade:SetShown(lift > 0 and set.icon:GetTexture() ~= nil)
	end
	if set.label then
		Theme.Ink(set.label, UI.KeyFloor(UI.colors.dim, rest, Theme.LC_LABEL, polar))
		Theme.Ink(set.labelHot, UI.KeyFloor(UI.colors.head, hot, Theme.LC_LABEL, polar))
		-- Its words in the theme's text effect, at least a shadow where the look lifts what stands on its buttons.
		local least = UI.KeyLift(make) > 0 and "shadow" or false
		Theme.Letter(set.label, { least = least })
		Theme.Letter(set.labelHot, { least = least })
	end
end

-- A look whose button is all its own art (Heritage's red button): built on the game button once, the forged
-- plate put away, and marked for hover and press. Other kit:Key buttons still wear forged (their sizes vary).
local function KeyOwnArt(set, make)
	local owner = set.owner
	if make.build then
		if not (owner.shyBuilt and owner.shyBuilt[make]) then
			owner.shyBuilt = owner.shyBuilt or {}
			local parts = make.build(owner) or {}
			owner.shyBuilt[make] = parts
			for i, t in ipairs(parts) do
				if not set["own" .. i] then Add(set, "own" .. i, t) end
			end
		end
		for other, regions in pairs(owner.shyBuilt) do
			for _, t in ipairs(regions) do t:SetShown(other == make) end
		end
	end
	for _, name in ipairs({ "fill", "edge", "gloss", "light", "wash", "hot", "glow", "inset", "face", "sheen", "halo" }) do
		if set[name] then set[name]:Hide() end
	end
	if make.mark then make.mark(owner, set.over or set.on, set.held, set.primary) end
end

local function KeyHideOwn(set)
	local built = set.owner and set.owner.shyBuilt
	if not built then return end
	for _, regions in pairs(built) do
		for _, t in ipairs(regions) do t:Hide() end
	end
end

local function KeyMake(set)
	local Theme = Shy.Theme
	local make = UI.KeyMake(Theme.Look())
	-- A make all of the game's own art: on a header close (opts.own) it is worn; other game buttons keep forged.
	if make.own and not set.allowOwn then
		KeyHideOwn(set)
		make = UI.KEY_MAKES.forged
	end
	set.shyKeyMake, set.keyLook, set.keyStamp = make, Theme.Look(), Theme.LookStamp()
	if make.own and set.allowOwn then
		KeyOwnArt(set, make)
		return
	end
	local M = UI.KEY_MEASURES
	local m = make.edge[2]
	local w, h = set.fill:GetSize()
	if w and h and not issecretvalue(w) and not issecretvalue(h) and w > 0 and h > 0 then m = math.min(m, math.floor(math.min(w, h) / 2)) end
	for _, t in ipairs({ set.edge, set.hot }) do
		t:SetTexture(make.edge[1])
		t:SetTextureSliceMargins(m, m, m, m)
	end
	local lit = set.primary or set.on
	Theme.Tint(set.edge, UI.KeyRim(make, lit, Theme.skin.metal))
	set.hot:SetShown(make.hot == true)
	KeyPieces(set, make)
	local file = (make.face and make.face()) or (make.grain and UI.LookArt.GRAIN) or (make.brushed and UI.LookArt.BRUSHED) or (make.frost and UI.FROST) or nil
	if file then
		set.face:SetTexture(file, "REPEAT", "REPEAT")
		set.face:SetHorizTile(true)
		set.face:SetVertTile(true)
		set.face:SetVertexColor(1, 1, 1, make.grain and make.grain * (set.primary and 0.5 or 1) or make.frost or 1)
	end
	if set.face then set.face:SetShown(file ~= nil) end
	if set.sheen then set.sheen:SetShown(make.brushed == true) end
	if set.halo then set.halo:SetShown(make.halo == true) end
	if set.footBand then
		set.footBand:SetShown(make.foot ~= nil)
		if make.foot then set.footBand:SetGradient("VERTICAL", CreateColor(0, 0, 0, make.foot), CreateColor(0, 0, 0, 0)) end
	end
	KeyBrackets(set)
	-- At rest a light along its top where the make keeps one (Glass), unless lit already.
	if not lit then
		set.light:SetShown((make.rest or 0) > 0)
		Theme.Tint(set.light, Theme.light, make.rest or 0)
	end
	set.shyPlate = true
	UI.KeyLay(set)
	KeyFace(set)
	KeyInks(set)
end
Shy:On("SHY_THEME", function()
	local look, stamp = Shy.Theme.Look(), Shy.Theme.LookStamp()
	for set, kit in pairs(keys) do
		if (set.keyLook ~= look or set.keyStamp ~= stamp) and kit.own[set] then KeyMake(set) end
	end
end)

function Kit:Key(owner, opts)
	opts = opts or {}
	local inset = opts.inset or { 0, 0, 0, 0 }
	local kit = self
	local set = Own(self, owner, opts.key or "key", function()
		local s = { plate = true }
		-- The face is the plate: every other piece stands on it.
		local fill = Add(s, "fill", Sliced(owner, "BACKGROUND", -8, UI.KEY_FACE, UI.KEY_SLICE))
		if opts.size then
			fill:SetPoint("CENTER", owner, "CENTER", (inset[1] - inset[3]) / 2, (inset[4] - inset[2]) / 2)
			fill:SetSize(opts.size, opts.size)
		else
			Corner(fill, "TOPLEFT", owner, inset)
			Corner(fill, "BOTTOMRIGHT", owner, inset)
		end
		local function Piece(name, file, layer, sub)
			local t = Add(s, name, Sliced(owner, layer, sub, file, UI.KEY_SLICE))
			t:SetAllPoints(fill)
			return t
		end
		-- The gloss from just under the top edge to the middle.
		local gloss = Add(s, "gloss", owner:CreateTexture(nil, "BACKGROUND", nil, -7))
		gloss:SetTexture(UI.GLOSS)
		gloss:SetPoint("TOPLEFT", fill, "TOPLEFT", 3, -2)
		gloss:SetPoint("BOTTOMRIGHT", fill, "RIGHT", -3, 0)
		Piece("edge", UI.KEY_EDGE, "BORDER", 0)
		KeyLight(s, "light", owner, "ARTWORK", 0, fill)
		Piece("wash", UI.KEY_FACE, "HIGHLIGHT", 0)
		Piece("hot", UI.KEY_EDGE, "HIGHLIGHT", 1)
		KeyLight(s, "glow", owner, "HIGHLIGHT", 2, fill)
		-- A press (every make); what else a look's make wears is made the first time it is worn (KeyMake).
		Piece("inset", UI.KEY_INSET, "ARTWORK", 1)
		s.inset:Hide()
		s.owner, s.kit, s.shyPlateOf = owner, kit, fill
		owner:HookScript("OnSizeChanged", function()
			if kit.own[s] then UI.KeyLay(s) end
		end)
		if opts.icon then
			for _, piece in ipairs({ { "icon", "OVERLAY" }, { "iconHot", "HIGHLIGHT" } }) do
				local t = Add(s, piece[1], owner:CreateTexture(nil, piece[2], nil, 3))
				t:SetPoint("CENTER", s.fill, "CENTER")
				UI.Concentric(t)
			end
			-- Its glyph lifted off the face: a dark copy under it, a unit down and right, following it.
			local shade = Add(s, "iconShade", owner:CreateTexture(nil, "OVERLAY", nil, 2))
			shade:SetPoint("TOPLEFT", s.icon, "TOPLEFT", 1, -1)
			shade:SetPoint("BOTTOMRIGHT", s.icon, "BOTTOMRIGHT", 1, -1)
			function s:Turn(radians)
				self.icon:SetRotation(radians)
				self.iconHot:SetRotation(radians)
				self.iconShade:SetRotation(radians)
			end
			function s:Stand(...)
				for _, t in ipairs({ self.icon, self.iconHot }) do
					t:ClearAllPoints()
					t:SetPoint(...)
				end
			end
		elseif opts.label then
			for _, piece in ipairs({ { "label", "OVERLAY" }, { "labelHot", "HIGHLIGHT" } }) do
				local t = Add(s, piece[1], owner:CreateFontString(nil, piece[2]))
				UI.TitleFace(t, opts.labelSize or 12)
				t:SetPoint("CENTER", s.fill, "CENTER")
			end
		end
		local function OwnLook()
			if s.allowOwn and s.shyKeyMake and s.shyKeyMake.own then
				KeyOwnArt(s, s.shyKeyMake)
			else
				KeyFace(s)
			end
		end
		owner:HookScript("OnEnter", function()
			if kit.own[s] then
				s.over = true
				OwnLook()
			end
		end)
		owner:HookScript("OnLeave", function()
			s.over = false
			if kit.own[s] then OwnLook() end
		end)
		owner:HookScript("OnMouseDown", function(b)
			if kit.own[s] and b:IsEnabled() then
				s.held = true
				OwnLook()
			end
		end)
		owner:HookScript("OnMouseUp", function()
			if s.held then
				s.held = false
				OwnLook()
			end
		end)
		return s
	end)
	set.primary, set.held, set.allowOwn = opts.primary == true, false, opts.own == true
	local Theme = Shy.Theme
	-- on: lit at rest (a tool in use): the hot edge and a softer light along its top.
	local on = opts.on == true
	set.on = on
	Theme.Tint(set.light, Theme.light, set.primary and KEY_LIGHT or KEY_GLOW)
	set.light:SetShown(set.primary or on)
	-- The look's make (its edge's color at rest among it), and again when the look changes.
	keys[set] = kit
	KeyMake(set)
	Theme.Tint(set.wash, Theme.AccentSolid, set.primary and KEY_WASH * 0.7 or KEY_WASH)
	Theme.Tint(set.hot, UI.colors.hot)
	Theme.Tint(set.glow, Theme.light, KEY_GLOW)
	set.glow:SetShown(not set.primary)
	if set.icon and opts.icon then
		local size = opts.iconSize or 12
		for _, t in ipairs({ set.icon, set.iconHot, set.iconShade }) do
			t:SetTexture(opts.icon)
			Shy.UI.GlyphFit(t, size)   -- whole pixels, as the family's own glyph buttons
		end
	end
	if set.label and opts.label then
		set.label:SetText(opts.label)
		set.labelHot:SetText(opts.label)
	end
	KeyInks(set)
	return set
end

-- A plate's outline, drawing nothing, made the first time it is asked for: what a grip stands on, since a
-- look other than the forged one sets the fill in from the edge (or under a head). Nil while the kit
-- doesn't hold the plate; it goes with the plate's art when the kit lets it go.
function Kit:Outline(set)
	if not self.own[set] then
		if set.outline then set.outline:Hide() end
		return nil
	end
	if not set.outline then
		local b = set.bounds
		local t = b.owner:CreateTexture(nil, "BACKGROUND")
		Corner(t, "TOPLEFT", b.to, b.inset)
		Corner(t, "BOTTOMRIGHT", b.to, b.inset)
		set.outline = t
		set.Undress = function() t:Hide() end
	end
	set.outline:Show()
	return set.outline
end

-- A header on a frame of the game's: the panel plate with the title strip of one of UI.HEAD's sizes
-- ("window" unless told), Blizzard's title in the display font of that size, left in the strip past
-- the icon. Returns the plate's parts.
--   kit:Head(frame, { size, height (the strip's height: UI.HeadSize), to, inset (or x, y), key, cap, hud, brackets, fill, border,
--                     text = the title font string, icon = a texture (true: room kept for one),
--                     right = room kept at the right (the × button's, unless told) })
function Kit:Head(owner, opts)
	opts = opts or {}
	local size = UI.HeadSize(opts.size or "window", opts.height)
	local x, y = opts.x or 0, opts.y or 0
	local inset = opts.inset or { x, y, x, y }
	local set = self:Plate(owner, { key = opts.key, panel = true, to = opts.to, inset = inset, cap = opts.cap,
		hud = opts.hud, brackets = opts.brackets, fill = opts.fill, border = opts.border, window = true,
		title = opts.cap and size.line or size.line - 2, lip = size.lip })
	local to = opts.to or owner
	local mid = UI.HeadStripMid(set, size)
	-- From the left, nested inside the look's border (UI.HeadLeft): the icon, then the title. `headLeft` is where
	-- the strip's content begins, for an owner that stands its own icon there.
	local left = UI.HeadLeft(set, size)
	set.headLeft = left
	if opts.icon then
		if opts.icon ~= true then self:Place(opts.icon, size.icon, size.icon, { "LEFT", to, "TOPLEFT", left, mid }) end
		left = left + size.icon + 6
	end
	if opts.text then
		-- Color first, so the kit records Blizzard's: a font object brings its own. The ink the look's title ground
		-- reads in (UI.TitleInk), and the words named the head's title (a look may set them off: UI.LookTitle).
		self:Text(opts.text, C.text)
		self:FontObject(opts.text, UI.TitleFont(size.text))
		self:Text(opts.text, { UI.TitleInk(C.text) })
		if set.look then UI.LookTitle(set.look, opts.text) end
		set.titleText, set.titleLeft = opts.text, left
		local house = { bounds = set.bounds, look = set.look, plate = set.plate, strip = set.strip,
			headY = set.headY, headTo = set.headTo, headStripTop = set.headStripTop, headLine = set.headLine,
			titleText = opts.text, titleLeft = left }
		local right = opts.right or UI.HeadRail.TitleRight(house, { leading = opts.leading }, size)
		-- Some windows size their title for Blizzard's smaller font.
		self:Place(opts.text, nil, size.text + 2, { "LEFT", to, "TOPLEFT", left, mid }, { "RIGHT", to, "TOPRIGHT", -right, mid })
		self:Justify(opts.text, "LEFT")
	end
	return set
end

function Kit:Restore()
	for region, e in pairs(self.seen) do
		if e.follows then Slot.Unfollow(region) end
		if e.shaded then Slot.Unswipe(region) end
		if e.art then
			if e.sliced then region:ClearTextureSlice() end
			if e.art.atlas then
				region:SetAtlas(e.art.atlas)
			else
				region:SetTexture(e.art.file)
				region:SetTexCoord(unpack(e.art.coords))
			end
			if e.tiled ~= nil then region:SetHorizTile(e.tiled) end
		end
		-- A hatched fill handed back to Blizzard must be un-tiled.
		if e.bar then
			region:SetStatusBarTexture(e.bar)
			region:GetStatusBarTexture():SetHorizTile(e.barTiled)
		end
		if e.blend then region:SetBlendMode(e.blend) end
		if type(e.points) == "table" then
			region:ClearAllPoints()
			if #e.points == 0 and region:IsObjectType("Frame") then
				-- A frame with no anchors was not placed yet (one of ours, stood on a header by a rail): it keeps its
				-- size, never stretched over its parent.
				if e.size[1] > 0 and e.size[2] > 0 then region:SetSize(e.size[1], e.size[2]) end
			elseif #e.points == 0 then
				region:SetAllPoints()   -- it had no anchors: it filled its frame
			else
				-- (Each was made whole when it was read, ReadPoints: put back as it is.)
				for _, point in ipairs(e.points) do
					region:SetPoint(point[1], point[2], point[3], point[4], point[5])
				end
				if e.size[1] > 0 and e.size[2] > 0 then region:SetSize(e.size[1], e.size[2]) end
			end
		end
		if e.mask then region:AddMaskTexture(e.mask) end
		if e.crop then region:SetTexCoord(unpack(e.crop)) end
		if e.color then
			-- Keep the current alpha: Blizzard may have faded it since.
			local ok, _, _, _, a = Read(region, "GetVertexColor")
			if ok then region:SetVertexColor(e.color[1], e.color[2], e.color[3], a) end
			if e.gray ~= nil then region:SetDesaturated(e.gray) end
		end
		-- Font before text color and side: a font object brings its own color and its own side.
		if e.states then
			if e.states[1] then region:SetNormalFontObject(e.states[1]) end
			if e.states[2] then region:SetHighlightFontObject(e.states[2]) end
			if e.states[3] then region:SetDisabledFontObject(e.states[3]) end
		end
		if e.font then
			if e.font.object then
				region:SetFontObject(e.font.object)
			else
				region:SetFont(e.font.file, e.font.size, e.font.flags)
			end
		end
		if e.justify then region:SetJustifyH(e.justify) end
		if e.text then
			local ok, _, _, _, a = Read(region, "GetTextColor")
			if ok then region:SetTextColor(e.text[1], e.text[2], e.text[3], a) end
		end
		if e.alpha then region:SetAlpha(e.alpha) end
	end
	wipe(self.seen)
	for set in pairs(self.own) do
		for _, region in ipairs(set) do region:Hide() end
		if set.Undress then set:Undress() end   -- a slot
	end
	wipe(self.own)
end
