-- Shy.UI: the widgets, panels, fonts, menus and helpers every addon builds its UI from.
--
-- Widgets take get/set callbacks and have :Refresh(). Optional `opts`:
--   desc    = hover text
--   enabled = function() -> bool; the widget dims and ignores input when false
--   width   = width in UI units
--
-- A group refreshes every widget in it after any change (a slider with opts.settle: once its knob is let go):
--   local g = UI.Group(function() --[[ apply settings ]] end)
--   g:Checkbox(parent, "Label", get, set, opts)   g:Switch(...)   g:Slider(...)   g:Dropdown(...)
--   g:ColorSwatch(...)   g:Input(...)   g:Add(widget)   g:Refresh()
--
-- Surfaces:
--   UI.Panel(frame, opts)   -- window, on-screen box or card: fill inside a beveled edge with corner
--                           -- brackets. opts: fill, title = title strip height, line = false,
--                           -- brackets = false.
--                           -- hud = true: uses the opacity setting (C.hud, C.hudStrip); windows don't.
--                           -- glazed = true: a window that does (its header a window's: the bags).
--                           -- cap = true: a console piece. `title` is then the header's full height
--                           -- from the top edge to its line (UI.HEAD_STRIP); folds in the bottom
--                           -- corners (facets = false for none); no brackets without a title.
--                           -- cap = "both" adds a bar along the foot (UI.CAP_H).
--                           -- A panel with hud or cap wears the theme's look (see "The looks":
--                           -- forged, steel, clear, eclipse); look = one of them fixes it (a sample).
--   UI.SetLook(frame, look)   UI.LookCard(parent, width, look, opts)   -- the looks, picked and shown
--   Shy.Top.Make            -- the top column's plaque (pointed ends on a soft shadow, the weave, the ring),
--                           -- for any piece that should read as the column's; it follows the look too
--   UI.Skin(frame, bg, border)   -- a control or row: flat, thin border
--   UI.SetFill(frame, color), UI.SetBorder(frame, color)   -- work on both
--   UI.Concentric(ring, ...)   -- a ring and what stands in its middle share one middle (see below)
--
-- Headers and windows (one design, three sizes: UI.HEAD):
--   UI.Head(frame, opts)    -- the panel and its header: title strip, accent line, title, icon, ×, buttons, tabs
--   UI.Window(opts)         -- a Shy.HUD window on a panel with a header; Esc closes it (opts.dock: beside another, as HUD's)
--   UI.Body(window)         -- where a window's content stands: clear of its look's work round the edge, the window
--                              that much bigger (UI.BodyFit(f, w, h) for one that sizes itself, UI.BodySize)
--   UI.Close(parent, size, glyph, onClick)   -- the × button
--
-- Colors: UI.colors tables change in place with the theme. Color regions through
--   UI.Paint(texture, color, alpha)   UI.Tint(texture, color, alpha)   UI.Ink(fontString, color, alpha)
-- and they follow a theme change (UI.Text, UI.Skin and UI.Panel already do). Pass the table, never
-- a copy of its numbers.
--
-- Text and fonts: UI.Text, UI.Header, UI.Lead, UI.NameFont, UI.TextFont, UI.TitleFont, UI.TitleFace, UI.Follow, UI.FontPicker,
-- UI.Money, UI.PlainText
-- Hover text: UI.Tip, UI.TipHide, UI.Help, UI.Lines (Hover.lua)
-- Also: UI.Button, UI.Press, UI.Menu, UI.ContextMenu, UI.TellMenu, UI.Tabs, UI.Rail, UI.GlyphArt, UI.ScrollArea, UI.PageHeader, UI.Spinner,
-- UI.ShowCopyBox, UI.OpenColorPicker, UI.Themed, Shy.Reload. Each is documented where it is defined.

local UI = {}
Shy.UI = UI

local B, Theme = Shy.Brand, Shy.Theme
local abs, floor, max, min = math.abs, math.floor, math.max, math.min

--   bg, bgHot   controls and cards; buttons        panel   windows, menus
--   row, rowEdge   list rows                       fill    on, selected, primary
--   border      thin edges                         hot     hover, focus
--   text, dim, head   body text, dim text, section headers
--   alert (gold: unread, needs attention), good (done, full, yes), bad (no, declined)
UI.colors = Theme.ui
local C = UI.colors

UI.Paint, UI.Tint, UI.Ink = Theme.Paint, Theme.Tint, Theme.Ink

UI.EDGE = Shy.MEDIA .. "PanelEdge"     -- a panel's beveled edge: a nine slice with an empty middle
UI.BRACKET = Shy.MEDIA .. "Bracket"    -- top left corner bracket; mirrored for the other three
UI.GLOSS = Shy.MEDIA .. "Gloss"        -- highlight over a title strip or bar
UI.FROST = Shy.MEDIA .. "Frost"        -- uneven texture over a tooltip's fill (UI.Frost)
UI.GLASS = Shy.MEDIA .. "Glass"        -- denser frosted glass: the sheet over a piece in the layout editor
UI.EDGE_SLICE = 8
UI.BRACKET_SIZE = 10                   -- the one bracket size, on every panel
UI.LINE = 2                            -- the accent line's height
-- Headers: one design in three sizes. `line` is where the accent line starts, down from the panel's
-- top edge; `lip` is what the strip keeps clear at its top, and what stands in the strip is centred
-- between the lip and the line, `pad` in from the sides. Text is the display font at `text`, a
-- logotype (B.CreateTitle) at `brand`; a `window` carries a small icon, a `main` window the emblem. `control` is
-- how tall what stands in the strip is (the ×, its buttons), with as much room over it as under, between the lip
-- and the line; `close` the room each glyph control takes at the strip's right, the ×'s first (the game's windows
-- keep it too): the control and 2, so a row of them (minimize, maximize, ×) stands 2 apart; `glyph` the glyph
-- `clear` extra inset from the plate rim so controls and their borders do not touch a thick frame (Shy.Skin).
-- drawn in one, in whole pixels (UI.GlyphFit). Every window control's glyph fills the same share of its art, so
-- they read as one set at this size. `apart` is what stands between two controls in the row at the strip's right
-- (the ×, a maximize, a text button: one tight cluster, as `close` counts it); `gap` what the title keeps clear of
-- that cluster; `rowPad` the least the cluster keeps from the look's inner face (the × keeps as much room at its
-- right as over it, UI.HeadCloseRight, so its corner is square).
UI.HEAD = {
	piece  = { line = 20, lip = 4, pad = 8, text = 12, close = 16, control = 14, glyph = 10, apart = 2, gap = 8, rowPad = 1 },   -- console pieces, cards, prompts
	window = { line = 26, lip = 2, pad = 8, text = 14, brand = 16, icon = 16, close = 22, control = 20,
		glyph = 12, clear = 2, apart = 2, gap = 8, rowPad = 1 },  -- windows, and the game's own
	main   = { line = 40, lip = 2, pad = 12, text = 18, brand = 22, emblem = 28, tabs = 17, close = 28, control = 26, glyph = 14,
		apart = 2, gap = 8, rowPad = 1 },  -- an addon's main window
}
UI.HEAD_STRIP, UI.HEAD_LIP = UI.HEAD.piece.line, UI.HEAD.piece.lip   -- a console piece's header and lip

-- A header size by name, at a height of its owner's choosing: the size's own table, or (a height given) one that reads
-- through to it with its own `line`, the strip's height from the top edge (its words and controls stand on the middle
-- of what lies between the lip and the line, so they follow it). Both header makers take it as `opts.height`
-- (UI.Head, kit:Head); a number of units, at least the control and its rows (so a control never overruns its strip).
--   local size = UI.HeadSize("window", 34)
function UI.HeadSize(name, height)
	local size = UI.HEAD[name or "piece"] or UI.HEAD.piece
	if type(height) ~= "number" or height == size.line then return size end
	local least = (size.control or 0) + 2 * (size.rowPad or 1) + (size.lip or 0) + 2
	return setmetatable({ line = math.max(height, least) }, { __index = size })
end
-- Where a header's words and controls stand: down from its top edge, the middle between its lip and its line
-- (a console piece's; UI.Head's head.mid for each size). Every header's title stands there, none nudged.
UI.HEAD_MID = (UI.HEAD.piece.lip + UI.HEAD.piece.line) / 2
UI.CAP = Shy.MEDIA .. "Cap"            -- riveted bar; flipped, it is the housing's foot
UI.CAP_H, UI.CAP_END = 11, 22          -- its height, and the width of each end (of 96 texels)
UI.RIB = Shy.MEDIA .. "Rib"            -- join between two pieces (tiles vertically, 16 x 30)
UI.FACET = Shy.MEDIA .. "Facet"        -- fold rising from a piece's bottom left corner

local function Sound(kit)
	PlaySound(SOUNDKIT[kit])
end

-- Basics

-- r, g, b, a of a fill color: a palette table, any { r, g, b, a } or a function returning them.
local function Color(c)
	if type(c) == "function" then
		local r, g, b, a = c()
		return r, g, b, a or 1
	end
	return c[1], c[2], c[3], c[4] or 1
end
local SLAB = { 0.03, 0.03, 0.035 }   -- the eclipse's slab: its title strip, and the tone its controls lean to
UI.LookSlab = SLAB
-- The riveted look's steel: what its fill leans to (by STEEL_TONE); its strip a darker band of the same plate,
-- thin enough that the plate's sheen shows through it (STRIP_STEEL, at STRIP_STEEL_A of the strip's opacity).
local STEEL, STEEL_TONE, STRIP_STEEL, STRIP_STEEL_A = { 0.15, 0.155, 0.17 }, 0.8, { 0.08, 0.083, 0.092 }, 0.6

local function Blend(r, g, b, tr, tg, tb, k)
	return r + (tr - r) * k, g + (tg - g) * k, b + (tb - b) * k
end
UI.LookBlend = Blend

-- The looks of their own files (Looks/*.lua), by key: UI.LookKind's (see "The looks").
UI.LOOK_KINDS = {}
local KINDS = UI.LOOK_KINDS

-- A title strip by look, from the color it has in the forged make (r, g, b, a: a window's, solid; a piece
-- on screen's, at its look's opacity). Each its own: Forged the strip as it is, under a gloss; Glass no
-- band at all, the header the pane itself, lit along its top edge in your color; Frosted a band of frost,
-- whiter than the pane under it, matte; Eclipse the slab, matte, its line flaring; Riveted a darker band of the
-- plate, its sheen showing through, its line a trim of metal anodized in your color (UI.LOOK_ZONES). A look of its
-- own file says its own (UI.LookKind's `strip`).
-- Returns r, g, b, a and whether the gloss lies on it.
local STRIP_GLASS, STRIP_FROST = 0.18, { 1, 1, 1, 0.09 }
function UI.LookStrip(look, r, g, b, a)
	local kind = KINDS[look]
	if kind then
		if kind.strip then return kind.strip(r, g, b, a) end
		return r, g, b, a, false
	end
	if look == "eclipse" then return SLAB[1], SLAB[2], SLAB[3], a, false end
	if look == "steel" then return r, g, b, a * STRIP_GLASS, true end
	if look == "clear" then return STRIP_FROST[1], STRIP_FROST[2], STRIP_FROST[3], STRIP_FROST[4], false end
	if look == "riveted" then return STRIP_STEEL[1], STRIP_STEEL[2], STRIP_STEEL[3], a * STRIP_STEEL_A, false end
	return r, g, b, a, true
end

-- A housing's fill by look, from its color in the forged make: the riveted look's leans to steel, a look of its own
-- file says its own; the others keep the color (their alpha is UI.LookAlpha's).
function UI.LookFill(look, r, g, b, a)
	local kind = KINDS[look]
	if kind and kind.fill then return kind.fill(r, g, b, a) end
	if look == "riveted" then r, g, b = Blend(r, g, b, STEEL[1], STEEL[2], STEEL[3], STEEL_TONE) end
	return r, g, b, a
end

-- A control's colors toned by the look (resolved as they are painted, so a change of look repaints them):
-- Glass a steel rim; Frosted a lighter fill and a rim of light; Eclipse a darker fill with a hairline of your
-- color; Riveted a fill of steel; a look of its own file its own. Forged is the color itself. Meaning colors (good, bad, alert, the
-- accent's fill) are never toned.
local SLAB_TONE = 0.45
local function ToneFill(c)
	return function()
		local r, g, b, a = Color(c)
		local look = Theme.Look()
		if c == C.good or c == C.bad or c == C.alert or c == C.fill then return r, g, b, a end
		local kind = KINDS[look]
		if kind then
			if kind.toneFill then r, g, b = kind.toneFill(r, g, b) end
			return r, g, b, a
		end
		if look == "eclipse" then r, g, b = Blend(r, g, b, SLAB[1], SLAB[2], SLAB[3], SLAB_TONE)
		elseif look == "clear" then r, g, b = Blend(r, g, b, 1, 1, 1, 0.08)
		elseif look == "riveted" then r, g, b = Blend(r, g, b, STEEL[1], STEEL[2], STEEL[3], STEEL_TONE * 0.6) end
		return r, g, b, a
	end
end
local function ToneBorder(c)
	return function()
		local r, g, b, a = Color(c)
		local look = Theme.Look()
		if c == C.good or c == C.bad or c == C.alert or c == C.hot then return r, g, b, a end
		local kind = KINDS[look]
		if kind then
			if kind.toneBorder then r, g, b = kind.toneBorder(r, g, b) end
			return r, g, b, a
		end
		if look == "eclipse" then
			local ar, ag, ab = Theme.Accent()
			r, g, b = Blend(r, g, b, ar, ag, ab, 0.35)
		elseif look == "clear" then r, g, b = Blend(r, g, b, 1, 1, 1, 0.22)
		elseif look == "steel" then
			local m = Theme.skin.metal
			r, g, b = Blend(r, g, b, m[1], m[2], m[3], 0.3)
		end
		return r, g, b, a
	end
end

function UI.Skin(f, bg, border)
	if not f.shyBg then
		f.shyBg = f:CreateTexture(nil, "BACKGROUND")
		f.shyBg:SetAllPoints()
		local e = {}
		for i = 1, 4 do
			e[i] = f:CreateTexture(nil, "BORDER")
			-- A one-unit line snapped to the pixel grid can fall between two pixels and vanish at some
			-- screen positions (a tile's right edge at one place and not another): drawn sub-pixel instead.
			e[i]:SetSnapToPixelGrid(false)
			e[i]:SetTexelSnappingBias(0)
		end
		e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
		e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
		e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
		e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
		f.shyEdges = e
		f.shyControl = true   -- a control: its colors toned by the look (UI.SetFill, UI.SetBorder)
	end
	UI.SetFill(f, bg or C.bg)
	UI.SetBorder(f, border or C.border)
end

local KeyLook   -- a button's make, painted for its state (see "Buttons")

function UI.SetFill(f, c)
	f.shyFill = c
	if f.shyButton then
		f.shyButton.fill = c
		return KeyLook(f)
	end
	local h = f.shyLook
	if h then
		-- A housing with a look: the fill's color and (on screen) its alpha are the look's (UI.LookFill,
		-- UI.LookAlpha), read as it is painted.
		Theme.Paint(f.shyBg, function()
			local r, g, b, a = Color(f.shyFill)
			return UI.LookFill(h.look, r, g, b, h.solid and a or UI.LookAlpha(h.look, a))
		end)
	elseif f.shyControl and type(c) == "table" then
		Theme.Paint(f.shyBg, ToneFill(c))
	else
		Theme.Paint(f.shyBg, c)
	end
end

-- A ring and what stands in its middle (a sign, a picture, a hand), each centred on the same point. Snapped
-- to the pixel grid, each texture's edges go to the nearest pixel by its own size, so a 29 unit ring and a
-- 12 unit sign could each round a different way and the sign stood a pixel off the middle. Drawn where they
-- truly lie, they share one middle at any scale. (At a screen's scale a ring's texels seldom fall one to a
-- pixel, so it is filtered either way: little is lost.)
function UI.Concentric(...)
	for i = 1, select("#", ...) do
		local texture = select(i, ...)
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
end

-- Stands in for a blur, which the client can't do: a tiled, uneven layer of the fill color (or
-- `color`) over a tooltip's fill, so text behind it is broken up. It only adds opacity.
function UI.Frost(texture, color)
	texture:SetTexture(UI.FROST, "REPEAT", "REPEAT")
	texture:SetHorizTile(true)
	texture:SetVertTile(true)
	Theme.Tint(texture, color or C.panel, 1)
end

function UI.SetBorder(f, c)
	if f.shyButton then
		f.shyButton.rim = c
		return KeyLook(f)
	end
	if f.shyEdge then
		Theme.Tint(f.shyEdge, c)   -- a panel's edge is a texture file: tint, not paint
		f.shyMetal = c
		if f.shyLook then Theme.Tint(f.shyLook.edge, c) end   -- the steel look's thin edge, the same
		return
	end
	local color = (f.shyControl and type(c) == "table") and ToneBorder(c) or c
	for _, e in ipairs(f.shyEdges) do Theme.Paint(e, color) end
end

-- point, then tex coords that mirror the bracket art for that corner.
local BRACKETS = {
	{ "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
	{ "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 },
}
UI.BRACKETS = BRACKETS

-- A cap bar along the top, or flipped along the foot: fixed ends, stretched middle, overhanging by one unit.
local function Cap(f, foot)
	local e = UI.CAP_END / 96
	local v0, v1 = 0, 1
	if foot then v0, v1 = 1, 0 end
	local side, y = foot and "BOTTOM" or "TOP", foot and -1 or 1
	local left = f:CreateTexture(nil, "BORDER", nil, 2)
	left:SetTexCoord(0, e, v0, v1)
	left:SetPoint(side .. "LEFT", -1, y)
	local right = f:CreateTexture(nil, "BORDER", nil, 2)
	right:SetTexCoord(1 - e, 1, v0, v1)
	right:SetPoint(side .. "RIGHT", 1, y)
	local bar = f:CreateTexture(nil, "BORDER", nil, 2)
	bar:SetTexCoord(e, 1 - e, v0, v1)
	bar:SetPoint("TOPLEFT", left, "TOPRIGHT")
	bar:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	for _, t in ipairs({ left, right, bar }) do
		t:SetTexture(UI.CAP)
		Theme.Tint(t, Theme.skin.metal)
	end
	left:SetSize(UI.CAP_END, UI.CAP_H)
	right:SetSize(UI.CAP_END, UI.CAP_H)
	return { left, bar, right }
end

-- The looks
--
-- Every housing that stays on screen during play (UI.Panel or kit:Plate with `hud` or `cap`) and every window
-- (UI.Head, kit:Head, or `window = true`) wears the look the theme names (Theme.Look()); a window keeps its
-- solid fill in every look, so what is written in it reads. Menus, hovers and the layout editor's own pieces
-- keep the forged make. A piece standing inside another housing (a window's inner plate, a card docked in a
-- deck) carries no look of its own (`looks = false`, UI.SetLook(frame, false)): one housing, one shade and one
-- halo; a plate whose housing is wider than its own rect fits the look to that (`looks = { to, inset }`).
-- Four looks, all of the family's graphite, each reaching the Background strength its own way:
--   forged   Forged: the family's frame, the beveled steel edge (PanelEdge) with brackets in your color at
--            the corners, the caps and facets a piece has
--   steel    Glass: a pane in the nameplates' thin beveled rim (PlateEdge, its corners a little rounded),
--            the hover's soft shade round it, your color as light in the top edge itself (HoverLight); the
--            fill solved against the shade so the two together reach the strength, so the world shows through
--   clear    Frosted: frosted glass, the world softened behind it (Frost over a thin tint of graphite), the
--            sky in the top of the pane, a slanted band of light across it when it is wide enough (Sheen),
--            a darker foot (the pane's thickness), its cut edge catching the light (Pane); a lighter shade,
--            the same light. A window (solid) keeps the rim and the light: its content is never under glass
--   eclipse  Eclipse: a dark slab with your color behind it: the light gets round its edge (Halo, a bright
--            line hugging the slab and a soft glow dying away on the world, added to it); a deeper fill
--            under a dark hairline (Pane worn black), a lighter shade; no light in the top edge; a matte
--            header strip, its accent line lit with a glow
--   stitched Stitched: worked leather, its own file (Looks/Stitched.lua)
--   riveted  Riveted: a flat plate of brushed steel riveted along its seams. Metal reads as metal by sheen over
--            most of it, not by a highlight on a dark plate: the fill leans to steel (UI.LookFill), the soft light
--            it reflects lies over nearly all of it (MetalSheen, stretched to the plate, brightest in a band across
--            the brushing), the grooves run one way (Brushed, faint and dark everywhere; BrushedLit, light, masked
--            by the sheen so the grooves show where the light is). Its edge a hairline bevel (MetalEdge), rows of
--            low rivets SEW in from it all round, one at each corner and the rest about PERIOD apart (Rivet, each
--            drawn for its size on screen and laid on whole pixels, so all are alike), each only lightening and
--            darkening the plate. A lighter shade; a darker foot on screen. The
--            strip a darker band of the plate, the sheen through it; the accent line as it is, a painted stripe
-- The title strip and the accent line stay in every look (Frosted etches the line lighter, Eclipse lights it
-- with a glow; a look of its own file lays its own). Every dressed housing is dressed again on SHY_THEME when the look changed; one made with `look`
-- in its opts keeps that look (a sample). The slots every icon stands in (Shy.Slot) and the bars' fill
-- (Skin.HATCH) follow the look too. No look moves a thing: the gaps pieces keep, their insets and their
-- rows are the same in every look (the eclipse's glow dies away under its neighbours).
--   UI.LOOK_NAMES / UI.LOOK_WORDS / UI.LOOK_SHORT   a look's name, its sentence and its few words
--   UI.LookAlpha(look, a)          the fill's alpha in that look for a piece that would be `a` in the forged make
--   UI.SetLook(frame, look)        dress a UI.Panel in a look (nil: the theme's again; false: none, an inner piece)
--   UI.SetAccent(frame, color)     its look's parts in your color wear `color` instead, for what the piece means (a
--                                  yell's red on a chat bubble); nil: the theme's again
--   UI.LookTail(h), UI.LookEdges(h)   a tail off its foot in the look's own make; the regions drawing its edge
--   UI.LookCard(parent, w, look, opts)   a card showing a housing in that look over a scene (setup, the hub)
--   UI.LookArt                     the files and measures, for whoever draws a housing as a picture
--   UI.LookBuild / UI.LookDress    the regions and their dressing, for Shy.Skin's plates
--   UI.LookContent(h, keep)        where a housing's content stands: a look with a well sinks it there
--   UI.LookLine(owner, line, look, strip)   a header's line by look (the eclipse's flare); an inner piece's too
-- More looks live in files of their own (Looks/*.lua), each registered with UI.LookKind (its comment lists the
-- fields) and worn like these; what they share:
--   UI.LookSeed(h, salt)           a housing's own pair 0 to 1 (where a tiling sheet starts on it)
--   UI.LookPool(h, name, layer, sub)   regions laid as many as its size calls for (:Get(i), :Done(used))
--   UI.LookPixel(h), UI.LookStamp(h, t, x, y, size, per, right, bottom)   art drawn a texel a pixel, on whole pixels
--   UI.LookAccent(h or owner)      the accent to tint with (a sample's own, else the theme's)
--   UI.LookOption(h or owner, key, look)   an option as it wears it (a sample's own, else Theme.LookOption): a look
--                                  reads every option through this, and dresses only its own housing's regions
--   UI.LookFace(h, under, behind)  a housing over its content lays its face (and any a look makes later) under it,
--                                  and what lies behind it (its shade, its halo) on `behind`
--   UI.LookZones(h, head, foot), UI.LookContent(h, keep), UI.LookFoot(h, info), UI.LookOwnsFoot(h)
--   UI.LookOptions(parent, opts)   a look's options as controls (Theme.LookOption keeps them)
--   UI.LookUnder(region)           a kind's region moved under a game window's own art
-- Every header is made of the same parts, whoever draws it (UI.Panel, UI.Head, a kit's plate or kit:Head):
--   UI.HeadLine(owner, under)      the accent line, the one make (UI.LINE fitted to the pixel: UI.LineFit)
--   UI.LineMark(owner, line, c)    a lit stretch of it (an open tab); kit:Mark on a game frame
--   UI.TitleText(parent, t, size)  a header's words in the title font; UI.HEAD's sizes
--   UI.OnHead(region, point, house, side, x)   placed on a header's middle (UI.HEAD_MID on a console piece)
--   UI.HeadRail.Pack(house, pack, kit)   a skinned game window's title strip: the × and pack.leading stood on
--                           UI.HeadStripMid, packed right to left from UI.HeadCloseRight (inside the look's
--                           border, UI.LookBorder), each UI.HEAD's `apart` from the one before.
--   UI.LookBorder(look or housing)   the look's border: left, top, right, bottom its frame's inner face stands in
--   UI.HeadLeft(house, size), UI.HeadCloseRight(house, size)   where a header's words begin and its × stands
--   UI.PanelHead(f, shown)         a panel's header put away whole, or shown (a piece docked under another's)
--   UI.FillSwatch / UI.SlotSwatch  a bar's fill, two slots, at true size: a pick seen before it is made

-- The looks' ids are older than their names: `steel` is Glass (a pane in a thin steel rim), `clear` is Frosted.
UI.LOOK_NAMES = { forged = "Forged", steel = "Glass", clear = "Frosted", eclipse = "Eclipse", riveted = "Riveted" }
UI.LOOK_WORDS = {
	forged = "A beveled steel frame with brackets in your color at its corners.",
	steel = "A pane of glass in a thin steel rim, lit along the top in your color.",
	clear = "Frosted glass that softens the world behind it.",
	eclipse = "A dark slab with your color glowing around its edge.",
	riveted = "A plate of brushed steel, riveted along its seams.",
}
UI.LOOK_SHORT = { forged = "A bracketed steel frame", steel = "Glass in a steel rim", clear = "Frosted glass", eclipse = "A dark slab, lit from behind",
	riveted = "Riveted brushed steel" }

local LOOK = {
	EDGE = Shy.MEDIA .. "PlateEdge", PANE = Shy.MEDIA .. "Pane", HALO = Shy.MEDIA .. "Halo",
	SHADE = Shy.MEDIA .. "HoverShade", LIGHT = Shy.MEDIA .. "HoverLight", SHEEN = Shy.MEDIA .. "Sheen",
	EDGE_SLICE = 4,                    -- PlateEdge's and Pane's nine slice
	-- Every nine slice the looks wear is its two margins and this sliver between, each way: the game shrinks a nine
	-- slice's margins whenever its region is smaller than its file, so a file drawn larger squeezed its border on a
	-- short piece (a piece folded to its header stood wider, its border thicker). UI.LookLeast: how small a piece
	-- a part draws true on.
	SLIVER = 2,
	FILL_IN = 2,                       -- the fill is set this far in, under the edge's band
	HALO_REACH = 16, HALO_SLICE = 20,  -- Halo reaches this far past the piece; its nine slice
	SHADE_SLICE = 28, SHADE_REACH = 18, SHADE_DROP = 3,   -- HoverShade's slice; it reaches this far past the piece, dropped a little
	SHADE_MID = 0.5,                   -- how dark the shade is under the whole piece: the steel fill is solved against it
	LIGHT_H = 12, LIGHT_IN = 4,        -- HoverLight's height; it stops this short of each end
	-- The light along the seam over a typing row (a chat window's edit box): its top row the lit seam, a glow
	-- under it, easing away to nothing at its right end. A texel a unit; tinted with the channel's color.
	SEAM = Shy.MEDIA .. "SeamLight", SEAM_H = 12,
	REST = 0.6,                        -- the light's (and the halo's) strength at rest
	-- Clear: the shade under the pane is lighter (glass casts less); the fill is this share of the strength; the sky
	-- lies in the top of the pane (white, `sky` at the top edge, gone `down` of the height down); the band of light
	-- crosses it from `at` of its width when there is room; the foot is darker, `footH` tall at most.
	CLEAR = { shade = 0.7, fill = 0.55, sky = 0.16, down = 0.45, sheen = 0.08, at = 0.22, foot = 0.30, footH = 10, frost = 0.5 },
	-- Eclipse: the shade under the slab (the light has something dark to fall on); the fill set in under the hairline.
	ECLIPSE = { shade = 0.8, inset = 1 },
	-- A button's face of hide: the grain (a texel a unit, tiled), unless its make names its own face.
	GRAIN = Shy.MEDIA .. "Grain",
	-- Riveted: the edge (a nine slice, a texel a unit), the brushing (a texel a unit, tiled), the sheen (stretched),
	-- the rivet (RIVET: a cell for each size in pixels from RIVET_CELLS.least to .most, left to right a texel
	-- apart; four rows of them, most + 1 apart: the rivet's middle on texel S // 2 of cell S, on its left edge,
	-- on its top edge, on both; the file w x h).
	METAL_EDGE = Shy.MEDIA .. "MetalEdge", METAL_EDGE_SLICE = 4, BRUSHED = Shy.MEDIA .. "Brushed", BRUSHED_LIT = Shy.MEDIA .. "BrushedLit",
	METAL_SHEEN = Shy.MEDIA .. "MetalSheen", RIVET = Shy.MEDIA .. "Rivet", RIVET_CELLS = { least = 4, most = 24, w = 314, h = 99 },
	-- Its shade, lighter (a flat plate casts little); the fill set in under the edge's dark line; a rivet's middle
	-- SEW in from the edge (or, round a content sunk in a well, half way between the edge's bevel, EDGE in, and the
	-- well), the rivets about PERIOD apart, a rivet's cell ROW across, none on a piece under LEAST; the sheen's
	-- strength on screen and in a window (SOLID of it), the lit grooves', the foot's dark.
	RIVETED = { shade = 0.6, inset = 1, sew = 4.5, edge = 2, period = 24, row = 6, least = 24, sheen = 0.85, solid = 0.7, lit = 1, foot = 0.5 },
	-- A content well's edge (a nine slice, a texel a unit), and a head's line worn as a trim of metal (tiling across):
	-- see UI.LOOK_ZONES.
	METAL_WELL = Shy.MEDIA .. "MetalWell", WELL_SLICE = 4, METAL_TRIM = Shy.MEDIA .. "MetalTrim",
}
UI.LookArt = LOOK
-- The zones of a housing: its head (from its top edge down to where the title strip's line is), its content (from
-- there down to its foot) and its foot (a band along the bottom some pieces have: chat's typing row). A look may
-- wear each its own way; one that names no zones wears the housing whole. The housing knows its head and foot
-- (h.zoneHead, h.zoneFoot: UI.Panel and kit:Plate set the head from their title strip, an owner sets the rest through
-- UI.LookZones); a housing with no head has no zones, unless its owner says where its content stands
-- (UI.LookContent: the console's buttons): then that content is sunk, GAP round it, and the plate is a rim.
--   trim   the head's accent line worn as a trim of metal anodized in your color (art: lit along its top, darker
--          toward its foot, faintly brushed; tinted): the head itself stays the plate's, the color only in the line
--   well   the content sunk below the plate: a darker fill (color at alpha, following the strength on screen) under
--          an inset bevel (art, its slice), IN in from the sides and the foot, flush under the head: hairlines in
--          the margin a piece already keeps, so nothing moves. A look's own furniture keeps out of the well (the
--          riveted look's rivets stand only along the head, and along the foot when it is tall enough for them)
--   footWell  the foot band sunk the same way (color, alpha, solid, art, slice, IN): from IN over the bottom edge up
--          to a seam under the content's well, IN in from the sides
UI.LOOK_ZONES = {
	riveted = { trim = LOOK.METAL_TRIM, well = { color = { 0.035, 0.037, 0.042 }, alpha = 0.62, solid = 0.62, art = LOOK.METAL_WELL, slice = LOOK.WELL_SLICE, IN = 3, GAP = 1 } },
}
-- Every region of the looks other than the forged make's (UI.LookBuild), by name: what a kit records and a fade
-- fades. The rivets are made as a housing's size calls for them (h.rivets, recorded as they are made): a fade
-- takes them with the rest from UI.LookParts(h).
UI.LOOK_PARTS = { "shade", "halo", "edge", "pane", "frost", "sky", "sheen", "foot", "light",
	"brushed", "plateSheen", "brushedLit", "metalEdge",
	"wellFill", "well", "rimTop", "rimBottom", "rimLeft", "rimRight", "footFill", "footWell" }
-- The parts that lie over the whole of a housing's face, not its edge (the riveted plate's brushing and sheen, a
-- well's dark; a look of its own file adds its own). A housing standing over its content (a map's border frame over the map)
-- lays them on a frame under the content instead; h.litMask goes with brushedLit, which it masks.
UI.LOOK_FACE = { "brushed", "plateSheen", "brushedLit", "wellFill" }
-- The parts that lie behind a housing, on the world round it (the shade, the halo; a look of its own file adds its
-- own). A housing standing over its content lays them on a frame of their own under it, never over the content.
UI.LOOK_BEHIND = { "halo", "shade" }
local DARK, WHITE = { 0, 0, 0 }, { 1, 1, 1 }
local looked = setmetatable({}, { __mode = "k" })   -- housing -> function dressing it in the theme's look again

-- A look of its own file (Looks/*.lua), registered once at load. Every field is optional but `name`:
--   name, words, short     its name, sentence and few words (UI.LOOK_NAMES, LOOK_WORDS, LOOK_SHORT)
--   zones                  its UI.LOOK_ZONES entry: trim, well, footWell (the zones above)
--   options                its options (Theme.AddLook): { key, label, kind = "choice" | "switch" | "slider",
--                          choices = { { value, text, item } } | min, max, step, default, desc }, read with
--                          Theme.LookOption (a choice's item: a game item's ID, its icon shown beside the choice)
--   alpha(a)               the fill's alpha for a piece that would be `a` in the forged make (UI.LookAlpha)
--   fill(r, g, b, a)       the fill's color (UI.LookFill); strip(r, g, b, a) -> r, g, b, a, gloss (UI.LookStrip)
--   toneFill(r, g, b), toneBorder(r, g, b)   a control's fill and edge (UI.Skin)
--   shade                  the shared shade's alpha under a piece on screen (false: none); inset the fill's inset
--   surface                { file, alpha, color }: the face a plaque, a card or a nameplate wears in it, for a look
--                          whose buttons lay their face in their own pieces (UI.LookMaterial)
--   miniArt() -> { rim, rimSlice, band, out, run, join, sides = { Top, Foot, Left, Right } }   its mini border (h.mini:
--                          the look's own smaller, simpler make, worn by `mini` housings: UI.Panel's and kit:Plate's
--                          `mini = true`) as files, for a piece that can't wear a housing (a nameplate): the rim's nine
--                          slice, and each side's run BAND across, OUT past the edge, RUN long (tiling), running JOIN on
--                          past each corner (<file>Key what of it is in your color); a look whose border is its rim alone
--                          (a bezel) names no sides. `face`: what lies over the piece's face, in layers laid by its size
--                          (each { file, tile = units a side (none: stretched), alpha, accent = in your color, add =
--                          added, at = { u, v } where it starts in the tile }): a look whose face is its own (a sky)
--   ring(size, tpu) -> { file, key, light, span, glow }   its border round a circle `size` across (UI.LookRing): the art,
--                          what of it is in your color, its light (added, your color lifted `glow` toward white), laid
--                          `span` across on the circle's middle. `tpu`: the texels a unit wanted (none: the HUD's two; 1
--                          on a nameplate, which is shown at about a pixel a unit and an addon's picture has no smaller
--                          copies to shrink to); a look with one set only gives that
--   rims                   false: no band round a placed content's well (UI.LookContent; drawn in the strip's color)
--   bar, slot              the bars' fill and the slots' finish it wears ("auto" picks)
--   strength, wells        the Background strength and the Icon wells (percents) it is at its best at: a preset in
--                          it puts them on as it goes on (Theme.BestStrength, Theme.BestWells)
--   ground                 its slots' well, under whatever finish frames them (a key of Shy.Slot.GROUNDS)
--   build(h, kit)          its regions on a housing, made the first time the housing is dressed in it: kit.Reg(name,
--                          region) records one (on h[name]; shown, hidden and faded with the look), kit.Out(region,
--                          out, drop) fits one to the housing `out` past its edges, kit.owner, kit.to, kit.inset
--   dress(h, p)            the housing dressed in it (p as UI.LookDress's): show and paint its regions. In any other
--                          look every region it recorded, and its pools', is hidden
--   fit(h, g)              laid out by size while it is worn and the housing shown, only when what it goes by
--                          changed (UI.LookFit; h.dressed counts its dresses, for what a fit sets once a dress):
--                          g = { w, tall, per, head, foot,
--                          inset, to, sunk, cleared (its content stands clear of `content`: a window's body,
--                          UI.Body; lay work inside the edge only then), well = { l, t, r, b } (units in from the
--                          plate) or nil, rim = { pixels
--                          each side } or nil, content, footInfo (UI.LookFoot), title (UI.LookTitle: the head's
--                          title words, or nil), titleOwn (they're ours to ink) }; again when the UI's scale changes
--                          or the title's words change
--   line(owner, line, strip) -> regions   what it lays over a header's line, made once a line, shown with the line
--                          while it is worn; lineAlpha the line's own alpha under them (0: put away)
--   title(fontString, on)  a header's words dressed in it (on), or given back (on false: the core's ink is put back)
--   titleInk() -> r, g, b  the ink that reads on the ground it sets a title off on (UI.TitleInk: words it doesn't letter)
--   face                   names of its regions and pools that lie over the face (UI.LOOK_FACE): a housing standing
--                          over its content (the world map's border) lays them under that content (UI.LookFace),
--                          with any mask they are cut by (h.faceMasks)
--   edge                   names of the rest: on its edge, its head or its foot band. Every region and pool a look
--                          lays is named in one or the other (a test holds every look to it)
--   behind                 those of its edge's that lie behind the piece, on the world round it (a halo,
--                          UI.LOOK_BEHIND): a housing standing over its content lays them under it (UI.LookFace)
--   text                   its own text effect (a Theme.TEXTS key), worn while the player picks none
--   scroll(area, thumb, track, on)   a scroll area's bar dressed its way (on), or given back (on false): it lays
--                          its own regions round the thumb and the track, keeps them shown as those are, and puts
--                          away what it doesn't wear (the track's alpha); the core keeps the bar's moving parts
--   content                how much further in than the family's own margins a window lays its content, so it
--                          stands clear of the look's work (UI.LookContentIn: a number, a table of four, or a
--                          function(housing))
--   border                 how far in from the piece's edge the frame's inner face stands (UI.LookBorder: a
--                          number for all four sides, { left, top, right, bottom }, or function(housing) for a
--                          frame that sizes itself: Heritage's Frame option). A header's icon and title nest
--                          inside its left, its controls inside its right, native and custom alike; content
--                          on screen inside the widest (UI.LookFillIn). A built-in look's is UI.LOOK_BORDER.
--   out                    how far past the piece's edge the frame is drawn (UI.LookOut: a number, or
--                          function(housing)); none said, it keeps inside the edge
function UI.LookKind(key, def)
	KINDS[key] = def
	UI.LOOK_NAMES[key], UI.LOOK_WORDS[key], UI.LOOK_SHORT[key] = def.name, def.words or "", def.short or def.name
	UI.LOOK_ZONES[key] = def.zones
	for _, name in ipairs(def.face or {}) do UI.LOOK_FACE[#UI.LOOK_FACE + 1] = name end
	for _, name in ipairs(def.behind or {}) do UI.LOOK_BEHIND[#UI.LOOK_BEHIND + 1] = name end
	Theme.AddLook(key, def.options)
	Theme.SetLookText(key, def.text)   -- its own text effect, worn while none is picked
	return def
end

-- A number pair 0 to 1 of a housing's own (salt: one use's), the same each time it is asked: where a tiling sheet
-- starts on it, so no two pieces are stamped from the same place. From its owner's name, else its own identity.
function UI.LookSeed(h, salt)
	salt = salt or ""
	-- (A housing keeps each pair it was asked: they are asked at every fit.)
	local kept, keptB = h.seeds, h.seedsB
	if kept and kept[salt] then return kept[salt], keptB[salt] end
	local key = h.seedKey
	if not key then
		local owner = h.owner
		key = owner.GetName and owner:GetName() or nil
		if type(key) ~= "string" then key = tostring(owner) end
		h.seedKey = key
	end
	local s = key .. salt
	local a, b = 5381, 7
	for i = 1, #s do
		local c = s:byte(i)
		a = (a * 33 + c) % 4294967296
		b = (b * 31 + c * 7) % 2147483647
	end
	local x, y = (a % 997) / 997, (b % 991) / 991
	if h.kinds then
		if not kept then
			kept, keptB = {}, {}
			h.seeds, h.seedsB = kept, keptB
		end
		kept[salt], keptB[salt] = x, y
	end
	return x, y
end

-- One of a list, a piece's own (salt: one use's), the same each time it is asked: a piece keeps its pick for as long
-- as it keeps its name (UI.LookSeed: a named window's for good, an unnamed frame's for the session). x: a housing, or
-- a frame (a header's owner, a button); nothing: the list's first.
--   local gem = UI.LookPick(h, GEMS, "gem")   -- this housing's gem
function UI.LookPick(x, list, salt)
	if not x or #list == 0 then return list[1] end
	local h = x.owner and x or { owner = x }
	local u = UI.LookSeed(h, salt)
	return list[min(#list, floor(u * #list) + 1)]
end

-- A look's movement, run by the game itself (an animation on the region: no Lua a frame, nothing on a hidden
-- region). Each is made once on a region and set again with every call; UI.LookStill stops them all. A region moving
-- so takes a ramp as one color (Theme's shyFlat: an animated alpha shows a gradient as white); tint it after.
--   UI.LookBreath(t, period, low)            a looping fade from whole to `low` and back over `period` seconds
--   UI.LookTwinkle(t, wait, long)            it comes up and goes over `long` seconds, then rests `wait` seconds; again
--   UI.LookDrift(t, dx, dy, time, rest)      it drifts dx, dy units over `time` seconds, coming up as it starts and
--                                            fading as it goes, rests `rest` seconds (none given: none); again
function UI.LookBreath(t, period, low)
	t.shyFlat = true
	local group = t.shyBreath
	if not group then
		group = t:CreateAnimationGroup()
		group:SetLooping("BOUNCE")
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetSmoothing("IN_OUT")
		t.shyBreath, t.shyBreathFade = group, fade
	end
	low = low or 0.6
	if t.shyBreathLow ~= low or t.shyBreathPeriod ~= period then
		t.shyBreathLow, t.shyBreathPeriod = low, period
		t.shyBreathFade:SetToAlpha(low)
		t.shyBreathFade:SetDuration(period / 2)
	end
	if not group:IsPlaying() then group:Play() end
end

function UI.LookTwinkle(t, wait, long)
	t.shyFlat = true
	local group = t.shyTwinkle
	if not group then
		group = t:CreateAnimationGroup()
		group:SetLooping("REPEAT")
		local up = group:CreateAnimation("Alpha")
		up:SetFromAlpha(0)
		up:SetToAlpha(1)
		up:SetOrder(1)
		local down = group:CreateAnimation("Alpha")
		down:SetFromAlpha(1)
		down:SetToAlpha(0)
		down:SetOrder(2)
		local rest = group:CreateAnimation("Alpha")
		rest:SetFromAlpha(0)
		rest:SetToAlpha(0)
		rest:SetOrder(3)
		t.shyTwinkle, t.shyTwinkleParts = group, { up, down, rest }
	end
	long, wait = long or 0.9, max(0.01, wait or 0.01)
	-- (Going already at this pace: left to run, not begun again.)
	if t.shyTwinkleLong == long and t.shyTwinkleWait == wait and group:IsPlaying() then return end
	t.shyTwinkleLong, t.shyTwinkleWait = long, wait
	local up, down, rest = unpack(t.shyTwinkleParts)
	up:SetDuration(long * 0.35)
	down:SetDuration(long * 0.65)
	rest:SetDuration(wait)
	t:SetAlpha(0)
	if not group:IsPlaying() then group:Play() end
end

function UI.LookDrift(t, dx, dy, time, rest)
	t.shyFlat = true
	local group = t.shyDrift
	if not group then
		group = t:CreateAnimationGroup()
		group:SetLooping("REPEAT")
		local move = group:CreateAnimation("Translation")
		move:SetOrder(1)
		local up = group:CreateAnimation("Alpha")
		up:SetFromAlpha(0)
		up:SetToAlpha(1)
		up:SetOrder(1)
		local down = group:CreateAnimation("Alpha")
		down:SetFromAlpha(1)
		down:SetToAlpha(0)
		down:SetOrder(1)
		local pause = group:CreateAnimation("Alpha")
		pause:SetFromAlpha(0)
		pause:SetToAlpha(0)
		pause:SetOrder(2)
		t.shyDrift, t.shyDriftParts = group, { move, up, down, pause }
	end
	dx, dy, rest = dx or 0, dy or 0, max(0.01, rest or 0.01)
	local set = t.shyDriftSet
	if set and set[1] == dx and set[2] == dy and set[3] == time and set[4] == rest and group:IsPlaying() then return end
	if not set then
		set = {}
		t.shyDriftSet = set
	end
	set[1], set[2], set[3], set[4] = dx, dy, time, rest
	local move, up, down, pause = unpack(t.shyDriftParts)
	move:SetOffset(dx, dy)
	move:SetDuration(time)
	up:SetDuration(time * 0.3)
	down:SetStartDelay(time * 0.3)
	down:SetDuration(time * 0.7)
	pause:SetDuration(rest)
	t:SetAlpha(0)
	if not group:IsPlaying() then group:Play() end
end

function UI.LookStill(t)
	if t.shyBreath then t.shyBreath:Stop() end
	if t.shyTwinkle then t.shyTwinkle:Stop() end
	if t.shyDrift then t.shyDrift:Stop() end
end

-- The accent a housing (or a header's owner) wears: a sample's own (UI.Panel's opts.accent: a preset's card shows
-- that preset's color while another is worn), else the theme's; a function either way, giving r, g, b. Tint with it
-- as with Theme.Accent (the theme's, passed as itself, follows a ramp).
function UI.LookAccent(x)
	return x and (x.accent or x.shyAccent) or Theme.Accent
end

-- A look option as a housing (or a header's owner) wears it: a sample's own (UI.Panel's opts.options: a preset's
-- card shows that preset's Frame or Wear while others are worn), else the theme's (Theme.LookOption). `look`: the
-- look it is asked of (the housing's own unless told). A look kind reads every option through this.
function UI.LookOption(x, key, look)
	local own = x and (x.options or x.shyOptions)
	if own and own[key] ~= nil then return own[key] end
	look = look or (x and (x.building or x.look)) or Theme.Look()
	return Theme.LookOption(look, key)
end

-- Pixels a unit where a housing stands, or nil while it can't be told.
function UI.LookPixel(h)
	local scale = h.owner:GetEffectiveScale()
	if not scale or issecretvalue(scale) or scale <= 0 then return nil end
	return scale / PixelUtil.GetPixelToUIUnitFactor()
end

-- A texture `size` pixels square, `x` and `y` whole pixels in from the plate's left (or right) and top (or foot)
-- edge: a cell of art drawn a texel a pixel lands on whole pixels wherever the housing's edges fall (as the rivets).
function UI.LookStamp(h, t, x, y, size, per, right, bottom)
	local to, inset = h.to, h.inset
	local corner = (bottom and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT")
	t:ClearAllPoints()
	t:SetPoint(corner, to, corner, right and -inset[3] - x / per or inset[1] + x / per, bottom and inset[4] + y / per or -inset[2] - y / per)
	t:SetSize(size / per, size / per)
end

-- A pool of like regions a look lays as many of as a housing's size calls for (rivets, bolts, ember spots): made
-- when first asked, recorded with the housing's parts, hidden with its look.
--   local pool = UI.LookPool(h, "bolt", "BORDER", 2)   -- made once; the same pool when asked again
--   pool:Get(i) -> the i-th texture; pool:Done(used) hides the ones past `used`
-- A pool over the housing's face (named in its look's `face`, or `face` true) is laid under the content on a housing
-- that stands over it (UI.LookFace), as the face's other parts are.
local Kin = { Pool = {}, UNDER = { BACKGROUND = 4, BORDER = 6, ARTWORK = 7, OVERLAY = 7 }, OPTION_GAP = 16, OPTION_ROW = 46 }   -- the kinds' machinery
Kin.Pool.__index = Kin.Pool
function Kin.Pool:Get(i)
	local t = self.list[i]
	if not t then
		t = self.h.owner:CreateTexture(nil, self.layer, nil, self.sublevel)
		self.list[i] = t
		if self.h.make then self.h.make(self.name .. i, t, true) end
		Kin.Claim(t)
		if self.face and self.h.faceOn then t:SetParent(self.h.faceOn) end
	end
	return t
end
function Kin.Pool:Done(used)
	for i = used + 1, #self.list do self.list[i]:Hide() end
end
-- A look option's choice may name a game item (choice.item: its ID): its icon shows beside the choice (the grove's
-- gems), or its own picture (choice.icon).
function Kin.ChoiceIcon(choice)
	if choice.icon then return choice.icon end
	if choice.item then return C_Item.GetItemIconByID(choice.item) end
end
function Kin.Listed(list, name)
	for _, n in ipairs(list or {}) do
		if n == name then return true end
	end
	return false
end
function UI.LookPool(h, name, layer, sublevel, face)
	local pool = h.pools[name]
	if not pool then
		local kind = h.building or h.look
		pool = setmetatable({ h = h, name = name, layer = layer or "BORDER", sublevel = sublevel or 0, list = {},
			kind = kind, face = face == true or Kin.Listed(KINDS[kind] and KINDS[kind].face, name) }, Kin.Pool)
		h.pools[name] = pool
	end
	return pool
end

-- A region of a look kind's (or a pool's) moved under a game window's own art, keeping its order among the others
-- (a housing built round a window of the game's lays the looks' regions in its BACKGROUND layer: `make`'s third
-- argument says a region is a kind's).
function UI.LookUnder(region)
	local layer, sub = region:GetDrawLayer()
	local at = Kin.UNDER[layer] or 6
	if layer == "BACKGROUND" then at = min(5, max(4, at + floor((sub or 0) / 8))) end
	region:SetDrawLayer("BACKGROUND", at)
end

-- The art a look's region wears, set again every time its housing (or its line) is dressed: a region whose picture
-- something else replaced (a skin's sweep over a game frame it stands on, a restore) comes back with the next dress,
-- never drawn as a solid block of its tint until a reload. And it is marked ours, so a skin leaves it be.
--   UI.LookWear(region, file, wrapH, wrapV, slice, tiled)   -- a file: its wrap, a nine slice's margin, tiled both ways
--   UI.LookWear(region, { atlas = name })                   -- an atlas of the game's
-- (UI.LookArt is the looks' files and measures, a table.)
Kin.art = setmetatable({}, { __mode = "k" })   -- region -> its art
function Kin.Again(region)
	local a = region and Kin.art[region]
	if not a then return end
	if a.atlas then
		region:SetAtlas(a.atlas)
	else
		region:SetTexture(a[1], a[2], a[3])
		if a[4] then region:SetTextureSliceMargins(a[4], a[4], a[4], a[4]) end
		if a[5] then
			region:SetHorizTile(true)
			region:SetVertTile(true)
		end
	end
end
function Kin.Claim(region)
	local skin = Shy.Skin
	if skin and skin.Claim then skin.Claim(region) end
end
function UI.LookWear(region, file, wrapH, wrapV, slice, tiled)
	local a = Kin.art[region]
	if type(file) == "table" then
		Kin.art[region] = file
	elseif a and not a.atlas then
		a[1], a[2], a[3], a[4], a[5] = file, wrapH, wrapV, slice, tiled   -- (its own list, kept: nothing made at each fit)
	else
		Kin.art[region] = { file, wrapH, wrapV, slice, tiled }
	end
	Kin.Again(region)
	Kin.Claim(region)
	return region
end

-- Every housing a look dresses (the audit's).
Kin.all = setmetatable({}, { __mode = "k" })

-- A housing's art given back without dressing it again (every theme change, when its look and options stay): every
-- part's and its line's, then what goes by size laid on it again.
function UI.LookRestore(h)
	if not h then return end
	for _, t in ipairs(UI.LookParts(h)) do Kin.Again(t) end
	local line = h.line
	if line then
		for _, t in ipairs(line.shyFlare or {}) do
			Kin.Again(t)
			t:SetTexCoord(0, 1, 1, 0)
		end
		for _, list in pairs(line.shyKinds or {}) do
			for _, t in ipairs(list) do Kin.Again(t) end
		end
	end
	UI.LookFit(h, true)
end

-- What every housing on screen wears, region by region, as text (/shy looks: pasted when something looks wrong).
-- A region shown without the art it should wear (its file or atlas gone: drawn as a block of its tint) is marked "!!".
function UI.LookAudit()
	local out, lost, count = {}, 0, 0
	local function Read(t, method)
		local ok, a, b, c, d = pcall(t[method], t)
		if not ok or issecretvalue(a) then return nil end
		return a, b, c, d
	end
	local function Num(v) return type(v) == "number" and string.format("%.1f", v) or "?" end
	local function Path(p) return (tostring(p):lower():gsub("\\", "/")) end
	for h in pairs(Kin.all) do
		local owner = h.owner
		if Read(owner, "IsVisible") then
			count = count + 1
			local name = Read(owner, "GetName")
			if type(name) ~= "string" then name = tostring(owner) end
			out[#out + 1] = string.format("%s  look %s  options %s/%s%s", name, tostring(h.look), tostring(h.stamp), tostring(Theme.LookStamp()),
				h.options and "  own options" or "")
			local named = {}
			for _, key in ipairs(UI.LOOK_PARTS) do if h[key] then named[h[key]] = key end end
			for key, parts in pairs(h.kinds) do
				for i, t in ipairs(parts) do named[t] = named[t] or (key .. i) end
			end
			for pname, pool in pairs(h.pools) do
				for i, t in ipairs(pool.list) do named[t] = pname .. i end
			end
			for i, t in ipairs(h.rivets) do named[t] = "rivet" .. i end
			-- Its line: the housing's own (a kit's plate on a game frame keeps it there, never on the frame), else
			-- the panel's.
			local line = h.line or owner.shyLine
			for _, t in ipairs(line and { line.shyTrim } or {}) do named[t] = "line extra" end
			for key, list in pairs(line and line.shyKinds or {}) do
				for i, t in ipairs(list) do named[t] = key .. " line " .. i end
			end
			for t, part in pairs(named) do
				if Read(t, "IsShown") then
					local art = Kin.art[t]
					local atlas = Read(t, "GetAtlas")
					local file = Read(t, "GetTextureFilePath")
					if type(file) ~= "string" then file = Read(t, "GetTexture") end
					local want = art and (art.atlas or art[1])
					local gone = art and ((art.atlas and atlas ~= art.atlas)
						or (not art.atlas and not (type(file) == "string" and Path(file):find(Path(art[1]), 1, true))))
					if gone then lost = lost + 1 end
					local r, g, b, a = Read(t, "GetVertexColor")
					out[#out + 1] = string.format("  %s%s: %s%s  scale %s  %sx%s  tint %s %s %s %s", gone and "!! " or "", part,
						tostring(atlas or file), want and gone and ("  (should be " .. tostring(want) .. ")") or "",
						Num(Read(t, "GetScale")), Num(Read(t, "GetWidth")), Num(Read(t, "GetHeight")), Num(r), Num(g), Num(b), Num(a))
				end
			end
		end
	end
	table.insert(out, 1, string.format("Looks: %s worn, %d housings on screen, %d regions without their art", Theme.Look(), count, lost))
	return table.concat(out, "\n"), lost
end

-- A housing standing over its content (a map's border frame over the map) lays the parts over its face (UI.LOOK_FACE)
-- on a frame under that content, and those behind it (UI.LOOK_BEHIND) on a frame under that: those it has now and
-- every one a look makes later.
function Kin.Faced(h)
	local behind = h.behindOn
	if behind then
		for _, key in ipairs(UI.LOOK_BEHIND) do
			local t = h[key]
			if t and t:GetParent() ~= behind then t:SetParent(behind) end
		end
	end
	local under = h.faceOn
	if not under then return end
	for _, key in ipairs(UI.LOOK_FACE) do
		local t = h[key]
		if t and t:GetParent() ~= under then t:SetParent(under) end
	end
	if h.litMask and h.litMask:GetParent() ~= under then h.litMask:SetParent(under) end
	for _, mask in ipairs(h.faceMasks or {}) do
		if mask:GetParent() ~= under then mask:SetParent(under) end
	end
	for _, pool in pairs(h.pools) do
		if pool.face then
			for _, t in ipairs(pool.list) do
				if t:GetParent() ~= under then t:SetParent(under) end
			end
		end
	end
end
function UI.LookFace(h, under, behind)
	if not h then return end
	h.faceOn, h.behindOn = under, behind
	Kin.Faced(h)
end

-- A look kind's regions on a housing, made the first time it is dressed in it.
function Kin.Kindled(h, key, def)
	if h.kinds[key] then return end
	local parts = {}
	h.kinds[key] = parts
	local owner, to, inset = h.owner, h.to, h.inset
	local kit = { owner = owner, to = to, inset = inset }
	function kit.Reg(name, region)
		h[name] = region
		parts[#parts + 1] = region
		if h.make then h.make(name, region, true) end
		Kin.Claim(region)
		return region
	end
	function kit.Out(region, out, drop)
		region:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] - out, -inset[2] + out - (drop or 0))
		region:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] + out, inset[4] - out - (drop or 0))
	end
	h.building = key
	if def.build then def.build(h, kit) end
	h.building = nil
	Kin.Faced(h)
end

-- Every region of a look kind on a housing (`key`), or of every kind but `but`, hidden.
function Kin.Unkindle(h, but)
	for key, parts in pairs(h.kinds) do
		if key ~= but then
			for _, t in ipairs(parts) do t:Hide() end
		end
	end
	for _, pool in pairs(h.pools) do
		if pool.kind ~= but then pool:Done(0) end
	end
end

-- A look's options as controls (a page's theme section): a dropdown for a choice, a switch for on and off, a slider
-- for an amount, in rows of `perRow`, `width` each. It shows the theme's look's (again when that changes), or
-- `opts.look`'s; nothing for a look with none (f.count 0, its height 0). Live unless `get` and `set` are given
-- (a page keeping a plan): get(look, key) -> value, set(look, key, value). `changed(f)` is told when its height
-- changes (another look's options).
--   local f = UI.LookOptions(parent, { width = 190, perRow = 3, changed = Relayout })
--   f:SetLook(look)   -- show another look's (nil: the theme's again); f:Refresh()
function UI.LookOptions(parent, opts)
	opts = opts or {}
	local OPTION_GAP, OPTION_ROW = Kin.OPTION_GAP, Kin.OPTION_ROW
	local width, perRow = opts.width or 190, opts.perRow or 3
	local get = opts.get or Theme.LookOption
	local set = opts.set or Theme.SetLookOption
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(perRow * width + (perRow - 1) * OPTION_GAP, 1)
	f.controls, f.count = {}, 0
	local showing   -- the look whose options are built
	local function Build()
		local look = f.look or Theme.Look()
		if look == showing then return end
		showing = look
		for _, c in ipairs(f.controls) do c:Hide() end
		f.controls = {}
		for i, o in ipairs(Theme.LookOptions(look)) do
			local function Get() return get(look, o.key) end
			local function Set(v) set(look, o.key, v) end
			local c
			if o.kind == "slider" then
				c = UI.Slider(f, o.label, o.min, o.max, o.step or 1, Get, Set, { width = width, desc = o.desc, format = o.format })
			elseif o.kind == "switch" then
				c = CreateFrame("Frame", nil, f)
				c:SetSize(width, OPTION_ROW)
				local label = UI.Text(c, o.label)
				label:SetPoint("TOPLEFT")
				local sw = UI.Switch(c, o.label, Get, Set, { desc = o.desc })
				sw:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
				function c:Refresh() sw:Refresh() end
			else
				local items = {}
				for _, choice in ipairs(o.choices or {}) do
					items[#items + 1] = { value = choice.value, text = choice.text, icon = Kin.ChoiceIcon(choice) }
				end
				c = UI.Dropdown(f, o.label, items, Get, Set, { width = width, desc = o.desc })
			end
			local row, col = floor((i - 1) / perRow), (i - 1) % perRow
			c:SetPoint("TOPLEFT", f, "TOPLEFT", col * (width + OPTION_GAP), -row * OPTION_ROW)
			f.controls[i] = c
		end
		f.count = #f.controls
		local rows = math.ceil(f.count / perRow)
		f:SetHeight(max(1, rows * OPTION_ROW))
		f:SetShown(f.count > 0)
		if opts.changed then opts.changed(f) end
	end
	function f:SetLook(look)
		f.look = look
		Build()
		f:Refresh()
	end
	function f:Refresh()
		Build()
		for _, c in ipairs(f.controls) do
			if c.Refresh then c:Refresh() end
		end
	end
	Shy:On("SHY_THEME", function() if not f.look then f:Refresh() end end)
	Build()
	return f
end

function UI.LookAlpha(look, a)
	local kind = KINDS[look]
	if kind then return kind.alpha and kind.alpha(a) or a end
	if look == "clear" then return a * LOOK.CLEAR.fill end
	if look == "eclipse" then return 1 - (1 - a) ^ 2 end
	if look == "steel" then return max(0, 1 - (1 - a) / (1 - LOOK.SHADE_MID)) end
	if look == "riveted" then return 1 - (1 - a) ^ 2 end
	return a
end

-- Every region a housing's look has made so far: its parts and its rivets. `out`: a list to add them to, else a new one.
function UI.LookParts(h, out)
	out = out or {}
	for _, key in ipairs(UI.LOOK_PARTS) do out[#out + 1] = h[key] end
	for _, t in ipairs(h.rivets) do out[#out + 1] = t end
	for _, parts in pairs(h.kinds) do
		for _, t in ipairs(parts) do out[#out + 1] = t end
	end
	for _, pool in pairs(h.pools) do
		for _, t in ipairs(pool.list) do out[#out + 1] = t end
	end
	return out
end

-- The regions of the other looks, on `owner`, fitted to `to` inside `inset` ({ left, top, right, bottom }).
-- Returns them as h; `make(name, region)` is told of each (a kit records them to restore), the rivets too as
-- LookFit makes them.
--   h.shade, h.halo, h.edge, h.pane, h.sky, h.sheen, h.foot, h.light; h.look is the look dressed
--   h.rivets            the rivets made so far; h.rivetLayer { layer, sublevel } the ones made later go on
function UI.LookBuild(owner, to, inset, make)
	local h = { owner = owner, to = to, inset = inset, make = make, accent = owner.shyAccent, options = owner.shyOptions }
	local function Reg(name, region)
		h[name] = region
		if make then make(name, region) end
		return region
	end
	local function Out(region, out, drop)
		region:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] - out, -inset[2] + out - (drop or 0))
		region:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] + out, inset[4] - out - (drop or 0))
	end
	local shade = Reg("shade", owner:CreateTexture(nil, "BACKGROUND", nil, -8))
	shade:SetTexture(LOOK.SHADE)
	shade:SetTextureSliceMargins(LOOK.SHADE_SLICE, LOOK.SHADE_SLICE, LOOK.SHADE_SLICE, LOOK.SHADE_SLICE)
	Out(shade, LOOK.SHADE_REACH, LOOK.SHADE_DROP)
	local halo = Reg("halo", owner:CreateTexture(nil, "BACKGROUND", nil, -7))
	halo:SetTexture(LOOK.HALO)
	halo:SetTextureSliceMargins(LOOK.HALO_SLICE, LOOK.HALO_SLICE, LOOK.HALO_SLICE, LOOK.HALO_SLICE)
	halo:SetBlendMode("ADD")
	Out(halo, LOOK.HALO_REACH)
	Theme.Tint(halo, UI.LookAccent(h), 1)
	halo:SetAlpha(LOOK.REST)
	-- Frosted: the frost (the hover's uneven layer) over the fill, so what is behind is softened, not seen.
	local frost = Reg("frost", owner:CreateTexture(nil, "BACKGROUND", nil, -5))
	UI.Frost(frost, C.panel)
	frost:SetAlpha(LOOK.CLEAR.frost)
	Out(frost, -LOOK.FILL_IN)
	local sky = Reg("sky", owner:CreateTexture(nil, "BACKGROUND", nil, -5))
	sky:SetColorTexture(1, 1, 1, 1)
	sky:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, LOOK.CLEAR.sky))
	sky:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + 2, -inset[2] - 2)
	sky:SetPoint("TOPRIGHT", to, "TOPRIGHT", -inset[3] - 2, -inset[2] - 2)
	sky:SetHeight(1)
	local sheen = Reg("sheen", owner:CreateTexture(nil, "BACKGROUND", nil, -4))
	sheen:SetTexture(LOOK.SHEEN)
	Theme.Tint(sheen, WHITE, LOOK.CLEAR.sheen)
	sheen:SetSize(1, 1)
	local foot = Reg("foot", owner:CreateTexture(nil, "BACKGROUND", nil, -3))
	foot:SetColorTexture(1, 1, 1, 1)
	foot:SetGradient("VERTICAL", CreateColor(0, 0, 0, LOOK.CLEAR.foot), CreateColor(0, 0, 0, 0))
	foot:SetPoint("BOTTOMLEFT", to, "BOTTOMLEFT", inset[1] + 2, inset[4] + 2)
	foot:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] - 2, inset[4] + 2)
	foot:SetHeight(1)
	local edge = Reg("edge", owner:CreateTexture(nil, "BORDER"))
	edge:SetTexture(LOOK.EDGE)
	edge:SetTextureSliceMargins(LOOK.EDGE_SLICE, LOOK.EDGE_SLICE, LOOK.EDGE_SLICE, LOOK.EDGE_SLICE)
	Out(edge, 0)
	local pane = Reg("pane", owner:CreateTexture(nil, "BORDER"))
	pane:SetTexture(LOOK.PANE)
	pane:SetTextureSliceMargins(LOOK.EDGE_SLICE, LOOK.EDGE_SLICE, LOOK.EDGE_SLICE, LOOK.EDGE_SLICE)
	Out(pane, 0)
	local light = Reg("light", owner:CreateTexture(nil, "ARTWORK", nil, 1))
	light:SetTexture(LOOK.LIGHT)
	light:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + LOOK.LIGHT_IN, -inset[2])
	light:SetPoint("TOPRIGHT", to, "TOPRIGHT", -inset[3] - LOOK.LIGHT_IN, -inset[2])
	light:SetHeight(LOOK.LIGHT_H)
	Theme.Tint(light, UI.LookAccent(h), 1)
	light:SetAlpha(LOOK.REST)
	-- Riveted: the brushing over the fill, the sheen over it, the lit grooves where the sheen falls (masked by
	-- it), the edge, and a row of rivets along each side (made and laid by LookFit).
	local RV = LOOK.RIVETED
	local brushed = Reg("brushed", owner:CreateTexture(nil, "BACKGROUND", nil, -5))
	brushed:SetTexture(LOOK.BRUSHED, "REPEAT", "REPEAT")
	brushed:SetHorizTile(true)
	brushed:SetVertTile(true)
	Out(brushed, -RV.inset)
	local plateSheen = Reg("plateSheen", owner:CreateTexture(nil, "BACKGROUND", nil, -4))
	plateSheen:SetTexture(LOOK.METAL_SHEEN)
	Out(plateSheen, -RV.inset)
	local lit = Reg("brushedLit", owner:CreateTexture(nil, "BACKGROUND", nil, -3))
	lit:SetTexture(LOOK.BRUSHED_LIT, "REPEAT", "REPEAT")
	lit:SetHorizTile(true)
	lit:SetVertTile(true)
	Out(lit, -RV.inset)
	local mask = owner:CreateMaskTexture()
	mask:SetTexture(LOOK.METAL_SHEEN, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	Out(mask, -RV.inset)
	lit:AddMaskTexture(mask)
	h.litMask = mask
	local metalEdge = Reg("metalEdge", owner:CreateTexture(nil, "BORDER"))
	metalEdge:SetTexture(LOOK.METAL_EDGE)
	metalEdge:SetTextureSliceMargins(LOOK.METAL_EDGE_SLICE, LOOK.METAL_EDGE_SLICE, LOOK.METAL_EDGE_SLICE, LOOK.METAL_EDGE_SLICE)
	Out(metalEdge, 0)
	h.rivets, h.rivetLayer = {}, { "BORDER", 2 }
	-- The content's well (a look's zones; laid by LookFit under the head and over the foot).
	Reg("wellFill", owner:CreateTexture(nil, "BACKGROUND", nil, -2)):SetColorTexture(1, 1, 1, 1)
	Reg("well", owner:CreateTexture(nil, "BORDER", nil, 1))
	-- Round a placed content the rim is the plate as a header is (laid by LookFit): the strip's band of darker
	-- steel at a header strip's strength (the look's, UI.LookAlpha), over the fill, in four pieces round the well.
	h.rims = {}
	for i, name in ipairs({ "rimTop", "rimBottom", "rimLeft", "rimRight" }) do
		local t = Reg(name, owner:CreateTexture(nil, "BACKGROUND", nil, -2))   -- where a header's strip stands
		t:SetColorTexture(1, 1, 1, 1)
		h.rims[i] = t
	end
	-- A second well along the foot band (a look's zones.footWell): laid by LookFit under the band.
	Reg("footFill", owner:CreateTexture(nil, "BACKGROUND", nil, -2)):SetColorTexture(1, 1, 1, 1)
	Reg("footWell", owner:CreateTexture(nil, "BORDER", nil, 1))
	h.zoneHead, h.zoneFoot = 0, 0
	-- The art each wears, set again whenever the housing is dressed (UI.LookWear).
	for region, art in pairs({
		[shade] = { LOOK.SHADE, nil, nil, LOOK.SHADE_SLICE }, [halo] = { LOOK.HALO, nil, nil, LOOK.HALO_SLICE },
		[frost] = { UI.FROST, "REPEAT", "REPEAT", nil, true }, [sheen] = { LOOK.SHEEN }, [light] = { LOOK.LIGHT },
		[edge] = { LOOK.EDGE, nil, nil, LOOK.EDGE_SLICE }, [pane] = { LOOK.PANE, nil, nil, LOOK.EDGE_SLICE },
		[brushed] = { LOOK.BRUSHED, "REPEAT", "REPEAT", nil, true }, [plateSheen] = { LOOK.METAL_SHEEN },
		[lit] = { LOOK.BRUSHED_LIT, "REPEAT", "REPEAT", nil, true }, [metalEdge] = { LOOK.METAL_EDGE, nil, nil, LOOK.METAL_EDGE_SLICE },
	}) do Kin.art[region] = art end
	-- The look kinds made on it (key -> their regions) and its pools (UI.LookKind, UI.LookPool).
	h.kinds, h.pools = {}, {}
	Kin.all[h] = true
	-- The parts that go by the piece's size follow it (a plate fitted to a texture, which has no size script,
	-- is fitted again whenever it is dressed).
	if to.HasScript and to:HasScript("OnSizeChanged") then to:HookScript("OnSizeChanged", function() UI.LookFit(h) end) end
	return h
end

-- The least a piece may be, each way, for a nine slice of the looks' with margins `slice` (a texel a unit) laid
-- `reach` past it to draw true: its file is the two margins and the sliver (LookArt.SLIVER), and the game
-- squeezes the margins of a region smaller than its file. Every border a look draws keeps its width down to it.
function UI.LookLeast(slice, reach)
	return 2 * slice + LOOK.SLIVER - 2 * (reach or 0)
end

-- The parts of a housing that go by its size: the clear look's band of light (in from the left end; none when
-- the pane is too narrow for it), the sky in its top and the dark at its foot. The shade needs room for its
-- corners: on a piece smaller than that (a drawer's strip of a pull) the game squeezes them, and the soft shadow
-- turns into a hard dark slab standing out round the piece, so such a piece casts none. (A piece folded to its
-- header, UI.FOLDED, has the room.)
local SHADE_ROOM = UI.LookLeast(LOOK.SHADE_SLICE, LOOK.SHADE_REACH)
-- The rivets go on whole pixels: each is the cell drawn for its size on screen (LOOK.RIVET), a texel to a pixel,
-- its middle a whole number of pixels in from the edges it is laid from, so every rivet of every housing comes
-- out alike wherever the housing's edges fall. Laid again when the UI's scale or a HUD piece's changes.
local studded = setmetatable({}, { __mode = "k" })   -- housing -> true while it wears rivets
local function Rivet(h, i)
	local t = h.rivets[i]
	if not t then
		t = h.owner:CreateTexture(nil, h.rivetLayer[1], nil, h.rivetLayer[2])
		h.rivets[i] = t
		if h.make then h.make("rivet" .. i, t) end
		Kin.art[t] = { LOOK.RIVET }
	end
	return t
end
-- Fitted only when what it goes by changed: the piece's size, the pixels a unit, its head and its foot, or its
-- fill put away or brought back. A housing's size script runs at every step of a glide, a title's words are set
-- again and again, and a new scale anywhere asks every housing: each costs a few readings unless something of
-- its own moved. `again`: fitted whatever it read (it was dressed, or what stands in it changed: its content, its
-- foot's words, its title).
Kin.FIT_HIDES = { "shade", "sheen", "wellFill", "well", "footFill", "footWell" }
Kin.fitClock, Kin.dressClock = Shy.Clock("look: a housing fitted", "ShyCore"), Shy.Clock("look: a housing dressed", "ShyCore")
function UI.LookFit(h, again)
	local to, inset = h.to, h.inset
	local w, tall = to:GetWidth(), to:GetHeight()
	if not (w and tall) then return end
	w, tall = w - inset[1] - inset[3], tall - inset[2] - inset[4]
	if tall <= 0 then return end
	local scale = h.owner:GetEffectiveScale()
	local per = scale and not issecretvalue(scale) and scale > 0 and scale / PixelUtil.GetPixelToUIUnitFactor() or nil   -- pixels a unit
	local away = h.fill ~= nil and not h.fill:IsShown()
	local head, foot = h.zoneHead or 0, h.zoneFoot or 0
	local was = h.fitted
	if not was then
		was = {}
		h.fitted = was
	elseif not again and was[1] == w and was[2] == tall and was[3] == per and was[4] == head and was[5] == foot and was[6] == away then
		return
	end
	was[1], was[2], was[3], was[4], was[5], was[6] = w, tall, per, head, foot, away
	local began = debugprofilestop()
	-- A housing its owner has put away (its fill hidden: chat's panel for a width no longer used) is fitted but
	-- shows nothing: what goes by its size is only shown again when it is dressed again.
	if away then
		for _, key in ipairs(Kin.FIT_HIDES) do h[key]:Hide() end
		for _, t in ipairs(h.rivets) do t:Hide() end
		for _, t in ipairs(h.rims) do t:Hide() end
		Kin.Unkindle(h)
		return
	end
	h.shade:SetShown(h.shaded == true and w >= SHADE_ROOM and tall >= SHADE_ROOM)
	local at, wide = 2 + w * LOOK.CLEAR.at, tall * 1.1
	h.sheen:ClearAllPoints()
	h.sheen:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + at, -inset[2] - 2)
	h.sheen:SetSize(wide, max(1, tall - 4))
	h.sheen:SetShown(h.look == "clear" and not h.solid and at + wide <= w - 2)
	h.sky:SetHeight(max(1, tall * LOOK.CLEAR.down))
	h.foot:SetHeight(max(1, min(LOOK.CLEAR.footH, tall * 0.3)))
	-- The content's well, when the look sinks it: under a head, flush under it, IN in from the sides and from the
	-- foot (just over a foot band when there is one); round a content its owner placed (UI.LookContent), GAP
	-- round it, its edges whole pixels in from the plate's (`rim`, { left, top, right, bottom }).
	local zone = UI.LOOK_ZONES[h.look]
	local well = zone and zone.well
	local keep = h.content
	local rim, l, t, r, b
	if well and keep and per then
		rim = {}
		for i = 1, 4 do rim[i] = max(0, floor((keep[i] - well.GAP) * per + 0.5)) end
		l, t, r, b = rim[1] / per, rim[2] / per, rim[3] / per, rim[4] / per
	elseif well and head > 0 then
		l, t, r, b = well.IN, head, well.IN, foot > 0 and foot + 1 or well.IN
	end
	local sunk = l ~= nil and w - l - r > 2 * well.slice and tall - t - b > 2 * well.slice
	if sunk then
		for _, region in ipairs({ h.wellFill, h.well }) do
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + l, -inset[2] - t)
			region:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] - r, inset[4] + b)
		end
	else
		rim = nil
	end
	h.wellFill:SetShown(sunk)
	h.well:SetShown(sunk)
	-- The foot band's own well (zones.footWell): under the band, IN in from the sides and the foot, a seam's two units
	-- clear of the content's well over it.
	local footWell = zone and zone.footWell
	local floored = footWell ~= nil and foot > 0 and w > 2 * (footWell.IN + footWell.slice) and foot - 1 - footWell.IN > 2 * footWell.slice
	if floored then
		for _, region in ipairs({ h.footFill, h.footWell }) do
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", to, "BOTTOMLEFT", inset[1] + footWell.IN, inset[4] + foot - 1)
			region:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] - footWell.IN, inset[4] + footWell.IN)
		end
	end
	h.footFill:SetShown(floored)
	h.footWell:SetShown(floored)
	-- Round a placed content the rim is the plate as a header is: the strip's band of darker steel (h.rims) over
	-- the fill, which stays whole, as a header's strip lies over its piece's fill. A look kind may wear none.
	local kind = KINDS[h.look]
	local rimPx = rim
	if kind and kind.rims == false then rim = nil end
	if rim then
		local n = LOOK.RIVETED.inset
		local x0, y0, x1, y1 = inset[1] + n, inset[2] + n, inset[3] + n, inset[4] + n   -- the plate, in under the edge
		local top, bottom, left, right = h.rims[1], h.rims[2], h.rims[3], h.rims[4]
		for _, region in ipairs(h.rims) do region:ClearAllPoints() end
		top:SetPoint("TOPLEFT", to, "TOPLEFT", x0, -y0)
		top:SetPoint("BOTTOMRIGHT", to, "TOPRIGHT", -x1, -inset[2] - t)
		bottom:SetPoint("TOPLEFT", to, "BOTTOMLEFT", x0, inset[4] + b)
		bottom:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -x1, y1)
		left:SetPoint("TOPLEFT", to, "TOPLEFT", x0, -inset[2] - t)
		left:SetPoint("BOTTOMRIGHT", to, "BOTTOMLEFT", inset[1] + l, inset[4] + b)
		right:SetPoint("TOPLEFT", to, "TOPRIGHT", -inset[3] - r, -inset[2] - t)
		right:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -x1, inset[4] + b)
	end
	for _, region in ipairs(h.rims) do region:SetShown(rim ~= nil) end
	-- The rivets: a row along each side, a rivet at each corner and the rest spread evenly about PERIOD apart;
	-- the sides' rows hold the rivets between the corners'. Each row's middle SEW in from its edge, or round a
	-- content placed in a well, half way across the rim between the edge's bevel and the well. None on a piece
	-- too small for them, and a well under a head keeps them to the head, and to a foot tall enough for a row.
	local RV, RC = LOOK.RIVETED, LOOK.RIVET_CELLS
	local used = 0
	if per and h.look == "riveted" and w >= RV.least and tall >= RV.least then
		local s = min(RC.most, max(RC.least, floor(RV.row * per + 0.5)))
		local mid, size = floor(s / 2), s / per                  -- the rivet's middle in its cell, in texels
		local u = (s - RC.least) * (s + RC.least + 1) / 2         -- the cell's left in the file
		local x0, y0, x1, y1 = inset[1], inset[2], inset[3], inset[4]
		-- Where a row's middles stand in from each edge { left, top, right, bottom }, in half pixels.
		local band, sew = {}, floor(2 * RV.sew * per + 0.5)
		for i = 1, 4 do band[i] = rim and floor(RV.edge * per + rim[i] + 0.5) or sew end
		-- One rivet, its middle `a` half pixels in from the left or right edge and `b` from the top or foot: on
		-- a pixel's middle or between two, each way (the cell drawn for it: the file's rows).
		local function Lay(top, left, a, b)
			used = used + 1
			local rivet = Rivet(h, used)
			local x = left and floor(a / 2) - mid or floor((a + 1) / 2) - s + mid
			local y = top and floor(b / 2) - mid or floor((b + 1) / 2) - s + mid
			local v = (a % 2 == 0 and 1 or 0) + (b % 2 == 0 and 2 or 0)
			rivet:ClearAllPoints()
			rivet:SetPoint((top and "TOP" or "BOTTOM") .. (left and "LEFT" or "RIGHT"), to, (top and "TOP" or "BOTTOM") .. (left and "LEFT" or "RIGHT"),
				left and x0 + x / per or -x1 - x / per, top and -y0 - y / per or y1 + y / per)
			rivet:SetSize(size, size)
			local v0 = v * (RC.most + 1)
			Kin.Again(rivet)   -- its art as it should be, whatever was done to it
			rivet:SetTexCoord(u / RC.w, (u + s) / RC.w, v0 / RC.h, (v0 + s) / RC.h)
			rivet:Show()
		end
		-- Along a side `long` pixels: the first middle `from` half pixels in from its start, the last `to` in from
		-- its end, the rest spread evenly between, each counted from the end it is nearer.
		local step = 2 * RV.period * per
		local function Along(long, from, upto, each)
			local span = 2 * long - from - upto
			local n = max(1, floor(span / step + 0.5))
			for i = 0, n do
				local near = i * 2 <= n
				each(i, n, near, (near and from or upto) + floor((near and i or n - i) * span / n + 0.5))
			end
		end
		local around = not sunk or rim ~= nil
		local low = around or foot >= 2 * RV.sew + 1
		Along(w * per, band[1], band[3], function(_, _, near, p)
			Lay(true, near, p, band[2])
			if low then Lay(false, near, p, band[4]) end
		end)
		if around then
			Along(tall * per, band[2], band[4], function(i, n, near, p)
				if i > 0 and i < n then
					Lay(near, true, band[1], p)
					Lay(near, false, band[3], p)
				end
			end)
		end
	end
	for i = used + 1, #h.rivets do h.rivets[i]:Hide() end
	studded[h] = used > 0 or nil
	-- A look kind lays what goes by size itself (and again when the scale changes: it may lay on whole pixels).
	if kind and kind.fit then
		local g = h.fitting or {}
		h.fitting = g
		g.w, g.tall, g.per, g.head, g.foot, g.inset, g.to = w, tall, per, head, foot, inset, to
		g.sunk, g.rim, g.content, g.footInfo, g.title, g.titleOwn = sunk, rimPx, keep, h.footInfo, h.titleText, h.titleOwn
		-- Whether its content stands clear of the look's work inside the edge (a window's body: UI.Body). A look
		-- lays that work (an inset band) only where it is: on any other piece it would lie under what the piece holds.
		g.cleared = h.owner.shyBody ~= nil
		if sunk then
			local gw = h.fittingWell or {}
			h.fittingWell = gw
			gw[1], gw[2], gw[3], gw[4] = l, t, r, b
			g.well = gw
		else
			g.well = nil
		end
		kind.fit(h, g)
		studded[h] = true
	end
	Kin.fitClock:Lap(debugprofilestop() - began)
end

-- A housing's zones (UI.LOOK_ZONES): how tall its head is (top edge down to its line's foot) and its foot (a band
-- along the bottom: chat's typing row while it is open). nil keeps what it was. Fitted again at once.
function UI.LookZones(h, head, foot)
	if not h then return end
	if head then h.zoneHead = head end
	if foot then h.zoneFoot = foot end
	UI.LookFit(h)
end

-- What stands in a housing's foot band, for a look that wears it its own way (a typing row's voice: { color =
-- { r, g, b }, voice = "say" | "yell" | "whisper" | "emote" | "channel", idle = true while the box isn't focused,
-- field = { left, right, mid } where its words stand: units in from the left and right edges of the housing's rect (its
-- `to`, before any inset) to where they start and end, and down from the band's top to their middle, or nil }), or nil. A look kind reads it as g.footInfo;
-- one with `ownsFoot` draws the band itself, framed round the field (UI.LookOwnsFoot: its owner puts its own seam and
-- light away and keeps its words where they are).
function UI.LookFoot(h, info)
	if not h then return end
	-- (Told at every change of the box, a new list each time: fitted again only for one that says something else.)
	local was = h.footInfo
	if was == info then return end
	if was and info and was.voice == info.voice and was.idle == info.idle then
		local a, b, f, g = was.color, info.color, was.field, info.field
		local same = a == b or (a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3])
		if same and (f == g or (f and g and f.left == g.left and f.right == g.right and f.mid == g.mid)) then
			h.footInfo = info
			return
		end
	end
	h.footInfo = info
	UI.LookFit(h, true)
end

function UI.LookOwnsFoot(h)
	local kind = h and KINDS[h.look]
	return kind ~= nil and kind.ownsFoot == true
end

-- The words a housing's head is titled with (a font string), for a look that sets its title off on a ground of its own
-- (a caption box sized to the words): fitted again whenever the words change. `own`: the words are ours (UI.TitleText),
-- so the look may ink them for its ground; a game window's title is inked by its kit (UI.TitleInk) instead. A head
-- naming none (tabs, toggles, counts) has nothing set off: what stands there keeps the head's plain ground.
UI.LOOK_TITLED = setmetatable({}, { __mode = "k" })   -- font string -> the housing it titles
function UI.LookTitle(h, fs, own)
	if not h then return end
	h.titleText, h.titleOwn = fs, fs ~= nil and own == true
	if fs then
		if not UI.LOOK_TITLED[fs] then
			-- (Words set again as they were, as a piece refreshing itself does, change nothing: only for a look
			-- that sets its title off, and only words that read, show or measure otherwise, are a reason to fit.)
			local function Again()
				local by = UI.LOOK_TITLED[fs]
				if not (by and by.titleText == fs) then return end
				local kind = KINDS[by.look]
				if not (kind and kind.title) then return end
				local said, shown, wide = fs:GetText(), fs:IsShown(), fs:GetUnboundedStringWidth()
				local known = not issecretvalue(said) and not issecretvalue(shown) and not issecretvalue(wide)
				if known and said == by.titleSaid and shown == by.titleShown and wide == by.titleWide then return end
				by.titleSaid, by.titleShown, by.titleWide = nil, nil, nil
				if known then by.titleSaid, by.titleShown, by.titleWide = said, shown, wide end
				UI.LookFit(by, true)
			end
			hooksecurefunc(fs, "SetText", Again)
			hooksecurefunc(fs, "SetFormattedText", Again)
		end
		UI.LOOK_TITLED[fs] = h
	end
	h.titleSaid = nil
	UI.LookFit(h, true)
end

-- The ink of a head's title words in the look worn, resolved now: a look that sets its title off says what reads on
-- that ground (its `titleInk`), else `base` (a palette table or a color function). For words the core doesn't letter
-- (a game window's title through kit:Head, repainted on SHY_THEME as kit paint is).
function UI.TitleInk(base)
	local kind = KINDS[Theme.Look()]
	if kind and kind.titleInk then return kind.titleInk() end
	local r, g, b = Color(base)
	return r, g, b
end

-- Where a housing's content stands (the console's buttons): in from its edges, { left, top, right, bottom } in
-- units, or nil for none said. A look with a well sinks it there and rivets the rim round it (LookFit). Fitted
-- again when it moves.
function UI.LookContent(h, keep)
	if not h then return end
	local was = h.content
	if keep and was and keep[1] == was[1] and keep[2] == was[2] and keep[3] == was[3] and keep[4] == was[4] then return end
	if not keep and not was then return end
	h.content = keep and { keep[1], keep[2], keep[3], keep[4] } or nil
	UI.LookFit(h, true)
end

-- A header's accent line by look, its height the same in every one: Forged and Glass as it is; Frosted
-- etched, lighter; on the slab lit full, with a flare of your color rising from its middle into the strip
-- (the very light a window's open tab is lit with: the same wash, laid over the slab, brightest at the
-- line and gone before the strip's top), the line itself crisp under it. `strip`: the flare fills it; with
-- none it stands FLARE_H tall. (An inner piece's line is its housing's: Shy.Skin dresses it through this too.)
local FLARE_H, FLARE_ALPHA = 18, 1
local flares = setmetatable({}, { __mode = "k" })   -- flare texture -> { from, to } (its alpha at each end)
local function Flare(t, ends)
	local r, g, b = Color(t.shyAccent or Theme.Accent)
	t:SetGradient("HORIZONTAL", CreateColor(r, g, b, ends[1] * FLARE_ALPHA), CreateColor(r, g, b, ends[2] * FLARE_ALPHA))
end
Shy:On("SHY_THEME", function()
	for t, ends in pairs(flares) do Flare(t, ends) end
end)
-- What a look lays over a line (the riveted trim, the eclipse's flare, a look kind's own) and its marks are shown with
-- the line: one hidden by its owner (a docked card's, the line of a panel put away, a kit's restored) takes them with it.
local function Over(line)
	if line.shyTrim then line.shyTrim:SetShown(line.shyTrimmed == true and line:IsShown()) end
	if line.shyMarks then line.shyMarks:SetShown(line:IsShown()) end
	if line.shyFlare then
		for _, t in ipairs(line.shyFlare) do t:SetShown(line.shyFlared == true and line:IsShown()) end
	end
	if line.shyKinds then
		for key, regions in pairs(line.shyKinds) do
			local on = key == line.shyKindOn and line:IsShown()
			for _, t in ipairs(regions) do t:SetShown(on) end
		end
	end
end
local function Follow(line)
	if line.shyFollowed then return end
	line.shyFollowed = true
	local function Again() Over(line) end
	hooksecurefunc(line, "Show", Again)
	hooksecurefunc(line, "Hide", Again)
	hooksecurefunc(line, "SetShown", Again)
end

-- A header's line in whole screen pixels: UI.LINE rounded up. Two units are rarely a whole number of pixels,
-- and the game rounds a line's edges to the pixel grid wherever it falls, so the same line came out two pixels
-- in one header and three in the next. Fitted again when the UI's scale or a HUD piece's changes.
-- UI.LineHeight(region): that height in units where `region` stands (a region of the game's, placed by a kit, takes it
-- once); UI.LineFit(line) gives it to a line of our own and keeps it so.
local fitted = setmetatable({}, { __mode = "k" })
function UI.LineHeight(region)
	local scale = region:GetEffectiveScale()
	if issecretvalue(scale) or not scale or scale <= 0 then return UI.LINE end
	local unit = PixelUtil.GetPixelToUIUnitFactor()
	return max(1, math.ceil(UI.LINE * scale / unit - 0.05)) * unit / scale
end
-- UI.LineFit(line, false): let go of it (an owner that sets a line's thickness itself: a list's section rule).
function UI.LineFit(line, fit)
	if fit == false then
		fitted[line] = nil
		return
	end
	fitted[line] = true
	line:SetHeight(UI.LineHeight(line))
end
-- A glyph in whole screen pixels: `units` square, rounded to the nearest pixel where it stands (never under
-- one), and drawn on the pixel grid, so a glyph's edges fall on pixels and two of a size are drawn alike
-- wherever they stand. Fitted again when the UI's scale or a HUD piece's changes.
--   UI.GlyphFit(texture, units)
local glyphs = setmetatable({}, { __mode = "k" })
function UI.GlyphFit(texture, units)
	glyphs[texture] = units
	local side = units
	local scale = texture:GetEffectiveScale()
	if not issecretvalue(scale) and scale and scale > 0 then
		local unit = PixelUtil.GetPixelToUIUnitFactor()
		side = max(1, floor(units * scale / unit + 0.5)) * unit / scale
	end
	texture:SetSize(side, side)
	texture:SetSnapToPixelGrid(true)
	texture:SetTexelSnappingBias(0)
end
-- A small box in whole screen pixels (a talent's rank pip): w by h units, each rounded to the nearest pixel where it
-- stands (never under one), drawn on the pixel grid. A box's units are rarely whole pixels: a 5 by 3 pip at 1.22
-- pixels a unit came out 6 or 7 wide and soft at its edges. UI.BoxPixels(region, units) is that rounding alone, for
-- the gap between boxes laid in a row. Fitted again when the UI's scale or a HUD piece's changes.
--   UI.BoxFit(texture, w, h)
local boxes = setmetatable({}, { __mode = "k" })
function UI.BoxPixels(region, units)
	local scale = region:GetEffectiveScale()
	if issecretvalue(scale) or not scale or scale <= 0 then return units end
	local unit = PixelUtil.GetPixelToUIUnitFactor()
	return max(1, floor(units * scale / unit + 0.5)) * unit / scale
end
function UI.BoxFit(texture, w, h)
	local box = boxes[texture] or {}
	box[1], box[2] = w, h
	boxes[texture] = box
	texture:SetSize(UI.BoxPixels(texture, w), UI.BoxPixels(texture, h))
	texture:SetSnapToPixelGrid(true)
	texture:SetTexelSnappingBias(0)
end

-- A badge: a count on a faint wash of its meaning color, a glyph before it when one says what is counted (a
-- group head's skill-ups and ready ones, a batch's points so far). Sized to what it says.
--   local b = UI.Badge(parent)    b:Set({ text, color, glyph, turn })    b.fill, b.glyph, b.text
function UI.Badge(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetHeight(16)
	b.fill = b:CreateTexture(nil, "ARTWORK")
	b.fill:SetAllPoints()
	b.fill:SetColorTexture(1, 1, 1, 1)
	b.glyph = b:CreateTexture(nil, "OVERLAY")
	UI.GlyphFit(b.glyph, 8)
	b.glyph:SetPoint("LEFT", 6, 0)
	b.text = UI.Words(b, UI.NameFont(10))
	function b:Set(item)
		self.glyph:SetShown(item.glyph ~= nil)
		if item.glyph then
			self.glyph:SetTexture(item.glyph)
			self.glyph:SetRotation(item.turn or 0)
			UI.Tint(self.glyph, item.color)
		end
		self.text:SetText(item.text or "")
		UI.Ink(self.text, item.color)
		self.text:ClearAllPoints()
		self.text:SetPoint("LEFT", item.glyph and 17 or 6, 0)
		UI.Paint(self.fill, item.color, 0.14)
		self:SetWidth(math.ceil(self.text:GetStringWidth()) + (item.glyph and 23 or 12))
	end
	return b
end

-- A group's head: where a group of rows begins in a list (a zone's quests on the quest card, a profession's
-- categories). A band under a hairline, the name over a dim line of what is in it, the fold on the rail, a glow
-- under the mouse. Open, its rows hang under it on a faint wash, with a rail of the hover color from the fold down
-- to the last of them and, when asked, a short branch into each. Rails and branches stand on whole screen pixels,
-- the rail ending where the last branch does, and are fitted again when the UI's scale changes.
--   local h = UI.GroupHead(parent, opts)
--     height (32), rail (23: the rail's middle from the left), gutter (46: where the words begin), right (8),
--     title (12), sub (10), fold (a region of yours, or function(h) making it, on the rail instead of the family's
--     UI.FoldMark; h:SetOpen calls its :Set("open"|"shut") and the hover its :SetHovered(on) when it has them),
--     foldSize (22, the quest card's), branches (where a branch ends, from the left: a branch into each row),
--     line (one line: the name on the band's middle, what is in it as badges at the right), click(h, mouse),
--     tip(h) -> title, text, opts
--   h:Set(name, sub)       h:SetOpen(open)       h:SetAccent(color | nil): a wash of a meaning color from the left
--   h:SetBadges({ { text, color, glyph, turn } ... })   counts at the right, the first rightmost
--   h:Hang(depth, nodes)   its rows: `depth` units under the head (the wash), `nodes` each row's middle down from
--                          the head's top (the rail runs to the last); h:Hang() takes them away
--   h.text, h.sub, h.fold, h.band, h.glow
do
	local heads = setmetatable({}, { __mode = "k" })
	local function Color(c)
		if c.GetRGB then return c:GetRGB() end
		return c[1] or c.r, c[2] or c.g, c[3] or c.b
	end
	local function Snapped(t)
		t:SetSnapToPixelGrid(true)
		t:SetTexelSnappingBias(0)
		return t
	end
	local function Lay(h)
		local o, nodes = h.opts, h.nodes
		local thick = UI.BoxPixels(h, 2)
		local railX = o.rail - thick / 2
		local from = o.height / 2 + o.foldSize / 2
		local last = nodes and nodes[#nodes]
		h.wash:SetShown(h.depth ~= nil and h.depth > 0)
		if h.depth and h.depth > 0 then h.wash:SetHeight(h.depth) end
		-- The rail closes on the last branch's foot, so the two meet in a corner and neither runs past the other.
		local foot = last and (last + (o.branches and thick / 2 or 0))
		local long = foot and foot - from or 0
		h.rail:SetShown(long > 0)
		if long > 0 then
			h.rail:ClearAllPoints()
			h.rail:SetPoint("TOPLEFT", h, "TOPLEFT", railX, -from)
			h.rail:SetSize(thick, long)
		end
		local n = (o.branches and nodes) and #nodes or 0
		for i = 1, n do
			local b = h.twigs[i]
			if not b then
				b = Snapped(h:CreateTexture(nil, "BACKGROUND", nil, 1))
				UI.Paint(b, C.hot, 0.3)
				h.twigs[i] = b
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", h, "TOPLEFT", railX + thick, -(nodes[i] - thick / 2))
			b:SetSize(max(1, o.branches - railX - thick), thick)
			b:Show()
		end
		for i = n + 1, #h.twigs do h.twigs[i]:Hide() end
		if h.edge:IsShown() then h.edge:SetWidth(thick) end
	end
	local function Hover(h, on)
		h.glow:SetShown(on)
		UI.Ink(h.text, on and C.hot or C.text)
		if h.fold.SetHovered then h.fold:SetHovered(on) end
		if on and h.opts.tip then
			local title, text, opts = h.opts.tip(h)
			if title then UI.Tip(h, title, text, opts or { side = "LEFT" }) end
		elseif not on then
			UI.TipHide(h)
		end
	end
	function UI.GroupHead(parent, opts)
		opts = opts or {}
		local o = { height = opts.height or 32, rail = opts.rail or 23, gutter = opts.gutter or 46, right = opts.right or 8,
			foldSize = opts.foldSize or 22, branches = opts.branches, tip = opts.tip, click = opts.click, line = opts.line }
		local h = CreateFrame("Frame", nil, parent)
		h.opts, h.twigs = o, {}
		h:SetHeight(o.height)
		h.band = h:CreateTexture(nil, "BACKGROUND")
		h.band:SetAllPoints()
		UI.Paint(h.band, C.row, 0.9)
		h.accent = h:CreateTexture(nil, "BACKGROUND", nil, 1)
		h.accent:SetAllPoints()
		h.accent:SetColorTexture(1, 1, 1, 1)
		h.accent:Hide()
		h.edge = Snapped(h:CreateTexture(nil, "BACKGROUND", nil, 3))
		h.edge:SetPoint("TOPLEFT")
		h.edge:SetPoint("BOTTOMLEFT")
		h.edge:SetColorTexture(1, 1, 1, 1)
		h.edge:Hide()
		h.rule = Snapped(h:CreateTexture(nil, "BACKGROUND", nil, 4))
		h.rule:SetHeight(1)
		h.rule:SetPoint("TOPLEFT")
		h.rule:SetPoint("TOPRIGHT")
		UI.Paint(h.rule, C.border, 0.9)
		h.glow = h:CreateTexture(nil, "BACKGROUND", nil, 2)
		h.glow:SetAllPoints()
		UI.Paint(h.glow, C.hot, 0.09)
		h.glow:Hide()
		-- The group under it: the wash from the head's foot down, the rail and branches on the head (so they move with it).
		h.wash = h:CreateTexture(nil, "BACKGROUND", nil, -1)
		h.wash:SetPoint("TOPLEFT", h, "BOTTOMLEFT")
		h.wash:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT")
		UI.Paint(h.wash, C.hot, 0.045)
		h.wash:Hide()
		h.rail = Snapped(h:CreateTexture(nil, "BACKGROUND", nil, 1))
		UI.Paint(h.rail, C.hot, 0.55)
		h.rail:Hide()
		-- The fold: the family's fold mark (UI.FoldMark, the quest card's), or yours.
		local fold = opts.fold
		if type(fold) == "function" then fold = fold(h) end
		h.fold = fold or UI.FoldMark(h, o.foldSize)
		h.fold:ClearAllPoints()
		h.fold:SetPoint("CENTER", h, "TOPLEFT", o.rail, -o.height / 2)
		-- The words: the name over what is in it; or, on one line, the name on the band's middle and what is in it as
		-- badges at the right (h:SetBadges).
		h.badges = {}
		h.text = UI.Text(h, "", opts.title or 12, true)
		h.text:SetJustifyH("LEFT")
		h.text:SetWordWrap(false)
		if o.line then
			h.text:SetPoint("LEFT", h, "LEFT", o.gutter, 0)
		else
			h.text:SetPoint("TOPLEFT", o.gutter, -4)
		end
		h.text:SetPoint("RIGHT", h, "RIGHT", -o.right, 0)
		h.sub = UI.Text(h, "", opts.sub or 10, false, C.dim)
		h.sub:SetPoint("TOPLEFT", o.gutter, -(o.height - 13))
		h.sub:SetPoint("RIGHT", h, "RIGHT", -o.right, 0)
		h.sub:SetJustifyH("LEFT")
		h.sub:SetWordWrap(false)
		h:EnableMouse(true)
		h:SetScript("OnEnter", function(self) Hover(self, true) end)
		h:SetScript("OnLeave", function(self) Hover(self, false) end)
		h:SetScript("OnMouseUp", function(self, mouse)
			if self.opts.click then self.opts.click(self, mouse) end
		end)

		function h:Set(name, sub)
			self.text:SetText(name or "")
			self.sub:SetText(sub or "")
			self.sub:SetShown(sub ~= nil and sub ~= "")
		end
		function h:SetOpen(open)
			self.open = open == true
			if self.fold.Set then self.fold:Set(self.open and "open" or "shut") end
		end
		-- Badges at the right, the first rightmost: { text, color, glyph } each (a count in a meaning color, a glyph
		-- before it); the name gives way to them.
		function h:SetBadges(list)
			local x = self.opts.right
			for i, item in ipairs(list or {}) do
				local b = self.badges[i]
				if not b then
					b = UI.Badge(self)
					self.badges[i] = b
				end
				b:Set(item)
				b:ClearAllPoints()
				b:SetPoint("RIGHT", self, "RIGHT", -x, 0)
				b:Show()
				x = x + b:GetWidth() + 4
			end
			for i = #(list or {}) + 1, #self.badges do self.badges[i]:Hide() end
			self.text:SetPoint("RIGHT", self, "RIGHT", -(x + 2), 0)
		end
		function h:SetAccent(color)
			if self.accentColor == color then return end
			self.accentColor = color
			self.accent:SetShown(color ~= nil)
			self.edge:SetShown(color ~= nil)
			if not color then return end
			local r, g, b = Color(color)
			self.accent:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.14), CreateColor(r, g, b, 0))
			self.edge:SetVertexColor(r, g, b, 0.8)
			self.edge:SetWidth(UI.BoxPixels(self, 2))
		end
		function h:Hang(depth, nodes)
			-- (Laid only when it changes: a list lays its groups out often.)
			local same = depth == self.depth and (nodes == nil) == (self.nodes == nil)
			if same and nodes then
				same = #nodes == #self.nodes
				for i = 1, #nodes do same = same and nodes[i] == self.nodes[i] end
			end
			if same then return end
			self.depth, self.nodes = depth, nodes
			Lay(self)
		end
		h:SetOpen(false)
		heads[h] = true
		return h
	end
	function UI.GroupRefit()
		for h in pairs(heads) do Lay(h) end
	end
end

-- A row of choices, one picked (the pick is the primary): a list's filter, the kinds of a search.
--   local s = UI.Segments(parent, labels, onSelect(i), opts)
--     opts.width: the row spread evenly over it (else each as wide as its words), opts.height (24)
--   s:Select(i)   s:SetLabel(i, text)   s:SetCount(i, n | nil): a dim number after the words   s.buttons
do
	local GAP = 4
	local function Fit(s)
		local o = s.opts
		local at = 0
		local each = o.width and (o.width - GAP * (#s.buttons - 1)) / #s.buttons
		for _, b in ipairs(s.buttons) do
			local words = b.text:GetStringWidth() + (b.count:IsShown() and b.count:GetStringWidth() + 4 or 0)
			b:SetWidth(each or (words + 22))
			b.text:ClearAllPoints()
			b.text:SetPoint("CENTER", b, "CENTER", -(b.count:IsShown() and (b.count:GetStringWidth() + 4) / 2 or 0), 0)
			b:ClearAllPoints()
			b:SetPoint("LEFT", s, "LEFT", at, 0)
			at = at + b:GetWidth() + GAP
		end
		s:SetWidth(max(1, at - GAP))
	end
	function UI.Segments(parent, labels, onSelect, opts)
		local s = CreateFrame("Frame", nil, parent)
		s.opts = opts or {}
		s:SetHeight(s.opts.height or 24)
		s.buttons = {}
		for i, label in ipairs(labels) do
			local b = UI.Button(s, label, 10, function()
				s:Select(i)
				onSelect(i)
			end)
			b:SetHeight(s.opts.height or 24)
			b.count = UI.Words(b, UI.NameFont(10))
			b.count:SetPoint("LEFT", b.text, "RIGHT", 4, 0)
			b.count:Hide()
			s.buttons[i] = b
		end
		function s:Select(i)
			self.selected = i
			for j, b in ipairs(self.buttons) do
				b:SetPrimary(j == i)
				UI.Ink(b.text, j == i and C.onFill or C.dim)
				UI.Ink(b.count, j == i and C.onFill or C.dim, 0.7)
			end
		end
		function s:SetLabel(i, text)
			local b = self.buttons[i]
			if not b or b.text:GetText() == text then return end
			b.text:SetText(text)
			Fit(self)
		end
		function s:SetCount(i, n)
			local b = self.buttons[i]
			if not b then return end
			local text = n and tostring(n) or nil
			if b.count:IsShown() == (text ~= nil) and b.count:GetText() == text then return end
			b.count:SetText(text or "")
			b.count:SetShown(text ~= nil)
			Fit(self)
		end
		Fit(s)
		s:Select(1)
		return s
	end
end

local function Refit()
	for line in pairs(fitted) do UI.LineFit(line) end
	for texture, units in pairs(glyphs) do UI.GlyphFit(texture, units) end
	for texture, box in pairs(boxes) do UI.BoxFit(texture, box[1], box[2]) end
	for h in pairs(studded) do UI.LookFit(h) end
	UI.GroupRefit()
end
Shy:On("SHY_HUD_SCALED", Refit)
local refit = CreateFrame("Frame")
refit:RegisterEvent("UI_SCALE_CHANGED")
refit:RegisterEvent("DISPLAY_SIZE_CHANGED")
refit:SetScript("OnEvent", Shy.Clocked("ui: fitted again for the screen's scale", Refit))

-- What stands in a header (a title, a count, a tab, a button): its `point` on the header's middle (where every
-- header's words stand: between its lip and its line), on `side` of it ("LEFT", "RIGHT" or "CENTER"), `x` along.
-- `house` is any header's owner: a UI.Panel with a title, or a kit plate's set with one (a docked piece places its
-- controls in the header of the housing it stands in this way, whichever that is).
--   UI.OnHead(count, "RIGHT", house, "RIGHT", -PAD)
-- UI.HeadPoint gives the same as an anchor, { point, to, relativePoint, x, y }: for a kit's Place (a region of the
-- game's, put back when the kit lets go).
function UI.HeadPoint(point, house, side, x)
	local to, y = house, house.shyHeadMid
	if not y then to, y = house.headTo, house.headY end
	if not y then y = UI.HeadMid(house) end
	side = side or "LEFT"
	return { point, to, side == "CENTER" and "TOP" or "TOP" .. side, x or 0, -y }
end

function UI.OnHead(region, point, house, side, x)
	region:SetPoint(unpack(UI.HeadPoint(point, house, side, x)))
end

-- A header's middle down from its top edge: half way between its lip (UI.HEAD's: a console piece's or a window's)
-- and its line, the line `rim + strip` under that edge.
function UI.HeadMiddle(rim, strip, lip)
	return (lip + rim + strip) / 2
end

-- The border of a look: how far in from a housing's edge the frame's inner face stands on each side, in units
-- { left, top, right, bottom }. Whatever stands in a housing nests inside it (a header's icon and title from the
-- left, its controls from the right, a piece's content all round), so nothing of ours sits on the frame in any
-- look, and a frame that grows (Heritage's Frame option) moves them in with it. Every look names it: a built-in
-- in UI.LOOK_BORDER (its fill's inset: the edge is a hairline), a look of its own file through its `border` (a
-- number for all four sides, a table of four, or a function(housing) for a frame sized by the piece). Read it
-- only through UI.LookBorder: the one measure both header makers (UI.Head, kit:Head) nest by.
UI.LOOK_BORDER = { forged = LOOK.FILL_IN, steel = LOOK.FILL_IN, clear = LOOK.FILL_IN,
	eclipse = LOOK.ECLIPSE.inset, riveted = LOOK.RIVETED.inset }

local function Sides(b)
	if type(b) == "table" then return b[1] or b.left or 0, b[2] or b.top or 0, b[3] or b.right or 0, b[4] or b.bottom or 0 end
	b = tonumber(b) or 0
	return b, b, b, b
end

-- The look `x` is in: a look's key, a housing (UI.LookBuild's), or nil for a piece wearing no look (the forged
-- make's measure).
local function LookOf(x)
	local h = type(x) == "table" and x or nil
	local name = h and (type(h.look) == "string" and h.look or h.building) or x
	if type(name) == "table" then name = name.look end
	return name, h
end

-- left, top, right, bottom of the border in that look (see UI.LOOK_BORDER).
function UI.LookBorder(x)
	local name, h = LookOf(x)
	local kind = name and KINDS[name]
	local b = kind and (kind.border or kind.headOut) or (name and UI.LOOK_BORDER[name]) or LOOK.FILL_IN
	if type(b) == "function" then b = b(h) end
	return Sides(b)
end

-- left, top, right, bottom: how much further in than the family's own margins a window lays its content in this look
-- (the top's under its head), so nothing it holds stands on the look's work round its edge (a look of its own file's
-- `content`: a number for all four sides, a table of four, or function(housing)); 0 for the core's looks. A window
-- never reads it: it lays its content on its body (UI.Body), which the core keeps there.
function UI.LookContentIn(x)
	local name, h = LookOf(x)
	local kind = name and KINDS[name]
	local c = kind and kind.content
	if type(c) == "function" then c = c(h) end
	return Sides(c or 0)
end

-- A window's body: the frame its content is laid on, the window's own rect less what its look keeps clear round the
-- edge (UI.LookContentIn), moved whenever the look or its options change. Everything a window holds below its head,
-- its foot included, stands on the body with the family's own margins, never on the window's edge, and the window is
-- that much bigger than its content, so no window measures a look. UI.Head gives every window with a header one.
--   local body = UI.Body(box)
--   list:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -40)
-- Its size is the window's less the clearance (UI.BodySize). A window that flows (a grip with `flow`) is told its
-- body's size, and every size it is made, kept and held at is its body's (Grip.lua); one that sizes itself says how
-- big it is as though its look kept nothing clear (UI.BodyFit), and wears the clearance besides, now and whenever
-- it changes. "SHY_BODY" (window) fires as a body's clearance changes.
-- A window holding a protected frame (a secure button) is protected itself: in a fight its body is placed and its
-- size worn once the fight is over.
UI.BodyWaiting = setmetatable({}, { __mode = "k" })
do
	local wait = CreateFrame("Frame")
	wait:RegisterEvent("PLAYER_REGEN_ENABLED")
	wait:SetScript("OnEvent", function()
		for f in pairs(UI.BodyWaiting) do
			UI.BodyWaiting[f] = nil
			UI.PlaceBody(f)
			local fit = f.shyBodyFit
			if fit then UI.BodyFit(f, fit[1], fit[2]) end
		end
	end)
end

function UI.PlaceBody(f)
	local body = f.shyBody
	if not body then return end
	if InCombatLockdown() and f:IsProtected() then
		UI.BodyWaiting[f] = true
		return
	end
	local l, t, r, b = UI.LookContentIn(f.shyLook)
	local was = body.shyIn
	if was[1] == l and was[2] == t and was[3] == r and was[4] == b and body.shyPlaced then return end
	was[1], was[2], was[3], was[4], body.shyPlaced = l, t, r, b, true
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", f, "TOPLEFT", l, -t)
	body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -r, b)
	local fit = f.shyBodyFit
	if fit then UI.BodyFit(f, fit[1], fit[2]) end
	Shy:Fire("SHY_BODY", f)
end

function UI.Body(f)
	local body = f.shyBody
	if not body then
		body = CreateFrame("Frame", nil, f)
		body.shyIn = { 0, 0, 0, 0 }
		f.shyBody = body
		if f.shyLook then UI.LookFit(f.shyLook, true) end   -- (its look may lay its inset work now: g.cleared)
	end
	UI.PlaceBody(f)
	return body
end

-- A window is two surfaces with a setting each, not one.
--   the housing   its fill, its strip, its edge and the look's work round them, at Theme.Strength()
--   the sheet     what its content is read off, under the rows and words, at Theme.Sheet()
-- So the world can show through the frame of a window without washing out what the window is for. The sheet
-- is laid on the body -- the rect a window's content already stands on -- and is the thing to anchor to when
-- something must cover the content rather than the window (a bar at the foot).
--   UI.BodySheet(f, true)                   under the head, to the body's other three edges
--   UI.BodySheet(f, true, { l, t, r, b })   further in than that (the hub leaves its rail off the sheet)
--   UI.BodySheet(f, false)                  none
--   -> the sheet, or nil
-- It is the content's, so it stops at the frame: never nearer the window's sides and foot than the look's
-- border (UI.LookBorder), whose inner face it meets. It lies over the housing, and would cover the frame there.
-- Laid again as the look or its options change (UI.SetLook).
function UI.BodySheet(f, on, inset)
	local body = f and f.shyBody
	if not body then return nil end
	body.shySheetOn, body.shySheetIn = on and true or false, on and inset or nil
	if not on then
		if body.shySheet then body.shySheet:Hide() end
		return nil
	end
	local sheet = body.shySheet
	if not sheet then
		-- (under everything the body holds, over the window's own fill and the look's work beneath it)
		sheet = body:CreateTexture(nil, "BACKGROUND", nil, -8)
		body.shySheet = sheet
		Theme.Paint(sheet, C.sheet)
	end
	-- (the head is the housing's, never the content's: the sheet starts under it unless told otherwise)
	local head = f.shyLook and f.shyLook.headLine or 0
	local l, t, r, b = 0, head, 0, 0
	if type(inset) == "table" then
		l, t, r, b = inset[1] or l, inset[2] or t, inset[3] or r, inset[4] or b
	end
	-- (the body may stand in from the edge already, by the look's clearance: only what is left of the border)
	local bl, _, br, bb = UI.LookBorder(f.shyLook)
	local il, _, ir, ib = UI.BodyIn(f)
	l, r, b = max(l, bl - il), max(r, br - ir), max(b, bb - ib)
	sheet:ClearAllPoints()
	sheet:SetPoint("TOPLEFT", body, "TOPLEFT", l, -t)
	sheet:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -r, b)
	sheet:Show()
	return sheet
end

-- left, top, right, bottom the body stands in from its window's edges now; 0 for a window without a body.
function UI.BodyIn(f)
	local body = f and f.shyBody
	if not body then return 0, 0, 0, 0 end
	local i = body.shyIn
	return i[1], i[2], i[3], i[4]
end

-- The body's width and height: the window's less its look's clearance.
function UI.BodySize(f)
	local l, t, r, b = UI.BodyIn(f)
	return f:GetWidth() - l - r, f:GetHeight() - t - b
end

-- A window that sizes itself to what it holds: `width` and `height` as though its look kept nothing clear round
-- its edge (its body's size plus the family's own margins). The window wears that and the look's clearance (a
-- piece of the HUD through Shy.HUD.Resize), and again whenever the clearance changes.
function UI.BodyFit(f, width, height)
	local fit = f.shyBodyFit
	if not fit then
		fit = {}
		f.shyBodyFit = fit
	end
	fit[1], fit[2] = width, height
	if InCombatLockdown() and f:IsProtected() then
		UI.BodyWaiting[f] = true
		return
	end
	local l, t, r, b = UI.BodyIn(f)
	width, height = width + l + r, height + t + b
	if f.id and Shy.HUD.Resize then Shy.HUD.Resize(f, width, height) else f:SetSize(width, height) end
end

-- How far past a housing's edge its frame is drawn, in units (a look of its own file's `out`: a number, or
-- function(housing) for a frame that differs by piece: its mini); 0 for a look whose frame keeps inside the edge. What
-- stands against a housing from outside keeps this clear of it (the first cell under the head's plate: Shy.Top).
function UI.LookOut(x)
	local name, h = LookOf(x)
	local kind = name and KINDS[name]
	local out = kind and kind.out
	if type(out) == "function" then out = out(h) end
	return tonumber(out) or 0
end

-- A tail off a housing's foot (a chat bubble's) in the look it wears: the look's own foot edge running on down the
-- tail's flanks to its point (Media/Tail<name><layer>, measured in Shy.Tails), over the look's own face laid again
-- inside it. Returns the tail's name, its measures, its edge layers as the look colors its own edge ({ layer =,
-- color = (a table or function), alpha =, blend = }) and its inside as the look lays its face, bottom up ({ fill =
-- true }: the housing's fill; { color =, alpha =, file =, tile = units a repeat, blend = }), cut to
-- Media/Tail<name>Inside. Media/Tail<name>Notch is cut from the housing's own edge (UI.LookEdges). A look of its own
-- file says its own (UI.LookKind's `tail(h) -> name, layers, inside`); the core's are here.
local TAIL = { dark = { 0, 0, 0 }, fill = { { fill = true } } }
function TAIL.Bordered(h)
	return function()
		local metal = h and h.owner and h.owner.shyMetal or Theme.skin.metal
		return Color(metal)
	end
end
TAIL.core = {
	forged = function(h) return "Forged", { { layer = "Edge", color = TAIL.Bordered(h) } } end,
	steel = function(h) return "Steel", { { layer = "Edge", color = TAIL.Bordered(h) } } end,
	clear = function() return "Clear", { { layer = "Edge", color = WHITE } } end,
	eclipse = function() return "Eclipse", { { layer = "Edge", color = TAIL.dark } } end,
	riveted = function()
		return "Riveted", { { layer = "Edge", color = WHITE } }, { { fill = true }, { file = LOOK.BRUSHED, tile = 128, color = WHITE } }
	end,
}
-- The core's parts that draw a housing's edge (not its face, not what lies behind it).
TAIL.edges = { "edge", "pane", "metalEdge", "well", "footWell", "rimTop", "rimBottom", "rimLeft", "rimRight" }
function UI.LookTail(x)
	local name, h = LookOf(x)
	local tails = Shy.Tails or {}
	local kind = name and KINDS[name]
	if kind and kind.tail then
		local tail, layers, inside = kind.tail(h)
		if tails[tail] then return tail, tails[tail], layers, inside or TAIL.fill end
	end
	local tail, layers, inside = (TAIL.core[name] or TAIL.core.forged)(h)
	return tail, tails[tail], layers, inside or TAIL.fill
end

-- The regions that draw a housing's edge in the look it wears now (the forged edge, the core's edge parts, its
-- rivets, a look kind's `edge` regions and pools but what lies behind the piece): what a tail is cut from. Into
-- `out` if given.
function UI.LookEdges(h, out)
	out = out or {}
	if not h then return out end
	local function Add(t)
		if t and t.AddMaskTexture then out[#out + 1] = t end
	end
	if h.owner and h.owner.shyEdge then Add(h.owner.shyEdge) end
	for _, key in ipairs(TAIL.edges) do Add(h[key]) end
	for _, t in ipairs(h.rivets or {}) do Add(t) end
	local kind = KINDS[h.look]
	for _, key in ipairs(kind and kind.edge or {}) do
		if not Kin.Listed(kind.behind, key) then
			Add(h[key])
			local pool = h.pools and h.pools[key]
			if pool then
				for _, t in ipairs(pool.list) do Add(t) end
			end
		end
	end
	return out
end

-- The border's right side alone, as the header makers of old asked it.
function UI.LookHeadIn(look)
	local _, _, right = UI.LookBorder(look)
	return right
end

-- How far a look's frame draws past the forged make's hairline on this housing (a look of its own file only).
function UI.LookFrameOut(look)
	local name = LookOf(look)
	if not (name and KINDS[name]) then return 0 end
	local l, t, r, b = UI.LookBorder(look)
	return max(l, t, r, b)
end

-- The look housing on a header: a kit plate's `.look`, a panel's shyLook, or the housing itself.
local function HeadLook(house)
	if not house then return nil end
	if house.shyLook and house.shyLook.look then return house.shyLook end
	local look = house.look
	if type(look) == "table" and look.look then
		if not look.owner then look.owner = house.owner end
		return look
	end
	return house
end

function UI.HeadLookOut(house)
	return UI.LookHeadIn(HeadLook(house))
end

-- A header's inner edges: the plate's inset plus the look's border on that side.
local function HeadInset(house)
	if not house then return 0, 0, 0, 0 end
	local inset = house.bounds and house.bounds.inset or house.inset or { 0, 0, 0, 0 }
	return inset[1] or 0, inset[2] or 0, inset[3] or 0, inset[4] or 0
end

function UI.HeadInnerRight(house)
	local _, _, right = UI.LookBorder(HeadLook(house))
	local _, _, inset = HeadInset(house)
	return inset + right
end

function UI.HeadInnerLeft(house)
	local left = UI.LookBorder(HeadLook(house))
	local inset = HeadInset(house)
	return inset + left
end

-- How far in from a housing's top-right edge its header's inner margin stands: the inner edge plus the
-- strip's pad and its clear, so a control's border does not sit on the frame.
function UI.HeadEdgeRight(house)
	if not house then return 0 end
	return UI.HeadCloseRight(house)
end

-- Content inset on a HUD piece wearing a look: the forged band plus a thick frame's outreach (Royal, Heritage bold).
function UI.LookFillIn(look)
	return UI.LookArt.FILL_IN + UI.LookFrameOut(look)
end

-- Where a header × sits: in from the look's inner face by as much room as the strip leaves over it, so the corner
-- it stands in is square in every size and look; never nearer than the row's pad and the clear, so the control's
-- border does not sit on the frame.
function UI.HeadCloseRight(house, size)
	size = size or UI.HEAD.window
	local over = UI.HeadMid(house, size) - size.control / 2 - UI.HeadInnerTop(house)
	return UI.HeadInnerRight(house) + max(over, (size.rowPad or 1) + (size.clear or 0))
end

-- Where a header's words begin from the left (its icon first, when it has one): the strip's pad, counted from the
-- look's inner face as the forged make's pad is from its hairline, so a thick frame moves the title in with it.
function UI.HeadLeft(house, size)
	size = size or UI.HEAD.window
	return UI.HeadInnerLeft(house) + size.pad - LOOK.FILL_IN
end

-- The title strip's numbers on a header's owner (a kit plate, a panel, or a panel's shyLook).
local function HeadStrip(house)
	if not house then return nil end
	if house.headStripTop then return house end
	if house.shyLook and house.shyLook.headStripTop then return house.shyLook end
	return house
end

-- The strip's middle down from the piece's top: the stored head mid (lip to line). A look
-- does not move it; titles, OnHead and the × all stand here.
function UI.HeadMid(house, size)
	size = size or UI.HEAD.window
	local strip = HeadStrip(house)
	return (strip and (strip.headY or strip.shyHeadMid))
		or UI.HeadMiddle(2, size.line - 2, size.lip)
end

-- How far down from the piece's top the strip's room begins: its own top, or a thick frame's inner face over it.
function UI.HeadInnerTop(house)
	local _, top = UI.LookBorder(HeadLook(house))
	local _, inset = HeadInset(house)
	local strip = HeadStrip(house)
	return max(inset + top, strip and strip.headStripTop or 0)
end

-- SetPoint y on TOP* anchors for a title strip (same sign as Kit:Head's mid = -headY).
function UI.HeadStripMid(house, size, _)
	return -UI.HeadMid(house, size)
end

-- Where a header's title and other controls must end before the × and the room it keeps.
function UI.HeadCloseReserve(house, size, closeW)
	size = size or UI.HEAD.window
	closeW = closeW or size.control
	return UI.HeadCloseRight(house, size) + closeW + (size.gap or 8)
end

-- Packed controls on a skinned game window's title strip (a Kit:Head plate set).
UI.HeadRail = {}

local function HeadRailEntry(entry)
	if type(entry) == "table" and (entry[1] or entry.region) then
		return entry[1] or entry.region, entry.y or 0, entry.gap
	end
	return entry, 0, nil
end

-- Width of `leading` on the title strip (`apart` before each control, then the control).
function UI.HeadRail.LeadingReserve(leading, size, packGap)
	size = size or UI.HEAD.window
	local gap, w = packGap or size.apart or 2, 0
	for _, entry in ipairs(leading or {}) do
		local region, _, g = HeadRailEntry(entry)
		if region then
			local rw = region:GetWidth()
			if not rw or issecretvalue(rw) or rw <= 0 then rw = size.control end
			w = w + (g or gap) + rw
		end
	end
	return w
end

-- How far in from `to`'s top-right the title's RIGHT anchor sits (Kit:Head's `right` term).
-- The ×'s reserve (look-aware: Heritage Frame) plus any leading packed beside it, then the title's gap.
function UI.HeadRail.TitleRight(house, pack, size)
	size = size or UI.HEAD.window
	return UI.HeadCloseRight(house, size) + size.control + UI.HeadRail.LeadingReserve(pack and pack.leading, size, pack and pack.gap) + (size.gap or 8)
end

-- pack.close: the game's CloseButton; pack.leading: right-to-left beside it (leading[1] next to the ×).
-- pack.moveClose: false keeps Blizzard's × anchor (only leading are placed); default true on Kit:Head sets.
-- kit: Shy.Skin kit, so anchors restore on Refresh (optional).
-- Same inset as UI.HeadCloseRight: one strip pad inside the look's inner edge.
function UI.HeadRail.CloseSlotRight(house, size)
	return UI.HeadCloseRight(house, size)
end

function UI.HeadRail.RegionSize(region, fallbackW, fallbackH)
	local w, h = region:GetWidth(), region:GetHeight()
	if not w or issecretvalue(w) or w <= 0 then w = fallbackW end
	if not h or issecretvalue(h) or h <= 0 then h = fallbackH or fallbackW end
	return w, h
end

function UI.HeadRail.Pack(house, pack, kit)
	if not (house and house.headTo) then return end
	pack = pack or {}
	local size = UI.HEAD.window
	local to = house.headTo
	local gap = pack.gap or size.apart or 2
	local closeGap = pack.closeGap or gap
	local slot = size.control
	local mid = UI.HeadStripMid(house, size, slot)
	local moveClose = pack.moveClose ~= false
	local function put(region, point, w, h)
		if not region then return end
		if kit then
			kit:Place(region, w, h, point)
		else
			region:ClearAllPoints()
			region:SetPoint(unpack(point))
			if w then region:SetSize(w, h or w) end
		end
	end
	local function stand(region, right, rw, yOff)
		local _, bh = UI.HeadRail.RegionSize(region, rw, slot)
		local y = UI.HeadStripMid(house, size, bh) - (yOff or 0)
		put(region, { "CENTER", to, "TOPRIGHT", -(right + rw / 2), y })
	end
	local right = UI.HeadCloseRight(house, size)
	local close = pack.close
	if close and moveClose then
		put(close, { "CENTER", to, "TOPRIGHT", -(right + slot / 2), mid }, slot, slot)
		right = right + slot + closeGap
	elseif not close then
		right = UI.HeadCloseRight(house, size)
	end
	for _, entry in ipairs(pack.leading or {}) do
		local region, yOff, g = HeadRailEntry(entry)
		if region then
			local rw = UI.HeadRail.RegionSize(region, slot, slot)
			stand(region, right, rw, yOff)
			right = right + rw + (g or gap)
		end
	end
	if house.titleText and kit and house.titleLeft and pack.leading and #pack.leading > 0 then
		local right = UI.HeadRail.TitleRight(house, pack, size)
		kit:Place(house.titleText, nil, size.text + 2,
			{ "LEFT", to, "TOPLEFT", house.titleLeft, mid },
			{ "RIGHT", to, "TOPRIGHT", -right, mid })
	end
end

-- A panel's header shown, or put away whole (a piece docked in a housing whose header it borrows): its strip, its
-- gloss and its line, and with the line what lies over it (the trim, the seam, the flare, its marks). Dressing the
-- panel in a look again keeps it so.
function UI.PanelHead(f, shown)
	f.shyHeadless = not shown or nil
	if f.shyStrip then f.shyStrip:SetShown(shown) end
	if f.shyGloss then
		local look = f.shyLook and f.shyLook.look or Theme.Look()
		f.shyGloss:SetShown(shown and (select(5, UI.LookStrip(look, 0, 0, 0, 1))) or false)
	end
	if f.shyLine then f.shyLine:SetShown(shown) end
end

-- A header's accent line, the one make every header wears (UI.Panel's, a kit plate's, kit:Line's, UI.Header's, a
-- page's tabs'): a texture of its owner's (regions only, so it is safe on a frame of the game's), the accent's ramp
-- along it, UI.LINE fitted to the pixel. `under`: laid along that region's foot; nil, placed by the caller. Its look
-- is UI.LookLine's (the riveted trim, a look kind's own), its lit stretches UI.LineMark's.
--   local line = UI.HeadLine(owner, strip)
local ramped = setmetatable({}, { __mode = "k" })
-- One color: the accent from its deep shade to its light. A ramp worn: the ramp itself (Theme's "The gradient"),
-- the line being painted in the accent.
local WHITE_LINE = { 1, 1, 1, 1 }
local function Ramp(line)
	if line.shyAccent then return Theme.Paint(line, line.shyAccent) end   -- a sample's own accent, one color
	if Theme.Gradient() then return Theme.Paint(line, Theme.Accent) end
	Theme.Paint(line, WHITE_LINE)
	line:SetGradient("HORIZONTAL", CreateColor(B.Ramp(0)), CreateColor(B.Ramp(1)))
end
Shy:On("SHY_THEME", function()
	for line in pairs(ramped) do Ramp(line) end
end)

function UI.HeadLine(owner, under)
	local line = owner:CreateTexture(nil, "BORDER", nil, 2)   -- over the edge (0) and the brackets (1)
	if under then
		line:SetPoint("TOPLEFT", under, "BOTTOMLEFT")
		line:SetPoint("TOPRIGHT", under, "BOTTOMRIGHT")
	end
	line:SetColorTexture(1, 1, 1, 1)
	UI.LineFit(line)
	line.shyAccent = owner.shyAccent
	ramped[line] = true
	Ramp(line)
	return line
end

-- A lit stretch of a header's line: an open tab's. As tall as the line, fitted to the
-- pixel the same way, and dressed by the look as the line is (a trimmed look's: a length of the same trim, lit; the
-- others': a plain bar of light). Marks stand over the line on a frame of their own, so a look that puts the line
-- itself away (Riveted, a look kind's) keeps them, and they go when the line is hidden.
--   local mark = UI.LineMark(owner, line, color)   -- color: Theme.light unless told (a table or a function)
--   mark:Span(from, to, inLeft, inRight)           -- from `from`'s left edge to `to`'s right (`from`'s unless told)
-- The mark is a texture: Show, Hide, SetShown, SetAlpha as any.
local marks = setmetatable({}, { __mode = "k" })
local function DressMark(mark)
	local zone = UI.LOOK_ZONES[Theme.Look()]
	if zone and zone.trim then
		mark:SetTexture(zone.trim, "REPEAT", "CLAMP")
		mark:SetHorizTile(true)
	else
		mark:SetColorTexture(1, 1, 1, 1)
	end
	Theme.Tint(mark, mark.shyColor, 1)
end
Shy:On("SHY_THEME", function()
	for mark in pairs(marks) do DressMark(mark) end
end)

local function Span(mark, from, to, inLeft, inRight)
	mark:ClearAllPoints()
	mark:SetPoint("TOP", mark.shyLine, "TOP")
	mark:SetPoint("LEFT", from, "LEFT", inLeft or 0, 0)
	mark:SetPoint("RIGHT", to or from, "RIGHT", -(inRight or inLeft or 0), 0)
end

function UI.LineMark(owner, line, color)
	local holder = line.shyMarks
	if not holder then
		holder = CreateFrame("Frame", nil, owner)
		holder:SetAllPoints(owner)
		holder:EnableMouse(false)
		-- Over the line: above a line that is a frame of its own, else above its owner's regions.
		holder:SetFrameLevel((line:IsObjectType("Frame") and line or owner):GetFrameLevel() + 1)
		line.shyMarks = holder
		if owner.shyHousing then owner.shyHousing[#owner.shyHousing + 1] = holder end
		Follow(line)
		Over(line)
	end
	local mark = holder:CreateTexture(nil, "ARTWORK")
	mark.shyLine, mark.shyColor, mark.Span = line, color or Theme.light, Span
	UI.LineFit(mark)
	marks[mark] = true
	DressMark(mark)
	return mark
end

-- A row or line that opens something, lit the one way the family lights one: under the mouse a pane of the accent
-- with a bar of it down its left; while it is the one being looked at (held: its page open, its ground lit on the
-- map) the bar stays at full strength over a fainter pane, so what you clicked reads as the one shown.
--   light = UI.RowLight(frame [, out [, host]])   out = { left, top, right, bottom }: how far past the frame it
--                                                 reaches. host: the frame whose regions it is (a frame laid over
--                                                 words that are its parent's: the light under them, not over)
--   light:Set(over, held)
--   UI.ROW_INSET   where a lit row's content starts, lit or not: past the bar with a little room after it
local ROW_LIGHT = { over = 0.18, held = 0.10, bar = 2, barOver = 0.7, barHeld = 1, pad = 5 }
UI.ROW_INSET = ROW_LIGHT.bar + ROW_LIGHT.pad
function UI.RowLight(frame, out, host)
	out = out or {}
	local back = (host or frame):CreateTexture(nil, "BACKGROUND", nil, 2)
	back:SetColorTexture(1, 1, 1, 1)
	back:SetPoint("TOPLEFT", frame, "TOPLEFT", -(out.left or 0), out.top or 0)
	back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out.right or 0, -(out.bottom or 0))
	local bar = (host or frame):CreateTexture(nil, "BORDER", nil, 2)
	bar:SetColorTexture(1, 1, 1, 1)
	bar:SetWidth(ROW_LIGHT.bar)
	bar:SetPoint("TOPLEFT", back, "TOPLEFT")
	bar:SetPoint("BOTTOMLEFT", back, "BOTTOMLEFT")
	back:Hide()
	bar:Hide()
	local light = { back = back, bar = bar }
	-- (On a host, the frame's hiding does not hide them: they go with it.)
	if host and host ~= frame then frame:HookScript("OnHide", function() light:Set(false, false) end) end
	function light:Set(over, held)
		self.over, self.held = over and true or false, held and true or false
		local on = self.over or self.held
		back:SetShown(on)
		bar:SetShown(on)
		if not on then return end
		UI.Tint(back, Theme.Accent, self.over and ROW_LIGHT.over or ROW_LIGHT.held)
		UI.Tint(bar, Theme.Accent, self.held and ROW_LIGHT.barHeld or ROW_LIGHT.barOver)
	end
	return light
end

function UI.LookLine(owner, line, look, strip)
	UI.LineFit(line)
	local zone = look and UI.LOOK_ZONES[look]
	local trimmed = zone and zone.trim
	local kind = look and KINDS[look]
	line:SetAlpha((look == "clear" and 0.6) or (trimmed and 0) or (kind and kind.lineAlpha) or 1)
	-- A look kind's own regions over the line (UI.LookKind's `line`): made once a line, shown with it while worn.
	if kind and kind.line and not (line.shyKinds and line.shyKinds[look]) then
		line.shyKinds = line.shyKinds or {}
		local regions = kind.line(owner, line, strip) or {}
		line.shyKinds[look] = regions
		for _, t in ipairs(regions) do
			Kin.Claim(t)   -- on a game frame's line: ours, never taken for the game's art
			if owner.shyHousing then owner.shyHousing[#owner.shyHousing + 1] = t end
		end
	end
	line.shyKindOn = look or nil
	for _, t in ipairs(kind and line.shyKinds and line.shyKinds[look] or {}) do Kin.Again(t) end
	if line.shyKinds then Follow(line) end
	-- A look whose line is a trim of metal (UI.LOOK_ZONES): the trim over the line, the line itself put away.
	local trim = line.shyTrim
	if trimmed and not trim then
		trim = owner:CreateTexture(nil, "ARTWORK", nil, -1)
		trim:SetPoint("TOPLEFT", line, "TOPLEFT")
		trim:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT")
		Theme.Tint(trim, UI.LookAccent(owner), 1)
		Kin.Claim(trim)
		line.shyTrim = trim
		if owner.shyHousing then owner.shyHousing[#owner.shyHousing + 1] = trim end
	end
	if trim then
		if trimmed then
			trim:SetTexture(trimmed, "REPEAT", "CLAMP")
			trim:SetHorizTile(true)
		end
		line.shyTrimmed = trimmed and true or false
		Follow(line)
	end
	Over(line)
	local flare = line.shyFlare
	if look == "eclipse" and not flare then
		flare = {}
		-- Two halves, each fading toward its own end: brightest in the middle, gone at the ends.
		for i = 1, 2 do
			local t = UI.LookWear(owner:CreateTexture(nil, "ARTWORK", nil, -1), UI.GLOSS)
			t:SetTexCoord(0, 1, 1, 0)   -- flipped: light from below, from the line
			t:SetPoint("BOTTOMLEFT", line, i == 1 and "TOPLEFT" or "TOP")
			t:SetPoint("BOTTOMRIGHT", line, i == 1 and "TOP" or "TOPRIGHT")
			if strip then t:SetPoint("TOP", strip, "TOP") else t:SetHeight(FLARE_H) end
			flares[t] = i == 1 and { 0, 1 } or { 1, 0 }
			t.shyAccent = owner.shyAccent
			Flare(t, flares[t])
			flare[i] = t
		end
		line.shyFlare = flare
	end
	if flare then
		line.shyFlared = look == "eclipse"
		Follow(line)
		Over(line)
	end
end

-- Dresses a housing in a look. p: fill = its fill texture (fitted to h.to inside h.inset unless p.fitTo and
-- p.fitInset say where), forged = the regions of the forged make alone (the edge, brackets, caps, facets),
-- metal = the color of its edge, gloss / line / strip = its title strip's. look = false: no look at all, every
-- region of the looks put away and the forged make's left as its owner has them (an inner piece).
function UI.LookDress(h, look, p)
	h.look = look or "forged"
	if p and p.fill then h.fill = p.fill end
	if look == false then
		h.shaded = false
		for _, region in ipairs(UI.LookParts(h)) do region:Hide() end
		if p and p.line then UI.LookLine(h.owner, p.line, false, p.strip) end
		return
	end
	h.stamp = Theme.LookStamp()   -- the look options dressed in (a change of one dresses it again)
	h.dressed = (h.dressed or 0) + 1   -- counts its dresses: what a fit set for one dress it sets again for the next
	local began = debugprofilestop()
	if p and p.line then h.line = p.line end
	local forged, clear, eclipse = look == "forged", look == "clear", look == "eclipse"
	local steel, riveted = look == "steel", look == "riveted"
	local RV = LOOK.RIVETED
	-- A look of its own file: its regions made the first time, every other kind's put away.
	local kind = KINDS[h.look]
	if kind then Kin.Kindled(h, h.look, kind) end
	Kin.Unkindle(h, kind and h.look or nil)
	-- Every part's art as it should be (UI.LookWear), before what goes by size lays its coordinates on it.
	for _, t in ipairs(UI.LookParts(h)) do Kin.Again(t) end
	-- A window's content (a map, a list) is never under glass: the frost, sky, sheen and foot are the HUD's.
	local glassy = clear and not h.solid
	for _, region in ipairs(p.forged) do region:SetShown(forged) end
	-- The shade is for a piece the world shows through; a window's housing may stand over its content (a
	-- map's border frame over the map), so a solid one casts none (nor one too small for it: LookFit).
	h.shaded = not forged and not h.solid and not (kind and kind.shade == false)
	h.shade:SetShown(h.shaded)
	h.shade:SetAlpha(clear and LOOK.CLEAR.shade or eclipse and LOOK.ECLIPSE.shade or riveted and RV.shade
		or kind and kind.shade or 1)
	h.halo:SetShown(eclipse)
	Theme.Tint(h.halo, UI.LookAccent(h), 1)
	h.edge:SetShown(steel)
	Theme.Tint(h.edge, p.metal)
	h.pane:SetShown(clear or eclipse)
	Theme.Tint(h.pane, eclipse and DARK or WHITE, 1)
	h.frost:SetShown(glassy)
	h.sky:SetShown(glassy)
	h.sky:SetAlpha(1)
	h.foot:SetShown(glassy or (riveted and not h.solid))
	h.foot:SetAlpha(riveted and RV.foot or 1)
	if not glassy then h.sheen:Hide() end   -- frosted: LookFit shows it when the pane is wide enough
	h.light:SetShown(steel or clear)
	Theme.Tint(h.light, UI.LookAccent(h), 1)
	-- The steel: its brushing and sheen fade with the fill on screen (the world through it is never filmed over),
	-- the sheen a little softer in a window, over what is written there.
	h.brushed:SetShown(riveted)
	h.plateSheen:SetShown(riveted)
	h.brushedLit:SetShown(riveted)
	h.metalEdge:SetShown(riveted)
	-- The content's well, in the look's zones (its shape is LookFit's).
	local zone = UI.LOOK_ZONES[h.look]
	local well = zone and zone.well
	if well then
		h.well:SetTexture(well.art)
		h.well:SetTextureSliceMargins(well.slice, well.slice, well.slice, well.slice)
		Theme.Paint(h.wellFill, function()
			local c = well.color
			return c[1], c[2], c[3], h.solid and well.solid or well.alpha * Theme.Strength() ^ 0.5
		end)
	else
		h.wellFill:Hide()
		h.well:Hide()
	end
	local footWell = zone and zone.footWell
	if footWell then
		h.footWell:SetTexture(footWell.art)
		h.footWell:SetTextureSliceMargins(footWell.slice, footWell.slice, footWell.slice, footWell.slice)
		Theme.Paint(h.footFill, function()
			local c = footWell.color
			return c[1], c[2], c[3], h.solid and footWell.solid or footWell.alpha * Theme.Strength() ^ 0.5
		end)
	else
		h.footFill:Hide()
		h.footWell:Hide()
	end
	-- Round a placed content (LookFit lays them): the band a header's strip is, in this look, at a strip's strength.
	for _, t in ipairs(h.rims) do
		Theme.Paint(t, function()
			local c = C.hudStrip
			return UI.LookStrip(h.look, c[1], c[2], c[3], h.solid and 1 or UI.LookAlpha(h.look, c[4]))
		end)
	end
	local function Through() return h.solid and 1 or min(1, Theme.Strength() * 1.6) end
	Theme.Tint(h.brushed, function() return 1, 1, 1, h.solid and 1 or Theme.Strength() ^ 0.5 end)
	Theme.Tint(h.plateSheen, function() return 1, 1, 1, RV.sheen * (h.solid and RV.solid or Through()) end)
	Theme.Tint(h.brushedLit, function() return 1, 1, 1, RV.lit * Through() end)
	-- The title strip: its gloss where the look has one (UI.LookStrip); its line by look (UI.LookLine).
	if p.gloss then p.gloss:SetShown((select(5, UI.LookStrip(look, 0, 0, 0, 1)))) end
	if p.line then UI.LookLine(h.owner, p.line, look, p.strip) end
	-- The fill is set in under the edge's band (the forged edge covers its own).
	local inset = forged and 0 or eclipse and LOOK.ECLIPSE.inset or riveted and RV.inset
		or kind and kind.inset or LOOK.FILL_IN
	if h.fillIn ~= inset then
		h.fillIn = inset
		local to, i = p.fitTo or h.to, p.fitInset or h.inset
		p.fill:ClearAllPoints()
		p.fill:SetPoint("TOPLEFT", to, "TOPLEFT", i[1] + inset, -i[2] - inset)
		p.fill:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -i[3] - inset, i[4] + inset)
	end
	if kind and kind.dress then kind.dress(h, p) end
	UI.LookFit(h, true)
	Kin.dressClock:Lap(debugprofilestop() - began)
end

-- A UI.Panel's housing, dressed in `look`, or in the theme's when nil (and again whenever that changes);
-- false: in none, as a piece standing inside another housing (a card docked in a deck).
-- A housing's own accent in place of the theme's, for what it means (a chat bubble's yell, in yell red): every part
-- of its look that wears your color wears this one instead, in every look (a galaxy's halo and glow, a grove's gems
-- and leaves, the matrix's phosphor, a leather's neon and stitching), and it is dressed again at once. A table
-- of r, g, b (kept: asking again for the same one changes nothing), or nil for the theme's again.
function UI.SetAccent(f, color)
	if f.shyAccentOf == color then return end
	f.shyAccentOf = color
	local accent = nil
	if type(color) == "table" then
		accent = function() return color[1], color[2], color[3] end
	end
	f.shyAccent = accent
	local h = f.shyLook
	if h then
		h.accent = accent
		UI.SetLook(f, f.shyLookFixed)
	end
end

function UI.SetLook(f, look)
	local h = f.shyLook
	if not h then return end
	f.shyLookFixed = look
	local function Dress()
		local wear = f.shyLookFixed
		if wear == nil then wear = Theme.Look() end
		-- (A header put away, UI.PanelHead, stays so: its gloss isn't shown again.)
		UI.LookDress(h, wear, { fill = f.shyBg, fitTo = h.fitTo, fitInset = h.fitInset, forged = h.forged, metal = f.shyMetal or Theme.skin.metal,
			gloss = not f.shyHeadless and f.shyGloss or nil, line = f.shyLine, strip = f.shyStrip })
		UI.PlaceBody(f)   -- its content clear of this look's work round the edge (UI.Body)
		-- (and its sheet inside this look's frame)
		local body = f.shyBody
		if body and body.shySheetOn then UI.BodySheet(f, true, body.shySheetIn) end
		UI.SetFill(f, f.shyFill)
		if f.shyStrip then
			-- The strip by look (UI.LookStrip), at the look's opacity as the fill is (a window's stays solid).
			local strip = f.shyStripColor
			-- Kept on the panel too: what its tabs' words stand on (UI.Tabs).
			f.shyStripFace = f.shyStripFace or function()
				local r, g, b, a = Color(strip)
				r, g, b, a = UI.LookStrip(h.look, r, g, b, h.solid and a or UI.LookAlpha(h.look, a))
				return r, g, b, a
			end
			Theme.Paint(f.shyStrip, f.shyStripFace)
			if f.shyGloss then
				f.shyGloss:SetShown(not f.shyHeadless and (select(5, UI.LookStrip(h.look, 0, 0, 0, 1))) or false)
				if not h.solid then Theme.Tint(f.shyGloss, function() return 1, 1, 1, UI.LookAlpha(h.look, (select(4, Color(strip)))) end) end
			end
		end
	end
	looked[f] = look == nil and Dress or nil
	Dress()
end

Shy:On("SHY_THEME", function()
	local look = Theme.Look()
	for f, dress in pairs(looked) do
		if f.shyLook.look ~= look or f.shyLook.stamp ~= Theme.LookStamp() then dress() else UI.LookRestore(f.shyLook) end
	end
end)

local FACET = 30   -- size of a bottom corner fold

function UI.Panel(f, opts)
	opts = opts or {}
	if not f.shyBg then
		-- Every region of the housing (not the content): the faded HUD's watch fades these alone.
		local house = {}
		f.shyHousing = house
		local function House(region)
			house[#house + 1] = region
			return region
		end
		-- A sample's own accent (a preset's card), worn by its brackets, its line and its look's parts: always a
		-- function, as Theme.Accent is (a look may call it).
		local accent = opts.accent
		if type(accent) == "table" then
			local c = accent
			accent = function() return c[1], c[2], c[3] end
		end
		f.shyAccent = accent
		-- Its own look options too (a preset's), read by its look through UI.LookOption.
		f.shyOptions = opts.options
		-- A piece on screen during play, and a window, wears the theme's look: its fill, strip and gloss stand a
		-- few sublevels up, leaving the shade and the halo room under them (BACKGROUND -8 and -7, the sky, sheen
		-- and foot -5 to -3). looks = false: an inner piece, none; looks = { to, inset }: fitted to that rect.
		local looks = opts.looks ~= false and (opts.hud or opts.cap or opts.look or opts.window or opts.looks) and true or false
		local forged = {}   -- the regions of the forged make alone
		f.shyBg = House(f:CreateTexture(nil, "BACKGROUND", nil, looks and -6 or -8))
		f.shyBg:SetAllPoints()
		f.shyEdge = House(f:CreateTexture(nil, "BORDER"))
		f.shyEdge:SetAllPoints()
		f.shyEdge:SetTexture(UI.EDGE)
		f.shyEdge:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
		forged[#forged + 1] = f.shyEdge
		local top = 2   -- the title strip starts inside the edge
		-- A console piece's `title` is its whole header height, so the strip is that less the edge.
		local strip = opts.title and (opts.cap and opts.title - top or opts.title)
		local brackets = opts.brackets
		if opts.cap then
			f.shyCap = {}   -- always empty: a header has no cap art over it
			-- A console piece has brackets only when it has a title.
			if brackets == nil then brackets = opts.title and UI.BRACKET_SIZE or false end
			local floor = 3
			if opts.cap == "both" then
				f.shyFoot = Cap(f, true)
				for _, t in ipairs(f.shyFoot) do
					House(t)
					forged[#forged + 1] = t
				end
				floor = UI.CAP_H - 1
			end
			if opts.facets ~= false then
				for i = 1, 2 do
					local t = House(f:CreateTexture(nil, "BACKGROUND", nil, looks and 0 or -5))
					t:SetTexture(UI.FACET)
					t:SetSize(FACET, FACET)
					if i == 1 then
						t:SetPoint("BOTTOMLEFT", 3, floor)
					else
						t:SetTexCoord(1, 0, 0, 1)
						t:SetPoint("BOTTOMRIGHT", -3, floor)
					end
					forged[#forged + 1] = t
				end
			end
		end
		if brackets ~= false then
			local size = UI.BRACKET_SIZE   -- always this size; a number in opts.brackets is ignored
			f.shyBrackets = {}
			for i, def in ipairs(BRACKETS) do
				local t = House(f:CreateTexture(nil, "BORDER", nil, 1))
				t:SetTexture(UI.BRACKET)
				t:SetTexCoord(def[2], def[3], def[4], def[5])
				t:SetSize(size, size)
				t:SetPoint(def[1])
				-- The bracket art is white, so it is tinted with the accent itself.
				Theme.Tint(t, UI.LookAccent(f))
				f.shyBrackets[i] = t
				forged[#forged + 1] = t
			end
		end
		if opts.title then
			f.shyStrip = House(f:CreateTexture(nil, "BACKGROUND", nil, looks and -2 or -7))
			f.shyStrip:SetPoint("TOPLEFT", 2, -top)
			f.shyStrip:SetPoint("TOPRIGHT", -2, -top)
			f.shyStrip:SetHeight(strip)
			f.shyStripColor = (opts.hud or opts.glazed) and C.hudStrip or C.bgHot
			Theme.Paint(f.shyStrip, f.shyStripColor)
			-- Its middle (UI.OnHead): a piece on screen keeps a console piece's lip, a window a window's (opts.lip: UI.Head's).
			f.shyHeadMid = UI.HeadMiddle(top, strip, opts.lip or ((opts.cap or opts.hud) and UI.HEAD.piece.lip or UI.HEAD.window.lip))
			local gloss = House(f:CreateTexture(nil, "BACKGROUND", nil, looks and -1 or -6))
			gloss:SetAllPoints(f.shyStrip)
			gloss:SetTexture(UI.GLOSS)
			f.shyGloss = gloss
			-- The gloss takes the strip's opacity.
			if opts.hud or opts.glazed then Theme.Tint(gloss, function() return 1, 1, 1, C.hudStrip[4] end) end
		end
		if opts.line ~= false then
			-- Under the title strip, or just inside the top edge without one.
			f.shyLine = House(UI.HeadLine(f))
			local y = strip and -(top + strip) or -top
			f.shyLine:SetPoint("TOPLEFT", 2, y)
			f.shyLine:SetPoint("TOPRIGHT", -2, y)
		end
		if looks then
			local fit = type(opts.looks) == "table" and opts.looks or nil
			f.shyLook = UI.LookBuild(f, fit and fit.to or f, fit and fit.inset or { 0, 0, 0, 0 }, function(_, region) House(region) end)
			f.shyLook.plate = true
			f.shyLook.mini = opts.mini == true   -- the look's mini border (its own simpler, smaller make: h.mini)
			-- A bar's housing (h.slim): long, and barely taller than a frame's corners. A look whose frame is sized by
			-- the piece keeps it whole on one while its corners fit at all (Heritage).
			f.shyLook.slim = opts.slim == true
			if strip then
				local lip = (opts.cap or opts.hud) and UI.HEAD.piece.lip or UI.HEAD.window.lip
				f.shyLook.headStripTop = top
				f.shyLook.headStripH = strip
				f.shyLook.headLine = top + strip
				f.shyLook.headTo = f
				f.shyLook.headY = UI.HeadMiddle(top, strip, lip)
			end
			f.shyLook.forged = forged
			f.shyLook.solid = not (opts.hud or opts.cap or opts.glazed)   -- a window keeps its solid fill in every look
			-- (`fill`: the fill's own inset in the panel's rect, when it goes with the look's: a housing standing past it.)
			if fit then f.shyLook.fitTo, f.shyLook.fitInset = f, fit.fill or { 0, 0, 0, 0 } end
			-- Its head (the zones, UI.LOOK_ZONES): its strip down to its line's foot; a look fitted elsewhere says its own.
			f.shyLook.zoneHead = (fit and fit.head) or (strip and not fit and top + strip + UI.LINE) or 0
		end
	end
	UI.SetFill(f, opts.fill or ((opts.hud or opts.glazed) and C.hud) or C.panel)
	UI.SetBorder(f, opts.border or Theme.skin.metal)
	if f.shyLook then UI.SetLook(f, opts.look or f.shyLookFixed) end
	return f
end

-- A look's card (the setup window's Theme page, the hub): a scene of dusk sky over dark ground with a
-- housing of that look standing in it, a row of cooldowns riding its top edge and two bars in it (the
-- vessel's silhouette, in the real art at true size), its name and its sentence under. The housing is a
-- UI.Panel in the look, so it carries the accent and the Background strength as the real ones do.
--   UI.LookCard(parent, width, look, { onClick(look), onEnter(look), onLeave(look), scene = height, accent = color })
--   (accent: a color or a function giving one, the card's own: a preset shown in its color while another is worn;
--   options: its look's options, the card's own, read through UI.LookOption)
--   card:Paint(on, inUse)   lit when picked; "in use" at its corner for the look the theme wears
-- The theme cards' scene: its world's colors, and the pieces standing in it.
local STAGE = {
	sky = { 0.20, 0.26, 0.36 },
	haze = { 0.44, 0.40, 0.36 },
	ground = { 0.17, 0.17, 0.13 },
	deep = { 0.07, 0.07, 0.065 },
	health = { 0.17, 0.76, 0.31 },
	pieceH = 38,
	tile = 16,
	tiles = 4,
}
-- The scene's colors, for whoever draws a housing standing in the same world (the theme chooser's preview).
UI.SCENE = { sky = STAGE.sky, haze = STAGE.haze, ground = STAGE.ground, deep = STAGE.deep, health = STAGE.health }

function UI.LookCard(parent, width, look, opts)
	opts = opts or {}
	local sceneH = opts.scene or 96
	local card = CreateFrame("Button", nil, parent)
	-- Its sentence under the name, or on a narrow card its few words on one line (opts.short).
	card:SetSize(width, sceneH + (opts.short and 44 or 64))
	UI.Skin(card)
	card.look = look
	card.glow = card:CreateTexture(nil, "BORDER", nil, -1)
	card.glow:SetTexture(Shy.MEDIA .. "Glow")
	card.glow:SetTextureSliceMargins(24, 24, 24, 24)
	card.glow:SetPoint("TOPLEFT", -3, 3)
	card.glow:SetPoint("BOTTOMRIGHT", 3, -3)
	Theme.Tint(card.glow, C.hot, 0.6)
	card.glow:Hide()

	-- The scene: sky to a hazy horizon, then the ground falling dark; the world the housing stands over.
	local scene = CreateFrame("Frame", nil, card)
	scene:SetPoint("TOPLEFT", 1, -1)
	scene:SetPoint("TOPRIGHT", -1, -1)
	scene:SetHeight(sceneH)
	scene:SetClipsChildren(true)
	local sky = scene:CreateTexture(nil, "BACKGROUND")
	sky:SetColorTexture(1, 1, 1, 1)
	sky:SetGradient("VERTICAL", CreateColor(STAGE.haze[1], STAGE.haze[2], STAGE.haze[3], 1), CreateColor(STAGE.sky[1], STAGE.sky[2], STAGE.sky[3], 1))
	sky:SetPoint("TOPLEFT")
	sky:SetPoint("TOPRIGHT")
	sky:SetHeight(sceneH * 0.56)
	local ground = scene:CreateTexture(nil, "BACKGROUND")
	ground:SetColorTexture(1, 1, 1, 1)
	ground:SetGradient("VERTICAL", CreateColor(STAGE.deep[1], STAGE.deep[2], STAGE.deep[3], 1), CreateColor(STAGE.ground[1], STAGE.ground[2], STAGE.ground[3], 1))
	ground:SetPoint("TOPLEFT", sky, "BOTTOMLEFT")
	ground:SetPoint("BOTTOMRIGHT")
	card.scene = scene
	-- The card's hairline stands over the scene and everything in it: under them, the scene (a frame, a unit in)
	-- covered its edge wherever that unit lands between two pixels.
	local rim = CreateFrame("Frame", nil, card)
	rim:SetAllPoints()
	rim:SetFrameLevel(card:GetFrameLevel() + 20)
	for _, edge in ipairs(card.shyEdges) do edge:SetParent(rim) end

	-- The housing, a little under the scene's middle, with the row of cooldowns riding its top edge.
	local piece = CreateFrame("Frame", nil, scene)
	local pieceW = max(60, width - 2 - 2 * 24)
	piece:SetSize(pieceW, STAGE.pieceH)
	piece:SetPoint("CENTER", 0, -(STAGE.tile / 2) + 2)
	UI.Panel(piece, { cap = true, facets = false, line = false, brackets = 10, hud = true, look = look, accent = opts.accent, options = opts.options })
	card.piece = piece
	local tiles = CreateFrame("Frame", nil, piece)
	tiles:SetFrameLevel(piece:GetFrameLevel() + 2)
	tiles:SetSize(STAGE.tiles * (STAGE.tile + 2) - 2, STAGE.tile)
	tiles:SetPoint("TOP", piece, "TOP", 0, STAGE.tile / 2)
	-- Real slots, in the card's look: they wear the finish the look gives (card:SetSlots(key) another: the one picked).
	card.tiles = {}
	for i = 1, STAGE.tiles do
		local tile = CreateFrame("Frame", nil, tiles)
		tile:SetSize(STAGE.tile, STAGE.tile)
		tile:SetPoint("LEFT", (i - 1) * (STAGE.tile + 2), 0)
		card.tiles[i] = Shy.Slot.New(tile, { look = look, size = STAGE.tile, hover = false })
	end
	function card:SetSlots(key)
		for _, slot in ipairs(self.tiles) do slot:Set({ look = self.look, style = key, size = STAGE.tile, hover = false }) end
	end
	-- Two bars in the housing, in its block: health, then power in your color, filled as the look's bars are
	-- (card:SetBar(file) fills them with another design: the one picked).
	card.fills = {}
	local function Bar(y, h, color)
		local track = piece:CreateTexture(nil, "ARTWORK")
		track:SetPoint("TOPLEFT", 8, -y)
		track:SetPoint("TOPRIGHT", -8, -y)
		track:SetHeight(h)
		track:SetColorTexture(0.02, 0.02, 0.025, 1)
		local fill = piece:CreateTexture(nil, "ARTWORK", nil, 1)
		fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
		fill:SetWidth((pieceW - 18) * 0.72)
		Theme.Tint(fill, color)
		card.fills[#card.fills + 1] = fill
	end
	Bar(STAGE.tile / 2 + 5, 9, STAGE.health)
	Bar(STAGE.tile / 2 + 16, 6, opts.accent or Theme.Accent)
	function card:SetBar(file)
		for _, fill in ipairs(self.fills) do
			fill:SetTexture(file, "REPEAT", "CLAMP")
			fill:SetHorizTile(true)
		end
	end
	card:SetBar(Shy.Skin and Shy.Skin.HatchFor(look) or Shy.MEDIA .. "Bar")

	card.name = UI.Text(card, UI.LOOK_NAMES[look], 15, true)
	card.name:SetPoint("TOPLEFT", 10, -sceneH - 8)
	card.used = UI.Text(card, "in use", 10, true, C.good)
	card.used:SetPoint("TOPRIGHT", -10, -sceneH - 10)
	card.words = UI.Text(card, opts.short and UI.LOOK_SHORT[look] or UI.LOOK_WORDS[look], 11, false, C.dim)
	card.words:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
	card.words:SetWidth(width - 20)
	card.words:SetWordWrap(not opts.short)
	card.words:SetJustifyH("LEFT")

	function card:Paint(on, inUse)
		self.on = on
		self.used:SetShown(inUse and true or false)
		UI.SetFill(self, on and C.row or C.bg)
		UI.SetBorder(self, (on or self.hover) and C.hot or C.border)
		UI.Ink(self.name, on and C.head or C.text)
		self.glow:SetShown(on and true or false)
	end
	card:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if opts.onClick then opts.onClick(self.look) end
	end)
	card:SetScript("OnEnter", function(self)
		self.hover = true
		UI.SetBorder(self, C.hot)
		if opts.onEnter then opts.onEnter(self.look) end
	end)
	card:SetScript("OnLeave", function(self)
		self.hover = false
		UI.SetBorder(self, self.on and C.hot or C.border)
		if opts.onLeave then opts.onLeave(self.look) end
	end)
	return card
end

-- Shy's own words, the one way they are made: every string of ours on the screen comes from UI.Text or UI.Words (or
-- is a slot's count, Slot:Count, or a game window's own text the skin dresses), so it wears the text effect and
-- reads on any look's ground.
--   UI.Text(parent, text, size, brand, color)   brand: the theme's title font (Theme.Face); else the game's plain one
--   UI.Words(parent, font, color, opts)         any font object: UI.NameFont (names, figures, every alphabet),
--                                               UI.TextFont (running text), UI.TitleFont (kept in the theme's font);
--                                               or a number: the rounded face at that very size (10.5 too), for
--                                               figures and marks of our own (Latin only)
--       opts.layer ("OVERLAY"), opts.justify ("LEFT"), opts.wrap (false: one line)
--       opts.world: words over the world, a bar or the map, not on a housing (a nameplate's, a buff's count, a map
--                   pin's name): the font object brings its outline ("OUTLINE"), a fine shadow under it, no look's
--                   effect, and no ink unless `color` is given (their owner colors them as they change)
-- Words on a face of their own color (a button, a caption, a paper) are inked for it: UI.FaceInk, UI.Letter.
function UI.Text(parent, text, size, brand, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if brand then Theme.Face(fs, size or 14)   -- Shy's own words: the theme's font, following it
	elseif size then fs:SetFont((GameFontHighlight:GetFont()), size, "") end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	if not brand then Theme.Wear(fs) end
	Theme.Ink(fs, color or C.text)
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	return fs
end

local WORLD_SHADOW = 0.8   -- under outlined words over the world: a fine shadow, so the outline isn't doubled

function UI.Words(parent, font, color, opts)
	opts = opts or {}
	local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
	if type(font) == "number" then fs:SetFont(Shy.FONT_ROUNDED, font, "") else fs:SetFontObject(font) end
	fs:SetJustifyH(opts.justify or "LEFT")
	if opts.wrap == false then fs:SetWordWrap(false) end
	if opts.world then
		fs:SetShadowOffset(WORLD_SHADOW, -WORLD_SHADOW)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		UI.Follow(fs)   -- a title keeps up with the theme's font
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
		Theme.Wear(fs)
	end
	-- (After the font: a font object brings its own color. Words over the world are colored by their owner as they
	-- change, unless a color is given.)
	if color or not opts.world then UI.Ink(fs, color or C.text) end
	return fs
end

-- A price as typed: "1g 20s 5c", "1g20s", "20s", "1.5g"; a bare number is copper. nil for anything else.
local COIN_UNIT = { g = 10000, s = 100, c = 1 }
function UI.ParseMoney(text)
	text = strtrim((text or ""):lower())
	if text == "" then return nil end
	local bare = tonumber(text)
	if bare then return bare >= 0 and math.floor(bare + 0.5) or nil end
	local copper, rest = 0, text:gsub("%s+", "")
	for amount, unit in rest:gmatch("(%d*%.?%d+)([gsc])") do
		copper = copper + tonumber(amount) * COIN_UNIT[unit]
	end
	-- (Every letter must have been a part of a coin: "12x" or "g" alone is no price.)
	if rest:gsub("%d*%.?%d+[gsc]", "") ~= "" then return nil end
	return math.floor(copper + 0.5)
end

-- How long ago a time (time()'s seconds) was, in words: "just now", "40 min ago", "3 h ago", "2 days ago". nil for none.
function UI.Ago(at)
	if not at then return nil end
	local seconds = time() - at
	if seconds < 120 then return "just now" end
	if seconds < 3600 then return ("%d min ago"):format(math.floor(seconds / 60)) end
	if seconds < 2 * 86400 then return ("%d h ago"):format(math.floor(seconds / 3600)) end
	return ("%d days ago"):format(math.floor(seconds / 86400))
end

-- Money with coin icons. short: drop silver and copper from 100 gold up. size: the size of the text it stands in
-- (12 unless told). at: the font string it is set on, when the caller has it (see UI.MoneyFit).
function UI.Money(copper, short, size, at)
	if short and copper >= 100 * COPPER_PER_GOLD then copper = copper - copper % COPPER_PER_GOLD end
	return UI.MoneyFit(C_CurrencyInfo.GetCoinTextureString(copper, size), at, size)
end

-- Every coin in a text as tall as the digits beside it and level with them, for the font string it is set on.
-- How the game sets a picture in a line of text (measured, with squares of known size in each kind of text):
--   its size is in twelfths of the text's own size, whatever that is: 12 is as tall as the text is large;
--   its offsets are screen pixels, whatever the scale, and a positive one is up;
--   it stands on the middle of the line, which in the name and text fonts is under the middle of the capitals
--   (COIN.lift of the text's size), and in the title fonts and the game's font is on it;
--   a font string's line spacing raises it by that much; whether the text wraps makes no difference.
-- So a coin is COIN.tall twelfths (its disc as tall as a capital), raised by the lift and lowered by the spacing, in
-- the pixels of where it stands.
--   UI.MoneyFit(text, at, size)   at: the font string (its font, size, spacing and scale are read); with none, the
--                                 name or text font at `size` (12), no spacing, the screen's own scale
-- A text with no coins of the game's in it comes back as it is.
UI.COIN = { tall = 10, lift = 0.075 }
function UI.MoneyFit(text, at, size)
	if issecretvalue(text) or type(text) ~= "string" or not text:find("|TInterface\\MoneyFrame\\UI-", 1, true) then return text end
	local COIN = UI.COIN
	local lift, spacing, scale = COIN.lift, 0, UIParent:GetEffectiveScale()
	size = size or 12
	if at then
		local file, tall = at:GetFont()
		if type(file) == "string" and not issecretvalue(file) and not file:find("Nunito", 1, true) then lift = 0 end
		if type(tall) == "number" and not issecretvalue(tall) and tall > 0 then size = tall end
		local apart, here = at:GetSpacing(), at:GetEffectiveScale()
		if type(apart) == "number" and not issecretvalue(apart) then spacing = apart end
		if type(here) == "number" and not issecretvalue(here) and here > 0 then scale = here end
	end
	if type(scale) ~= "number" or issecretvalue(scale) then scale = 1 end
	local up = floor((lift * size - spacing) * scale / PixelUtil.GetPixelToUIUnitFactor() + 0.5)
	return (text:gsub("(|TInterface\\MoneyFrame\\UI%-%a+Icon):%d+:%d+:(%-?%d+):%-?%d+|t", "%1:" .. COIN.tall .. ":" .. COIN.tall .. ":%2:" .. up .. "|t"))
end

-- Player-made text (names, guilds, chat) can be in any alphabet and the display font is Latin only.
-- UI.NameFont returns a font family: the rounded font for Latin, Cyrillic, Greek, Thai, symbols and
-- emoji (the game falls back between files only per alphabet, so all of that is inside the one file),
-- Blizzard's own for Korean and Chinese (GameFonts.xml). One family per look, size and flags, created once.
--   fs:SetFontObject(UI.NameFont(13))
--   UI.NameFont(size, "OUTLINE", { roman = file, russian = file }, "lookName")
local NAME_FILES = { roman = Shy.FONT_ROUNDED, russian = Shy.FONT_ROUNDED }
local ASIAN_FILES = {
	korean = "Fonts\\2002.TTF",
	simplifiedchinese = "Fonts\\ARKai_T.ttf",
	traditionalchinese = "Fonts\\blei00d.TTF",
}
local families = {}

function UI.NameFont(size, flags, files, look)
	flags = flags or ""
	local id = ("ShyNames_%s_%d_%s"):format(look or "shy", size, (flags:gsub("%A", "")))
	if not families[id] then
		local members = {}
		for alphabet, file in pairs(files or NAME_FILES) do
			members[#members + 1] = { alphabet = alphabet, file = file, height = size, flags = flags }
		end
		for alphabet, file in pairs(ASIAN_FILES) do
			if not (files and files[alphabet]) then
				members[#members + 1] = { alphabet = alphabet, file = file, height = size, flags = flags }
			end
		end
		families[id] = CreateFontFamily(id, members)
	end
	return families[id]
end

-- Running text (chat lines): two weights of the text font, the heavier one under size 16, with the
-- Korean and Chinese fonts of Blizzard's chat (NumberFont_Shadow_Med).
--   fs:SetFontObject(UI.TextFont(12))
local function TextFiles(file)
	return {
		roman = file, russian = file,
		korean = "Fonts\\2002.TTF",
		simplifiedchinese = "Fonts\\ARHei.ttf",
		traditionalchinese = "Fonts\\arheiuhk_bd.TTF",
	}
end
local TEXT_FILES, TEXT_LARGE_FILES = TextFiles(Shy.FONT_TEXT), TextFiles(Shy.FONT_TEXT_LARGE)

function UI.TextFont(size, flags)
	return UI.NameFont(size, flags, size < 16 and TEXT_FILES or TEXT_LARGE_FILES, "text")
end

-- Headers that show localized game text (a chat tab's name, the zone, a tracker section): the theme's font for
-- Latin (Theme.FONTS), its Cyrillic file or the rounded font for Cyrillic, Blizzard's for Korean and Chinese.
-- `key`: a Theme.FONTS key instead of the font on screen (a sample).
--   UI.TitleFace(fs, 12)                -- the font set and kept in the theme's (Theme.Face): use this
--   UI.Follow(fs)                       -- a string given UI.TitleFont's object another way keeps up (Theme.Follow)
--   fs:SetFontObject(UI.TitleFont(12))  -- the font on screen now, not kept up: call UI.Follow(fs) after
UI.TITLE_SIZE = UI.HEAD.piece.text   -- header text size on a console piece
local madeTitle = {}   -- each title font object -> { size, flags } (UI.TitleFontMade)

-- How far to raise words of `size` centred on something so their capitals stand on its middle: their face's ink
-- (Theme.FONTS' `ink`; names and numbers are Nunito ExtraBold's, NAME_INK) and half their unit of drop shadow, which
-- weighs them down. UI.TitleLift for the theme's font, UI.NameLift for names and numbers.
local NAME_INK, SHADOW_LIFT = -0.021, 0.5   -- Nunito ExtraBold: (1.011 - 0.714 / 2) / 1.364 - 0.5
function UI.TitleLift(size)
	return size * Theme.FontInk(size) + SHADOW_LIFT
end
function UI.NameLift(size)
	return size * NAME_INK + SHADOW_LIFT
end

function UI.TitleFont(size, flags, key)
	size = size or UI.TITLE_SIZE
	local files, font = Theme.FontFiles(key, size)   -- a face that cramps small hands small words to its pair
	local object = UI.NameFont(size, flags, files, font == Theme.FONT and "title" or "title-" .. font)
	madeTitle[object] = madeTitle[object] or { size = size, flags = flags }
	return object
end

-- The size and flags a title font object was made at, or nil for any other object.
function UI.TitleFontMade(object)
	return object and madeTitle[object]
end

UI.TitleFace, UI.Follow, UI.Letter = Theme.Face, Theme.Follow, Theme.Letter   -- (UI.Letter: the text effect)

-- A header's words (a title, a tab's name): the title font, shadowed as UI.Text's, in the head's ink unless told.
-- Every header's words are made with this, at its UI.HEAD size, so they read the same wherever they stand.
--   UI.TitleText(parent, "Find", UI.HEAD.window.text)
-- A header's words in the theme's look: the core's ink, or a look kind's lettering (UI.LookKind's `title`).
do
	local titled = setmetatable({}, { __mode = "k" })   -- font string -> { size, color, kind dressed in }
	local function Letter(fs)
		local t = titled[fs]
		local kind = KINDS[Theme.Look()]
		local want = kind and kind.title and Theme.Look() or nil
		if t.kind == want then return end
		if t.kind and KINDS[t.kind] then KINDS[t.kind].title(fs, false) end
		Theme.Face(fs, t.size)
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
		Theme.Ink(fs, t.color)
		t.kind = want
		if want then kind.title(fs, true) end
	end
	Shy:On("SHY_THEME", function()
		for fs in pairs(titled) do Letter(fs) end
	end)

	function UI.TitleText(parent, text, size, color)
		local fs = parent:CreateFontString(nil, "OVERLAY")
		titled[fs] = { size = size, color = color or C.head }
		Theme.Face(fs, size)
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
		Theme.Ink(fs, color or C.head)
		fs:SetText(text or "")
		fs:SetJustifyH("LEFT")
		Letter(fs)
		return fs
	end
end

-- Hover text for an addon's own content (Hover.lua documents `opts`). GameTooltip is only for what
-- the game describes (items, spells, units).
--   UI.Tip(owner, "Sort", "Puts the cheapest things first.")
--   local lines = UI.Lines(); lines:AddLine(name); lines:AddDoubleLine("Sold", "12"); UI.Tip(owner, lines)
--   UI.TipHide(owner[, now])       -- now: skip the short grace period
--   UI.Help(frame, title, text)    -- shows on enter, hides on leave; title and text may be functions
-- A player's PvP flag as the crest it wears, the game's own (its player frame's): free for all, else their faction's
-- while they are flagged. nil for anyone else, anyone not flagged, or what the game keeps secret. Wherever a unit's
-- name stands (a nameplate, a tooltip's plate) the crest stands before it, so a flag is seen at a glance.
--   UI.PvPCrest(unit) -> "Alliance" | "Horde" | "FFA" | nil
--   UI.Crest(texture, crest, tall[, tpu]) -> width, height   -- shows it on the texture, `tall` high; hides it for nil
-- The game's art is drawn for a player frame and has no smaller copies; before a name a crest is a few pixels, so
-- the family's are drawn for the heights they are shown at (CREST.sizes), at two texels a unit and, for a nameplate
-- or a HUD with a unit on a pixel (`tpu` under 2: UI.TexelsFor), at a nameplate's (CREST.texels). `shape` is each
-- one's width, of its height; a picture is a whole number of texels each way, so its size is worked out from those.
local CREST = { shape = { Alliance = 0.840, Horde = 0.840, FFA = 0.622 },
	sizes = { { 15, 16 }, { 16 } }, texels = { 1.5, 2 }, made = { {}, {} } }
function UI.PvPCrest(unit)
	local player = UnitIsPlayer(unit)
	if issecretvalue(player) or not player then return nil end
	local ffa = UnitIsPVPFreeForAll(unit)
	if issecretvalue(ffa) then return nil end
	if ffa then return "FFA" end
	local flagged = UnitIsPVP(unit)
	if issecretvalue(flagged) or not flagged then return nil end
	local faction = UnitFactionGroup(unit)
	if issecretvalue(faction) or not CREST.shape[faction] then return nil end
	return faction
end

function UI.Crest(texture, crest, tall, tpu)
	local shape = crest and CREST.shape[crest]
	texture:SetShown(shape ~= nil)
	if not shape then return 0, 0 end
	local fine = (tpu or 2) < 2 and 1 or 2
	local made = CREST.made[fine][crest]
	if not made then
		made = {}
		CREST.made[fine][crest] = made
	end
	local art = made[tall]
	if not art then
		local best
		for _, drawn in ipairs(CREST.sizes[fine]) do
			if not best or math.abs(drawn - tall) < math.abs(best - tall) then best = drawn end
		end
		local texels = CREST.texels[fine]
		art = { file = Shy.MEDIA .. "Crest" .. crest .. best .. (fine == 1 and "Plate" or ""),
			wide = math.ceil(shape * best * texels) / texels * tall / best,
			tall = math.ceil(best * texels) / texels * tall / best }
		made[tall] = art
	end
	texture:SetTexture(art.file)
	texture:SetSize(art.wide, art.tall)
	return art.wide, art.tall
end

-- A unit's rank, as its dragon frames it: "boss", "rareelite", "elite", "rare", or nil (none, or secret).
function UI.UnitRank(unit)
	local boss = UnitIsBossMob(unit)
	if not issecretvalue(boss) and boss then return "boss" end
	local kind = UnitClassification(unit)
	if issecretvalue(kind) then return nil end
	if kind == "worldboss" then return "boss" end
	if kind == "rareelite" or kind == "elite" or kind == "rare" then return kind end
	return nil
end

-- The rank's dragon round a circle `size` across (UI.UnitRank's rank): the game's own target frame dragons (gold an
-- elite's, silver a rare's, winged a rare elite's and a boss's), drawn for the family's circles at the sizes they are
-- shown (DRAGON.sizes, at two texels a unit, or a texel a unit for a nameplate), curled round
-- the circle's left. -> { file, span } (a square `span` across on the circle's middle), or nil.
-- (Each answer is worked out once and kept: the same list for the same rank, size and density, not to be written to.)
local DRAGON = { reach = 1.060, sizes = { [1] = { 33, 25, 20 }, [2] = { 33 } },
	kinds = { boss = "Boss", rareelite = "RareElite", elite = "Elite", rare = "Rare" }, made = { {}, {} } }
function UI.RankDragon(rank, size, tpu)
	local kind = rank and DRAGON.kinds[rank]
	if not kind then return nil end
	local texels = (tpu or 2) < 2 and 1 or 2
	local made = DRAGON.made[texels][kind]
	if not made then
		made = {}
		DRAGON.made[texels][kind] = made
	end
	local art = made[size]
	if not art then
		local plate = texels == 1
		local best
		for _, drawn in ipairs(DRAGON.sizes[texels]) do
			if not best or math.abs(drawn - size) < math.abs(best - size) then best = drawn end
		end
		local span = math.ceil(2 * DRAGON.reach * best * texels) / texels * size / best
		art = { file = Shy.MEDIA .. "Dragon" .. kind .. best .. (plate and "Plate" or ""), span = span }
		made[size] = art
	end
	return art
end

-- The texels a unit to draw a picture at for where `region` stands (1 or 2): the screen's pixels a unit there, the
-- nearer. An addon's picture has no smaller copies, so one drawn finer than it is shown is sampled a texel here and
-- there; the family's art comes at two (the HUD at a UI scale near 1) and, where it matters, at one (a nameplate, or
-- the HUD at a UI scale that puts a unit on a pixel: 1440 high with the game's UI scale off). Two when it can't be told.
function UI.TexelsFor(region)
	local scale = region and region:GetEffectiveScale()
	local _, height = GetPhysicalScreenSize()
	if not scale or issecretvalue(scale) or not height or height <= 0 then return 2 end
	return scale * height / 768 < 1.5 and 1 or 2
end

function UI.Tip(owner, title, text, opts)
	if type(title) == "table" then return Shy.Hover.ShowLines(owner, title, text) end
	return Shy.Hover.Tip(owner, title, text, opts)
end

function UI.TipHide(owner, now)
	Shy.Hover.Hide(owner, now)
end

-- Where a hover over a piece of a window stands: past the window's edge, level with the piece, so it never covers
-- what the window shows. On the side asked for (opts.side, "RIGHT" by default) where the screen has room for it, else
-- on the other.
--   Shy.Hover.Show(piece, content, { at = UI.Beside(window, piece) })
-- opts.room: the width the hover wants (280); opts.reach: what stands out past the window's right edge (side tabs);
-- opts.tip: the frame shown, when its scale is its own (offsets are in its units); opts.up: for a piece in the
-- window's foot, the hover stands up from the piece's bottom edge (never hanging under the window).
function UI.Beside(window, piece, opts)
	opts = opts or {}
	local scale = window:GetEffectiveScale()
	local right = (window:GetRight() or 0) + (opts.reach or 0)
	local unit = scale / (opts.tip or UIParent):GetEffectiveScale()
	local toScreen = scale / UIParent:GetEffectiveScale()
	local room = opts.room or 280
	local onRight
	if opts.side == "LEFT" then
		onRight = (window:GetLeft() or 0) * toScreen < room
	else
		onRight = (UIParent:GetWidth() or 0) - right * toScreen >= room
	end
	local edge, y = opts.up and "BOTTOM" or "TOP", opts.up and -2 or 2
	if onRight then
		return { edge .. "LEFT", piece, edge .. "RIGHT", (right - (piece:GetRight() or 0)) * unit + 6, y }
	end
	return { edge .. "RIGHT", piece, edge .. "LEFT", -((piece:GetLeft() or 0) - (window:GetLeft() or 0)) * unit - 6, y }
end

-- The game's tooltip for a piece of a window with a picture (a row, a card, a slot): owned by the piece, its bottom
-- left corner on the picture's top right one, the same place in every window. With no room for it past there on
-- the screen (GAME_TIP_ROOM), it stands off the top left corner instead: the game would push it back over the piece.
--   UI.GameTipAt(row, row.icon):SetItemByID(id)
-- icon: the picture, where it is not the whole piece. A row whose words begin at its top (a line of a close
-- list) passes none: the tooltip stands off the row's own corner, clear of it both ways.
local GAME_TIP_ROOM = 300
function UI.GameTipAt(piece, icon)
	local at = icon or piece
	GameTooltip:SetOwner(piece, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	local right, scale = at:GetRight(), at:GetEffectiveScale()
	if right and scale and (UIParent:GetWidth() or 0) - right * scale / UIParent:GetEffectiveScale() < GAME_TIP_ROOM then
		GameTooltip:SetPoint("BOTTOMRIGHT", at, "TOPLEFT", 0, 0)
	else
		GameTooltip:SetPoint("BOTTOMLEFT", at, "TOPRIGHT", 0, 0)
	end
	return GameTooltip
end

function UI.Lines()
	return Shy.Hover.Lines()
end

function UI.Help(frame, title, text, opts)
	Shy.Hover.Attach(frame, title, text, opts)
end

local function AttachHelp(frame, label, opts)
	if not (opts and opts.desc) then return end
	frame:HookScript("OnEnter", function(self) UI.Tip(self, label, opts.desc) end)
	frame:HookScript("OnLeave", function(self) UI.TipHide(self) end)
end

local function IsEnabled(opts) return not (opts and opts.enabled) or opts.enabled() end

local function SetDimmed(frame, dimmed)
	frame:SetAlpha(dimmed and 0.4 or 1)
	frame.dimmed = dimmed
end

function UI.Header(parent, text, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width or 260, 22)
	local fs = UI.Text(f, text, 16, true, C.head)
	fs:SetPoint("TOPLEFT")
	local accent = UI.HeadLine(f)
	accent:SetWidth(36)
	accent:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
	local rule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.7)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", accent, "RIGHT", 0, 0)
	rule:SetPoint("RIGHT", f, "RIGHT")
	return f
end

-- A page's heading, the same over every page of a window: what the page asks or is, in the theme's font over
-- a stub of the accent and a rule, and one quiet sentence under it.
--   local lead = UI.Lead(parent, width)   lead:Set(ask, sentence)   -- UI.LEAD_H: its height, down to the page
UI.LEAD_H = 44

function UI.Lead(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, UI.LEAD_H)
	f.ask = UI.Text(f, "", 15, true, C.head)
	f.ask:SetPoint("TOPLEFT")
	local accent = B.CreateLine(f, 36, 2, 12, true)
	accent:SetPoint("TOPLEFT", f.ask, "BOTTOMLEFT", 0, -3)
	local rule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.7)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", accent, "RIGHT", 0, 0)
	rule:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	rule:SetPoint("TOP", accent, "TOP", 0, 0)
	f.words = UI.Text(f, "", 12, false, C.dim)
	f.words:SetPoint("TOPLEFT", f.ask, "BOTTOMLEFT", 0, -12)
	f.words:SetWidth(width)
	f.words:SetWordWrap(false)
	function f:Set(ask, words)
		self.ask:SetText(ask or "")
		self.words:SetText(words or "")
	end
	return f
end

-- Buttons
--
-- The keyed piece: a face in the piece's slightly rounded shape and a thin edge over it, all grey art tinted
-- from the theme, so the accent runs through it and a change of look or color repaints it. Every look has its
-- own make of it (UI.KEY_MAKES, "The makes" below): its edge, its finish and what it wears on top, each state
-- shown its own way; the sizes, where the words stand and the states themselves are the same in every look (no
-- look moves a thing), and a change of look dresses every button again at once.
--   UI.Keyed(frame)                    -- the piece on any frame: .fill, .gloss, .edge, .light (unlit)
--   UI.KeyMarks(frame, lit, down, primary, rim, now)   -- its edge and the look's marks for a state (a key of
--                                      -- Talk's paints the rest itself); rim: the edge's color at rest (metal)
--   UI.KEY_MAKES[look] = make, UI.KeyMake(look)   -- a look's make (a look naming none wears the forged one)
--   UI.KeyPress(button, opts)          -- the make and every state on a button of your own (see there)
--   UI.ButtonFace(button, text, fill)  -- the same with words in the middle (a secure button: Finish, Reload)
--   UI.Button(parent, text, width, onClick)
--     b:SetPrimary(on)   b:SetUsable(on, why)   b:SetLabel(text)   b:SetOn(on)   b:SetTone(color)
--   UI.GlyphButton(parent, glyph, size, onClick, opts), UI.Close: a glyph in the make
--   UI.MenuButton with plate = true, UI.Dropdown: the make with words and a caret
-- UI.Press is the quiet one beside these: no plate until hovered (toolbar glyphs, rows).
-- Malleable: any size (the corners shrink to fit a small piece), plated or bare, words, a glyph or both, a
-- meaning tone, on, primary. At rest a face toned by the look in the look's edge. Under the mouse the edge
-- goes hot (or the look lights it its own way), a wash of the accent comes over the face, light rises along
-- its top and the words brighten; held, the face darkens, is pushed below its edge and the words sink a unit.
-- The primary (fill C.fill) is the accent's deep shade in the hot edge with light along its top. UI.SetFill
-- and UI.SetBorder on a button pick its fill and its edge as on any control, and it keeps its make: C.hot
-- lights it as under the mouse, whoever's hover asks.
UI.KEY_FACE, UI.KEY_EDGE, UI.KEY_SLICE = Shy.MEDIA .. "TalkFace", Shy.MEDIA .. "TalkButton", 6
UI.LIGHT = Shy.MEDIA .. "HoverLight"   -- light along a lit piece's top, added
-- A press (the face pushed below its edge), the eclipse's light round a button, a forged button's bracket.
UI.KEY_INSET, UI.KEY_HALO, UI.KEY_BRACKET = Shy.MEDIA .. "KeyInset", Shy.MEDIA .. "KeyHalo", Shy.MEDIA .. "KeyBracket"

-- The makes, by look. A make's fields, all but `edge` left out when not worn:
--   edge = { file, slice }     the edge's nine slice, a texel a unit
--   rim                        its color at rest: "metal" (the control's edge, toned by the look), "white", "dark"
--   hot                        it goes hot while lit, and on the primary
--   gloss                      a gloss on the face's upper half (true: the family's; a number: that strong)
--   rest                       light along its top at rest (Glass: the light in its top edge)
--   lean = { r, g, b, k }      the face leans this far to that color (Glass a cool pane, Frosted frost, Riveted steel)
--   clear                      the face this opaque, the scene behind it showing through (Glass)
--   grain / brushed / frost    a texture over the face: the hide's grain at `grain` (or, with `face`, the file
--                              face() names, at `grain`); brushed steel and its sheen; frost at `frost`
--   foot                       a darker band along its foot, this dark (a steel plate's)
--   halo                       the light getting round it while lit (softer on the primary)
--   trim                       "bracket": brackets at its corners, in the hot color while lit (dim in the steel at
--                              rest, at `bracketRest`, when given); "rivet": a small rivet in each corner of a piece
--                              big enough for them
--   hover = { color, lift, light, sheen, halo }   its own hover (UI.KeyHover; eased in and out): a wash of color over
--                              the face at lift, the light along its top to light, the sheen and the halo to theirs
--   lift                       how dark the shadow under a glyph on it is (UI.KeyLift; 0.6 when none given)
--   prime, dye                 how the primary wears your color: the accent's fill (none given), "dye" the face
--                              steeped in it (`dye` of it), "light" the face as at rest with your color as light in it,
--                              "halo" the face as at rest in the light round it at full; its words then read on it
--   build(frame), mark(frame, lit, down, primary)   a look's own pieces: build makes them once on a piece the
--                              first time it wears the make and returns them (a list; put away whenever the piece
--                              wears another make); mark shows them for its state (lit, held: false on a bare piece
--                              at rest). A press (the face below its edge) and the words sinking come with every make
--   own                        its own pieces are its face and edge (the game's own button art): ours are put away,
--                              the press with them (its mark shows its own)
UI.KEY_MAKES = {
	-- Forged: its brackets light, the bevel goes hot and catches the light along its top.
	forged   = { edge = { UI.KEY_EDGE, UI.KEY_SLICE }, rim = "metal", hot = true, gloss = true, trim = "bracket", bracketRest = 0.5,
		hover = { color = { 1, 1, 1 }, lift = 0.06, light = 0.45 } },
	-- Glass: the pane brightens and its top edge flares.
	steel    = { edge = { LOOK.EDGE, LOOK.EDGE_SLICE }, rim = "metal", hot = true, gloss = 0.4, rest = 0.8,
		lean = { 0.62, 0.70, 0.86, 0.22 }, clear = 0.55, prime = "light", lift = 0.9,
		hover = { color = { 0.85, 0.92, 1 }, lift = 0.12, light = 1 } },
	-- Frosted: the frost lifts toward white.
	clear    = { edge = { LOOK.PANE, LOOK.EDGE_SLICE }, rim = "white", hot = true, frost = 0.3,
		lean = { 0.80, 0.82, 0.86, 0.38 }, prime = "dye", dye = 0.45, lift = 0.9,
		hover = { color = { 1, 1, 1 }, lift = 0.2, light = 0.3 } },
	-- Eclipse: the light in your color comes up round the slab; the slab itself stays dark.
	eclipse  = { edge = { LOOK.PANE, LOOK.EDGE_SLICE }, rim = "dark", halo = true, prime = "halo",
		hover = { lift = 0, light = 0, halo = 0.65 } },
	-- Riveted: the sheen comes up across the brushed face.
	riveted  = { edge = { LOOK.METAL_EDGE, LOOK.METAL_EDGE_SLICE }, rim = "white", hot = true, brushed = true, trim = "rivet",
		lean = { 0.42, 0.44, 0.48, 0.32 }, foot = 0.4, prime = "dye", dye = 0.45,
		hover = { color = { 1, 1, 1 }, lift = 0.05, light = 0.3, sheen = 0.8 } },
}
function UI.KeyMake(look)
	return UI.KEY_MAKES[look] or UI.KEY_MAKES.forged
end

-- Heritage: the game's own red button (128-RedButton) cut in nine: its corners and rim from the ends' outer EDGE
-- texels, the face from its middle, so the rim stands RIM units wide on a piece of any size (a tall card wears the
-- same thin rim as a button), less on one too small for it. Without its color and tinted in yours unless the look
-- wears the game's own colors, its light laid again, added, as the heritage frame's is (its Shine); held, its own art
-- turned half round (lit from the other side: pushed in); out of use the game's disabled art; under the mouse its
-- highlight in your color.
do
local RED = "128-RedButton"
local WHITE_EDGE = { 1, 1, 1 }   -- the game's own colors
local HERITAGE_KEY = { EDGE = 32, RIM = 5 }
-- A slice of an atlas, as the game's NineSlice crops one: its file, and the part of it from u0 to u1 across and v0 to
-- v1 down (0 to 1 of the atlas's own picture).
local function Cut(t, name, u0, u1, v0, v1)
	local info = C_Texture.GetAtlasInfo(name)
	if not info then return false end
	local l, r, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local uv = t.shyUV or {}
	uv[1], uv[2], uv[3], uv[4] = l + (r - l) * u0, l + (r - l) * u1, top + (bottom - top) * v0, top + (bottom - top) * v1
	t.shyUV = uv
	t:SetTexture(info.file or info.filename)
	t:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
	t.shyAtlas = name
	return true
end
local function HeritageMark(f, lit, down, primary)
	local parts = f.heritageButton
	local w, h = f:GetSize()
	if issecretvalue(w) or issecretvalue(h) or not (w and h) or w <= 0 or h <= 0 then return end
	local left, right = C_Texture.GetAtlasInfo(RED .. "-Left"), C_Texture.GetAtlasInfo(RED .. "-Right")
	if not (left and right and left.height > 0 and left.width > 0 and right.width > 0) then return end
	local game = Theme.LookOption("heritage", "color") == "game"
	local shine = game and 0 or (Theme.LookOption("heritage", "shine") or 55) / 100
	local off = f.IsEnabled and not f:IsEnabled()
	-- Held, its own art turned about: the light from the other side, so the face reads as pushed in (the game's
	-- pressed art moves its face down and right, which no slicing keeps whole on a tall piece).
	local state = off and "-Disabled" or ""
	local turned = down and not off
	-- The rim: RIM units, no more than the art at the piece's height gives it, nor half the piece.
	local K = HERITAGE_KEY
	local rim = min(K.RIM, h * K.EDGE / left.height, w / 2, h / 2)
	-- Placed, cut and greyed again only when what they go by changed: a slice placed anew has no place on screen
	-- until the next frame, and a ramp tinted then shows its key color for that frame (the lit card flashing as
	-- another is pointed at).
	if parts.rim ~= rim then
		parts.rim = rim
		-- Each line between slices held to the edge it is nearest (so a piece sized again keeps its rim).
		local xs = { { "LEFT", 0 }, { "LEFT", rim }, { "RIGHT", -rim }, { "RIGHT", 0 } }
		local ys = { { "TOP", 0 }, { "TOP", -rim }, { "BOTTOM", rim }, { "BOTTOM", 0 } }
		for i = 1, 18 do
			local at = (i - 1) % 9
			local row, col = floor(at / 3) + 1, at % 3 + 1
			local x0, x1, y0, y1 = xs[col], xs[col + 1], ys[row], ys[row + 1]
			local t = parts[i]
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", f, y0[1] .. x0[1], x0[2], y0[2])
			t:SetPoint("BOTTOMRIGHT", f, y1[1] .. x1[1], x1[2], y1[2])
		end
	end
	if parts.state ~= state or parts.turned ~= turned then
		parts.state, parts.turned = state, turned
		local ev = K.EDGE / left.height
		local cols = {   -- each column's atlas and the part of it across
			{ RED .. "-Left" .. state, 0, K.EDGE / left.width },
			{ "_" .. RED .. "-Center" .. state, 0, 1 },
			{ RED .. "-Right" .. state, 1 - K.EDGE / right.width, 1 },
		}
		local rows = { { 0, ev }, { ev, 1 - ev }, { 1 - ev, 1 } }
		for i = 1, 18 do
			local at = (i - 1) % 9
			local col, row = at % 3 + 1, floor(at / 3) + 1
			if turned then
				-- (each slice the opposite one's, its coordinates run backward: the art half a turn round)
				local c, v = cols[4 - col], rows[4 - row]
				parts[i].shyCut = Cut(parts[i], c[1], c[3], c[2], v[2], v[1])
			else
				local c, v = cols[col], rows[row]
				parts[i].shyCut = Cut(parts[i], c[1], c[2], c[3], v[1], v[2])
			end
		end
	end
	local glow = parts[19]
	if parts.game ~= game then
		parts.game = game
		for i = 1, 19 do parts[i]:SetDesaturated(not game) end
	end
	local accent = UI.LookAccent(f)
	for i = 1, 18 do
		local t, added = parts[i], i > 9
		Theme.Tint(t, game and WHITE_EDGE or accent, added and shine * (primary and 1.3 or 1) or 1)
		-- (a tint leaving a ramp gives the texture its file back, which takes its cut with it: the cut again)
		local uv = t.shyUV
		if uv then t:SetTexCoord(uv[1], uv[2], uv[3], uv[4]) end
		t:SetShown(t.shyCut and (not added or shine > 0))
	end
	-- Its highlight under the mouse, eased in and out as every hover is.
	Theme.Tint(glow, game and WHITE_EDGE or accent, 1)
	glow:Show()
	UI.KeyFade(glow, (lit and not off) and 0.6 or 0)
end
UI.KEY_MAKES.heritage = { edge = { UI.KEY_EDGE, UI.KEY_SLICE }, own = true,
	build = function(f)
		local parts = {}
		for i = 1, 18 do
			parts[i] = f:CreateTexture(nil, "BACKGROUND", nil, i <= 9 and 1 or 2)
			if i > 9 then parts[i]:SetBlendMode("ADD") end
		end
		for i = 1, 18 do parts[i]:SetHorizTile(false) end
		local glow = f:CreateTexture(nil, "ARTWORK", nil, 0)
		glow:SetAtlas(RED .. "-Highlight")
		glow:SetAllPoints()
		glow:SetBlendMode("ADD")
		glow:SetAlpha(0)   -- (unlit until a hover eases it up: never a frame at full)
		parts[19] = glow
		f.heritageButton = parts
		return parts
	end,
	mark = HeritageMark }
end
-- The marks' measures (units): the eclipse's light reaches HALO past the piece (its art's slice HALO_SLICE); a
-- bracket is BRACKET a side; a face's texture stands FACE_IN in, its corners hidden under the edge; a rivet ROW
-- across, its middle SEW in from both its edges, none on a piece under WIDE x TALL.
-- DARK and WHITE: an edge worn black or white; SHEEN the brushed sheen at rest; GLYPH_LC the contrast a glyph on a
-- button keeps with its face (between a mark's and a label's); HOVER a make's hover when it names none.
local KEY = { HALO = 6, HALO_SLICE = 12, BRACKET = 4, FACE_IN = 1.5,
	DARK = { 0, 0, 0 }, WHITE = { 1, 1, 1 }, SHEEN = 0.35, GLYPH_LC = 45,
	HOVER = { color = { 1, 1, 1 }, lift = 0.06, light = 0.4, halo = 0.6 },
	RIVET = { row = 6, sew = 4.5, wide = 40, tall = 20 }, FOOT = 7 }

local KeyFit   -- what goes by a piece's size: its corners, its rivets (below)

-- The corners fit the piece: a piece under twice their size (a narrow segment, a small stepper) takes
-- corners of half its own, so they never overlap; at any size it stays the one make. Each slice keeps its own
-- margin (its art's: the looks' edges differ).
local function Corners(f)
	local w, h = f:GetSize()
	if issecretvalue(w) or issecretvalue(h) or not (w and h) or w <= 0 or h <= 0 then return end
	local cap = floor(min(w, h) / 2)
	if cap == f.shyCorners then return end
	f.shyCorners = cap
	for _, t in ipairs(f.shySlices) do
		local m = min(t.shyMargin or UI.KEY_SLICE, cap)
		t:SetTextureSliceMargins(m, m, m, m)
	end
end

local function KeySliced(f, file, layer, sub)
	local t = f:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(file)
	t:SetTextureSliceMargins(UI.KEY_SLICE, UI.KEY_SLICE, UI.KEY_SLICE, UI.KEY_SLICE)
	t:SetAllPoints()
	if not f.shySlices then
		f.shySlices = {}
		f:HookScript("OnSizeChanged", function(self) KeyFit(self) end)
	end
	f.shySlices[#f.shySlices + 1] = t
	f.shyCorners = nil
	Corners(f)
	return t
end

-- Whether the look in use lays a gloss on a face (Forged and Glass do; Frosted and Eclipse are matte), as
-- on its title strips (UI.LookStrip).
function UI.LookGloss()
	return (select(5, UI.LookStrip(Theme.Look(), 0, 0, 0, 1))) == true
end

function UI.Keyed(f)
	f.fill = KeySliced(f, UI.KEY_FACE, "BACKGROUND", 0)
	Theme.Tint(f.fill, C.bg, 0.94)
	-- The gloss from just under the top edge to the middle, at any height (over a make's face texture).
	f.gloss = f:CreateTexture(nil, "BACKGROUND", nil, 3)
	f.gloss:SetTexture(UI.GLOSS)
	f.gloss:SetPoint("TOPLEFT", 3, -2)
	f.gloss:SetPoint("BOTTOMRIGHT", f, "RIGHT", -3, 0)
	f.gloss:SetAlpha(0.18)
	f.edge = KeySliced(f, UI.KEY_EDGE, "BORDER", 0)
	Theme.Tint(f.edge, Theme.skin.metal)
	f.light = f:CreateTexture(nil, "ARTWORK")
	f.light:SetTexture(UI.LIGHT)
	f.light:SetBlendMode("ADD")
	Theme.Tint(f.light, Theme.light)
	f.light.shyTintBeforeFade = function()
		local r, g, b = Color(Theme.light)
		f.light:SetVertexColor(r, g, b, 1)
	end
	f.light:SetPoint("TOPLEFT", 3, 1)
	f.light:SetPoint("TOPRIGHT", -3, 1)
	f.light:SetHeight(9)
	f.light:SetAlpha(0)
	return f
end

-- A keyed plate that is no control of its own (a reagent's card, what a recipe needs, the row picked in a list):
-- the family's make as each look draws it (UI.KeyPress), its face the panel's well, the mouse left to what is on it
-- or under it. A meaning color tones the whole of it, as a button's (UI.KeyPress's SetTone); lit is the make's own
-- lit state (the accent: what is picked). It must be a Button (the make follows a button's states).
--   UI.KeyPlate(button)   button:SetTone(color | nil, lit)   (Theme.Accent: lit in your color, untoned)
function UI.KeyPlate(f)
	UI.KeyPress(f, { fill = C.bg })
	f:EnableMouse(false)
	local tone = f.SetTone
	function f:SetTone(color, lit)
		if self.plateTone == color and self.plateLit == (lit == true) then return end
		self.plateTone, self.plateLit = color, lit == true
		tone(self, color ~= Theme.Accent and color or nil)
		self:SetOn(lit == true)
	end
	return f
end

-- A look's piece on a keyed piece, made the first time a make wears it.
local function Mark(f, key, layer, sub)
	local t = f[key]
	if not t then
		t = f:CreateTexture(nil, layer, nil, sub)
		f[key] = t
	end
	return t
end

-- The rivets go on whole pixels, as a housing's do (UI.LookFit): each the atlas cell drawn for its size on
-- screen, its middle a whole number of half pixels in from the corner it stands by. (A holder whose plate is
-- another region, a game button's under Kit:Key, names it: shyPlateOf.)
local function Studs(f)
	local studs = f.shyStuds
	if not studs then return end
	local to = f.shyPlateOf or f
	local w, h = to:GetSize()
	local scale = to:GetEffectiveScale()
	local per = not issecretvalue(scale) and scale and scale > 0 and scale / PixelUtil.GetPixelToUIUnitFactor() or nil
	local R, RC = KEY.RIVET, LOOK.RIVET_CELLS
	local show = f.shyKeyMake and f.shyKeyMake.trim == "rivet" and per and not issecretvalue(w) and not issecretvalue(h)
		and w and h and w >= R.wide and h >= R.tall or false
	if show then
		local s = min(RC.most, max(RC.least, floor(R.row * per + 0.5)))
		local mid, side = floor(s / 2), s / per
		local u = (s - RC.least) * (s + RC.least + 1) / 2
		local a = floor(2 * R.sew * per + 0.5)                     -- the middle, in half pixels in from each edge
		local v0 = ((a % 2 == 0 and 1 or 0) + (a % 2 == 0 and 2 or 0)) * (RC.most + 1)
		for i, t in ipairs(studs) do
			local top, left = i <= 2, i % 2 == 1
			local x = left and floor(a / 2) - mid or floor((a + 1) / 2) - s + mid
			local y = top and floor(a / 2) - mid or floor((a + 1) / 2) - s + mid
			local corner = (top and "TOP" or "BOTTOM") .. (left and "LEFT" or "RIGHT")
			t:ClearAllPoints()
			t:SetPoint(corner, to, corner, left and x / per or -x / per, top and -y / per or y / per)
			t:SetSize(side, side)
			t:SetTexCoord(u / RC.w, (u + s) / RC.w, v0 / RC.h, (v0 + s) / RC.h)
		end
	end
	for _, t in ipairs(studs) do t:SetShown(show and f.shyPlate ~= false) end
end

function KeyFit(f)
	if f.shySlices then Corners(f) end
	Studs(f)
end
-- For a make on a game button (Kit:Key): its measures, and its rivets laid on a holder (shyStuds, shyKeyMake,
-- shyPlate, shyPlateOf: the plate they stand on); studded ones laid again on a new scale.
UI.KEY_MEASURES = KEY

-- Rivets are laid again when the UI's scale or a HUD piece's changes (KEY.studded: the pieces wearing them).
KEY.studded = setmetatable({}, { __mode = "k" })
do
	local function Restud()
		for f in pairs(KEY.studded) do Studs(f) end
	end
	Shy:On("SHY_HUD_SCALED", Restud)
	local restud = CreateFrame("Frame")
	restud:RegisterEvent("UI_SCALE_CHANGED")
	restud:RegisterEvent("DISPLAY_SIZE_CHANGED")
	restud:SetScript("OnEvent", Restud)
end
function UI.KeyLay(holder)
	if holder.shyStuds then KEY.studded[holder] = true end
	Studs(holder)
end

-- Hover atlases (KEY_FACE and the like): vertex tint before alpha rises, without Theme.Tint's Lay (SetTexture
-- or SetGradient restore there can show the file untinted for a frame).
local function HoverVertex(t, color)
	local r, g, b = Color(color)
	t:SetVertexColor(r, g, b, 1)
end

local function WashVertex(wash)
	local r, g, b = Theme.AccentSolid()
	wash:SetVertexColor(r, g, b, 1)
end

-- One eased hover and press level per button (0 to 1): every hover layer reads these instead of snapping on
-- mouse down or up, so lift, wash, light and the pressed inset crossfade smoothly.
local blendAnims = setmetatable({}, { __mode = "k" })   -- s -> { hov = { from, to, t }, press = ... }
local fader, FadeStep
local FADE = 0.16   -- hover/press blend and texture fades (seconds)

local function EaseBlend(s, key, to, now)
	s.blend = s.blend or { hov = 0, press = 0 }
	local cur = s.blend[key]
	if now or abs(cur - to) < 0.004 then
		local anims = blendAnims[s]
		if anims then anims[key] = nil end
		s.blend[key] = to
		return
	end
	local anims = blendAnims[s]
	if not anims then
		anims = {}
		blendAnims[s] = anims
	end
	local f = anims[key]
	if f and f.to == to then return end
	anims[key] = { from = cur, to = to, t = 0 }
	fader:SetScript("OnUpdate", FadeStep)
end

local function BlendStep(s, dt)
	local anims = blendAnims[s]
	if not anims then return false end
	local moved = false
	for key, f in pairs(anims) do
		f.t = f.t + dt
		local k = min(1, f.t / FADE)
		local e = 1 - (1 - k) ^ 3
		s.blend[key] = f.from + (f.to - f.from) * e
		if k >= 1 then
			anims[key] = nil
		else
			moved = true
		end
	end
	if not next(anims) then blendAnims[s] = nil end
	return moved
end

-- A keyed piece dressed in its look's make: its edge's art, its face's texture and the marks the make wears,
-- made the first time they're worn and put away when another make doesn't wear them. Again only when the look
-- changed. Returns the make.
local function KeyDress(f)
	local look = f.shyKeyFixed or Theme.Look()
	if f.shyKeyLook == look then return f.shyKeyMake end
	local make = UI.KeyMake(look)
	f.shyKeyLook, f.shyKeyMake = look, make
	f.edge:SetTexture(make.edge[1])
	f.edge.shyMargin = make.edge[2]
	f.shyCorners = nil
	-- The face's texture: the make's own, the hide's grain, brushed steel, frost.
	local file = (make.face and make.face()) or (make.grain and LOOK.GRAIN) or (make.brushed and LOOK.BRUSHED) or (make.frost and UI.FROST) or nil
	if file then
		local t = Mark(f, "face", "BACKGROUND", 1)
		t:SetTexture(file, "REPEAT", "REPEAT")
		t:SetHorizTile(true)
		t:SetVertTile(true)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", KEY.FACE_IN, -KEY.FACE_IN)
		t:SetPoint("BOTTOMRIGHT", -KEY.FACE_IN, KEY.FACE_IN)
	end
	if f.face then f.face:SetShown(file ~= nil) end
	if make.brushed then
		local t = Mark(f, "sheen", "BACKGROUND", 2)
		t:SetTexture(LOOK.METAL_SHEEN)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", KEY.FACE_IN, -KEY.FACE_IN)
		t:SetPoint("BOTTOMRIGHT", -KEY.FACE_IN, KEY.FACE_IN)
		t:SetVertexColor(1, 1, 1, 1)
		t:SetAlpha(KEY.SHEEN)   -- (its strength in its alpha: the hover eases it up)
	end
	if f.sheen then f.sheen:SetShown(make.brushed == true) end
	-- A plate's darker foot (FOOT tall, dying away upward).
	if make.foot then
		local t = Mark(f, "footBand", "BACKGROUND", 2)
		t:SetColorTexture(1, 1, 1, 1)
		t:SetGradient("VERTICAL", CreateColor(0, 0, 0, make.foot), CreateColor(0, 0, 0, 0))
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", KEY.FACE_IN, KEY.FACE_IN)
		t:SetPoint("BOTTOMRIGHT", -KEY.FACE_IN, KEY.FACE_IN)
		t:SetHeight(KEY.FOOT)
	end
	if f.footBand then f.footBand:SetShown(make.foot ~= nil) end
	-- The hover's lift: a wash of the make's hover color over the face, in the face's own shape (every make; none
	-- shown at rest).
	local lift = Mark(f, "lift", "ARTWORK", 0)
	if not lift.shyMargin then
		lift:SetTexture(UI.KEY_FACE)
		lift:SetAllPoints()
		lift.shyMargin = UI.KEY_SLICE
		f.shySlices[#f.shySlices + 1] = lift
		local hover = UI.KeyHover(make)
		Theme.Tint(lift, hover.color or KEY.WHITE, 1)
		lift:SetAlpha(0)
	end
	-- A press: the face below its edge (every make).
	local inset = Mark(f, "inset", "ARTWORK", 2)
	if not inset.shyMargin then
		inset:SetTexture(UI.KEY_INSET)
		inset:SetAllPoints()
		inset.shyMargin = UI.KEY_SLICE
		f.shySlices[#f.shySlices + 1] = inset
		inset:SetAlpha(0)
	end
	if make.halo then
		local t = Mark(f, "halo", "BACKGROUND", -2)
		if not t.shyLaid then
			t.shyLaid = true
			t:SetTexture(UI.KEY_HALO)
			t:SetTextureSliceMargins(KEY.HALO_SLICE, KEY.HALO_SLICE, KEY.HALO_SLICE, KEY.HALO_SLICE)
			t:SetBlendMode("ADD")
			t:SetPoint("TOPLEFT", -KEY.HALO, KEY.HALO)
			t:SetPoint("BOTTOMRIGHT", KEY.HALO, -KEY.HALO)
			Theme.Tint(t, Theme.Accent, 1)
			t:SetAlpha(0)
		end
	end
	if f.halo then f.halo:SetShown(make.halo == true) end
	if make.trim == "bracket" and not f.shyBrackets then
		f.shyBrackets = {}
		for i, corner in ipairs(BRACKETS) do
			local t = f:CreateTexture(nil, "BORDER", nil, 2)
			t:SetTexture(UI.KEY_BRACKET)
			t:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
			t:SetSize(KEY.BRACKET, KEY.BRACKET)
			t:SetPoint(corner[1])
			f.shyBrackets[i] = t
		end
	end
	if f.shyBrackets then
		for _, t in ipairs(f.shyBrackets) do t:SetShown(make.trim == "bracket") end
	end
	if make.trim == "rivet" and not f.shyStuds then
		f.shyStuds = {}
		for i = 1, 4 do
			local t = f:CreateTexture(nil, "BORDER", nil, 2)
			t:SetTexture(LOOK.RIVET)
			f.shyStuds[i] = t
		end
		KEY.studded[f] = true
	end
	-- A make's own pieces: built once on a piece, and put away whenever it wears another make.
	if make.build and not (f.shyBuilt and f.shyBuilt[make]) then
		f.shyBuilt = f.shyBuilt or {}
		f.shyBuilt[make] = make.build(f) or {}
	end
	if f.shyBuilt then
		for other, regions in pairs(f.shyBuilt) do
			if other ~= make then
				for _, region in ipairs(regions) do region:Hide() end
			end
		end
	end
	KeyFit(f)
	return make
end
UI.KeyDress = KeyDress

-- A texture's alpha eased to `to` over FADE seconds (now, or unseen: at once). One driver for every fade,
-- running only while one moves. Keyed buttons also ease hover and press blends here, then dress again.
local fades = {}
fader = CreateFrame("Frame")
FadeStep = Shy.Clocked("ui: a button's light", function(_, dt)
	for s, _ in pairs(blendAnims) do
		BlendStep(s, dt)
		if s._btn then KeyLook(s._btn) end
	end
	for t, f in pairs(fades) do
		f.t = f.t + dt
		local k = min(1, f.t / FADE)
		t:SetAlpha(f.from + (f.to - f.from) * (1 - (1 - k) ^ 3))
		if k >= 1 then fades[t] = nil end
	end
	if not next(fades) and not next(blendAnims) then fader:SetScript("OnUpdate", nil) end
end)

local function Fade(t, to, now)
	local f = fades[t]
	if f and f.to == to and not now then return end
	if now or not t:IsVisible() or abs(t:GetAlpha() - to) < 0.004 then
		fades[t] = nil
		t:SetAlpha(to)
		return
	end
	fades[t] = { from = t:GetAlpha(), to = to, t = 0 }
	fader:SetScript("OnUpdate", FadeStep)
end
UI.KeyFade = Fade   -- (for a make's own pieces: their hover eased as the family's is)

-- Every keyed piece paints its whole state again on a change of theme, as a hover does: its layers aren't
-- left to follow one by one.
local keyed = setmetatable({}, { __mode = "k" })   -- frame -> function(frame) that repaints it
Shy:On("SHY_THEME", function()
	for f, repaint in pairs(keyed) do repaint(f) end
end)

-- A piece sized to its words measures them again when the font on screen changes (a wider face would run past
-- it), a font hovered in a list as much as one picked.
--   UI.KeyWords(frame, measure, key)   -- measure(frame) when the font changes; one per key ("words" when none)
do
	local worded = setmetatable({}, { __mode = "k" })   -- frame -> { key -> function(frame) that measures it again }
	function UI.KeyWords(f, measure, key)
		worded[f] = worded[f] or {}
		worded[f][key or "words"] = measure
	end
	Shy:On("SHY_FONT", function()
		for f, list in pairs(worded) do
			for _, measure in pairs(list) do measure(f) end
		end
	end)
end

-- A fill's tone, held down.
local function Held(c)
	local tone = ToneFill(c)
	return function()
		local r, g, b, a = tone()
		return r * 0.7, g * 0.7, b * 0.7, a
	end
end

-- A button's tones, for a make on a frame of the game's (Kit:Key): each a color function for Theme.Tint.
UI.KeyTone = { fill = ToneFill, held = Held, edge = function(c) return ToneBorder(c or Theme.skin.metal) end }

-- A piece standing on a housing's edge (a tab rising off a unit frame's top): no frame of the look's own, but its
-- colors. The fill the housing's own in the look in use (UI.LookFill at the look's alpha; `solid`: at full
-- strength, for pieces that overlap one another), the rim the look's steel as its controls wear it (`c`: a color
-- of meaning instead, kept). Each a color function for Theme.Tint, or to call for r, g, b, a.
UI.PieceTone = {
	fill = function(solid)
		return function()
			local look = Theme.Look()
			local r, g, b, a = Color(C.hud)
			return UI.LookFill(look, r, g, b, solid and 1 or UI.LookAlpha(look, a))
		end
	end,
	edge = function(c) return ToneBorder(c or Theme.skin.metal) end,
}

-- The words still in the ink this make gave them: anyone else's ink (a dim choice, a good one) is kept.
local function Ours(fs, c)
	if not c then return true end
	local r, g, b = fs:GetTextColor()
	local cr, cg, cb = Color(c)
	return abs(r - cr) < 0.006 and abs(g - cg) < 0.006 and abs(b - cb) < 0.006
end

-- A meaning color's own shades for a button in it (a merchant's gold): its face deep, its edge pale.
local function Shade(c, k)
	return function()
		local r, g, b = Color(c)
		return r * k, g * k, b * k, 1
	end
end
local function Pale(c, k)
	return function()
		local r, g, b = Color(c)
		return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k, 1
	end
end

-- Its content held down a unit, or let up: each region by its first anchor.
local function Sink(s, down)
	local step = down and 1 or 0
	if step == s.step then return end
	for _, region in ipairs(s.sink) do
		local point, to, toPoint, x, y = region:GetPoint(1)
		if point then region:SetPoint(point, to, toPoint, x + step - s.step, y - step + s.step) end
	end
	s.step = step
end

-- A face's color in its make: the fill toned by the look, leaning as the make says (Glass to a cool pane, Frosted to
-- frost, Riveted to bright steel) and as clear as it says (Glass); the primary the accent's fill, or the make's own
-- way of wearing it (`prime`): "dye" the face steeped in it, "light" and "halo" the face as at rest (the color is
-- its light). Held, darker. A color function.
local function KeyFace(make, c, primary, down)
	local own = primary and make.prime
	local tone = ToneFill(own and C.bgHot or c)
	local lean, clear = make.lean, make.clear
	-- (Its alpha whole, or the pane's: a face is never as faint as the fill's own color.)
	return function()
		local r, g, b
		local a = 1
		if primary and not own then
			r, g, b = Color(C.fill)
		else
			r, g, b = tone()
			if lean then r, g, b = Blend(r, g, b, lean[1], lean[2], lean[3], lean[4]) end
			if own == "dye" then
				local fr, fg, fb = Color(C.fill)
				r, g, b = Blend(r, g, b, fr, fg, fb, make.dye or 0.5)
			end
			a = clear or 1
		end
		if down then r, g, b = r * 0.7, g * 0.7, b * 0.7 end
		return r, g, b, a
	end
end

-- A look's material on a piece of the family's own shape that no housing and no key dresses (the column's plaques,
-- the hovers' cards, the nameplates): what the look's buttons are made of, so every surface on screen reads as the
-- look chosen. The piece keeps its shape, its size and its own edge art in every look; only what it is made of
-- changes: its face toned and leaning as the make's (UI.KEY_MAKES), the make's texture over it (its own face, the
-- hide's grain, brushed steel and its sheen, frost) kept inside the piece's edge, and the edge itself in the make's
-- rim at rest. Forged is the family's own make: the piece as its art is. A look of its own file whose buttons lay
-- their face in their own pieces names the face here (UI.LookKind's `surface = { file, alpha, color }`).
--   UI.LookMaterial(look) -> m   { look, tone = color function or nil (the piece's own fill), clear, face, faceAlpha, faceColor,
--                                  sheen, rim = { r, g, b }, halo (your color's light round it), shade (share of the
--                                  piece's shadow) }
--   UI.LookRim(look) -> r, g, b  the tint a piece's own steel edge takes at rest
--   UI.LookSurface(owner, layer, sub) -> s   the face on any piece (s.tone, s.face, s.sheen: textures on `sub` and the
--                                  sublevel over it); place it with s:SetPoint / s:SetAllPoints / s:ClearAllPoints, keep
--                                  it inside with s:AddMaskTexture
--   s:Dress(alpha, look)         worn for the look (the theme's when nil) at the piece's strength; dressed again on
--                                  SHY_THEME at the strength last given. s:SetShown(on) puts it away or back
do
	local RIM = { metal = { 1, 1, 1 }, white = { 1, 1, 1 }, dark = { 0.32, 0.32, 0.35 } }
	local SHADE = { clear = 0.7, eclipse = 0, riveted = 0.6 }
	local NONE = {}
	local cache = {}   -- look -> its material (made again on SHY_THEME: a look's options change its face)

	function UI.LookMaterial(look)
		look = look or Theme.Look()
		local m = cache[look]
		if m then return m end
		local make = UI.KEY_MAKES[look]
		local kind = KINDS[look]
		local own = kind and kind.surface or NONE
		m = { look = look, rim = RIM[make and make.rim or "metal"] or RIM.metal, halo = make ~= nil and make.halo == true }
		if make and look ~= "forged" then
			m.tone, m.clear = KeyFace(make, C.panel, false, false), make.clear
			if own.file then m.face, m.faceAlpha, m.faceColor = own.file, own.alpha or 1, own.color
			elseif make.face and make.grain then m.face, m.faceAlpha = make.face(), make.grain
			elseif make.grain then m.face, m.faceAlpha = LOOK.GRAIN, make.grain
			elseif make.brushed then m.face, m.faceAlpha, m.sheen = LOOK.BRUSHED, 1, KEY.SHEEN
			elseif make.frost then m.face, m.faceAlpha = UI.FROST, make.frost end
		end
		if kind and kind.shade == false then m.shade = 0
		elseif kind and type(kind.shade) == "number" then m.shade = kind.shade
		else m.shade = SHADE[look] or 1 end
		cache[look] = m
		return m
	end

	function UI.LookRim(look)
		local rim = UI.LookMaterial(look).rim
		return rim[1], rim[2], rim[3]
	end

	local surfaces = setmetatable({}, { __mode = "k" })
	local Surface = {}
	Surface.__index = Surface
	function Surface:SetPoint(...) for _, t in ipairs(self.list) do t:SetPoint(...) end end
	function Surface:SetAllPoints(...) for _, t in ipairs(self.list) do t:SetAllPoints(...) end end
	function Surface:ClearAllPoints() for _, t in ipairs(self.list) do t:ClearAllPoints() end end
	function Surface:AddMaskTexture(mask) for _, t in ipairs(self.list) do t:AddMaskTexture(mask) end end
	function Surface:SetShown(on)
		self.off = on == false
		if self.alpha then self:Dress(self.alpha, self.fixed) end
	end
	function Surface:Dress(alpha, look)
		self.alpha, self.fixed = alpha or 1, look
		alpha = self.alpha
		local m = UI.LookMaterial(look)
		local on = not self.off
		if on and m.tone then
			local r, g, b = m.tone()
			self.tone:SetVertexColor(r, g, b, alpha * (m.clear or 1))
		end
		self.tone:SetShown(on and m.tone ~= nil)
		if on and m.face then
			if self.file ~= m.face then
				self.file = m.face
				self.face:SetTexture(m.face, "REPEAT", "REPEAT")
				self.face:SetHorizTile(true)
				self.face:SetVertTile(true)
			end
			local ink = m.faceColor or RIM.white
			self.face:SetVertexColor(ink[1], ink[2], ink[3], m.faceAlpha * alpha)
		end
		self.face:SetShown(on and m.face ~= nil)
		if on and m.sheen then self.sheen:SetVertexColor(1, 1, 1, m.sheen * alpha) end
		self.sheen:SetShown(on and m.sheen ~= nil)
	end

	function UI.LookSurface(owner, layer, sub)
		sub = sub or 0
		local s = setmetatable({ owner = owner }, Surface)
		s.tone = owner:CreateTexture(nil, layer, nil, sub)
		s.tone:SetColorTexture(1, 1, 1, 1)
		s.face = owner:CreateTexture(nil, layer, nil, min(7, sub + 1))
		s.sheen = owner:CreateTexture(nil, layer, nil, min(7, sub + 1))
		s.sheen:SetTexture(LOOK.METAL_SHEEN)
		s.list = { s.tone, s.face, s.sheen }
		for _, t in ipairs(s.list) do t:Hide() end
		surfaces[s] = true
		return s
	end

	Shy:On("SHY_THEME", function()
		wipe(cache)
		for s in pairs(surfaces) do
			if s.alpha then s:Dress(s.alpha, s.fixed) end
		end
	end)
end

-- A circle's border in the look worn: the look's own ring (UI.LookKind's `ring`: its border bent round a circle, drawn
-- for it) laid over the rim of a circle of ours (a dial: the steel ring a sign, a level or an arrow stands in). A look
-- with none leaves the dial as it is. It goes where its dial goes (shown and hidden with it) and is dressed again on
-- SHY_THEME. A dial in a meaning's color (a danger, a thing done) shows its own rim, which carries that color: its
-- owner says so (ring:Plain(false)) and the look's ring stands down for as long.
--   UI.LookRing(dial, size, owner) -> ring   dial: the circle's own texture; size: the circle across (units); owner:
--                                     the frame its art is made on (the dial's own when none: one above it where
--                                     something else is drawn over the dial's rim)
--   ring:Plain(plain)                 false while the dial wears a meaning's color
--   ring:Worn()                       whether the look's ring is on it now (its owner puts the dial's rim to glass)
do
	local rings = setmetatable({}, { __mode = "k" })
	local Ring = {}
	Ring.__index = Ring

	function Ring:Dress()
		local kind = KINDS[Theme.Look()]
		-- (The look's art drawn for the density it is shown at: UI.TexelsFor.)
		local art = kind and kind.ring and kind.ring(self.size, UI.TexelsFor(self.dial)) or nil
		local on = art ~= nil and self.plain and self.dial:IsShown()
		self.on = on and true or false
		for _, t in ipairs(self.parts) do t:SetShown(on) end
		if not on then return end
		if self.file ~= art.file then
			self.file = art.file
			self.base:SetTexture(art.file)
			self.key:SetTexture(art.key)
			self.light:SetTexture(art.light)
		end
		for _, t in ipairs(self.parts) do t:SetSize(art.span, art.span) end
		local lift = art.glow or 0.5
		Theme.Tint(self.key, Theme.Accent, 1)
		Theme.Tint(self.light, function()
			local r, g, b = Theme.Accent()
			return r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift
		end, 1)
	end

	-- Whether the look's ring is on the dial now: its owner may put the dial's own rim to glass under it, so one ring
	-- shows.
	function Ring:Worn()
		return self.on == true
	end

	function Ring:Plain(plain)
		plain = plain ~= false
		if self.plain == plain then return end
		self.plain = plain
		self:Dress()
	end

	function UI.LookRing(dial, size, owner)
		local layer, sub = "ARTWORK", 0
		if not owner then
			owner = dial:GetParent()
			layer, sub = dial:GetDrawLayer()
			layer, sub = layer or "ARTWORK", sub or 0
		end
		local ring = setmetatable({ dial = dial, size = size, plain = true, parts = {} }, Ring)
		for i, name in ipairs({ "base", "key", "light" }) do
			local t = owner:CreateTexture(nil, layer, nil, min(7, sub + i))
			t:SetPoint("CENTER", dial, "CENTER")
			if name == "light" then t:SetBlendMode("ADD") end
			t:SetSnapToPixelGrid(false)   -- (on the dial's own middle: UI.Concentric)
			t:SetTexelSnappingBias(0)
			t:Hide()
			ring[name] = t
			ring.parts[i] = t
		end
		local function Follow() ring:Dress() end
		hooksecurefunc(dial, "Show", Follow)
		hooksecurefunc(dial, "Hide", Follow)
		hooksecurefunc(dial, "SetShown", Follow)
		rings[ring] = true
		ring:Dress()
		return ring
	end

	Shy:On("SHY_THEME", function()
		for ring in pairs(rings) do ring:Dress() end
	end)
end

-- A texture's shine: its own art laid over it a second time, added, so the art itself grows lighter in its own
-- colors with nothing spread past it (a glow's light reaches round the art and washes it out). The shine hangs on
-- the texture's own points and takes every picture, cut, slice, color and showing the texture is given after this;
-- nothing is read back, so it serves a frame that can't be measured (a nameplate) too.
-- A texture that isn't shining costs nothing more than itself: what it is given is only kept, and its second copy
-- is made, and told all of it, the first time it shines while it shows. While it shines the copy is told as the
-- texture is.
--   UI.Shine(texture, owner, layer, sub) -> texture   the shine made on owner (the texture's frame), in the layer and
--                                          sublevel it is drawn in (just over the texture's own)
--   UI.SetShine(texture, k)                0 to 1: how much of the art is added again (0: none); UI.ShineOf(texture)
do
	local FORWARD = { "SetTexture", "SetTexCoord", "SetTextureSliceMargins", "SetTextureSliceMode", "SetVertexColor",
		"SetHorizTile", "SetVertTile" }
	local METHODS = { "SetShown", "Show", "Hide" }   -- every method a shining texture has of ours: these and FORWARD
	for _, name in ipairs(FORWARD) do METHODS[#METHODS + 1] = name end
	-- texture -> { owner, layer, sub, base (the widget's own methods), shown (nil: not asked yet), k, kept (name ->
	-- what it was last given), twin (once made), up (the twin shows), stale (the twin was not told something kept),
	-- alpha }
	local shines = setmetatable({}, { __mode = "k" })
	local bases = setmetatable({}, { __mode = "k" })    -- a widget kind (its metatable) -> its own methods, by name
	local Shared = {}                                    -- name -> the one function every shining texture has for it

	-- The twin made if it wasn't, told what it missed, and shown while its texture shows and shines.
	local function Up(s, texture)
		local shown = s.shown
		if shown == nil and s.k > 0 then
			shown = texture:IsShown() and true or false
			s.shown = shown
		end
		if shown and s.k > 0 then
			local twin = s.twin
			if not twin then
				twin = s.owner:CreateTexture(nil, s.layer, nil, s.sub)
				twin:SetAllPoints(texture)
				twin:SetBlendMode("ADD")
				s.twin, s.stale = twin, true
			end
			if s.stale then
				s.stale = false
				local kept = s.kept
				for _, name in ipairs(FORWARD) do
					local given = kept[name]
					if given then twin[name](twin, unpack(given, 1, given.n)) end
				end
			end
			if s.alpha ~= s.k then
				s.alpha = s.k
				twin:SetAlpha(s.k)
			end
			if not s.up then
				s.up = true
				twin:Show()
			end
		elseif s.up then
			s.up = false
			s.twin:Hide()
		end
	end

	for _, name in ipairs(FORWARD) do
		Shared[name] = function(self, ...)
			local s = shines[self]
			local own = s.base[name]
			own(self, ...)
			local given = s.kept[name]
			if not given then
				given = {}
				s.kept[name] = given
			end
			given.n = select("#", ...)
			given[1], given[2], given[3], given[4], given[5], given[6], given[7], given[8] = ...
			-- (The copy is a texture like any other: told by its own method, never through a hook on this one's.)
			local twin = s.up and s.twin
			if twin then twin[name](twin, ...) else s.stale = true end
		end
	end
	local function Shows(self, s, shown)
		if shown == s.shown then return end
		s.shown = shown
		if s.k > 0 then Up(s, self) end
	end
	function Shared.SetShown(self, shown)
		local s = shines[self]
		s.base.SetShown(self, shown)
		Shows(self, s, shown and true or false)
	end
	function Shared.Show(self)
		local s = shines[self]
		s.base.Show(self)
		Shows(self, s, true)
	end
	function Shared.Hide(self)
		local s = shines[self]
		s.base.Hide(self)
		Shows(self, s, false)
	end

	function UI.Shine(texture, owner, layer, sub)
		if shines[texture] then return texture end
		local meta = getmetatable(texture) or bases
		local base = bases[meta]
		if not base then
			base = {}
			bases[meta] = base
		end
		-- (A method the texture has of its own already, another's hook on it, is kept as it is: this one's alone.)
		local own
		for _, name in ipairs(METHODS) do
			local has = rawget(texture, name)
			if has ~= nil then
				own = own or setmetatable({}, { __index = base })
				own[name] = has
			elseif base[name] == nil then
				base[name] = texture[name]
			end
			texture[name] = Shared[name]
		end
		-- (Whether it shows is asked when its shine is first wanted, or learned as it is shown or hidden.)
		shines[texture] = { owner = owner, layer = layer, sub = sub, base = own or base, kept = {}, k = 0, up = false,
			stale = false }
		return texture
	end

	-- How much of a texture's art is added again now (0: none, or no shine).
	function UI.ShineOf(texture)
		local s = shines[texture]
		return s and s.k or 0
	end

	function UI.SetShine(texture, k)
		local s = shines[texture]
		if not s then return end
		k = k or 0
		if k == s.k then return end
		s.k = k
		Up(s, texture)
	end
end

local function KeyFacePress(make, c, primary, press)
	if press <= 0 then return KeyFace(make, c, primary, false) end
	if press >= 1 then return KeyFace(make, c, primary, true) end
	return function()
		local r0, g0, b0, a0 = KeyFace(make, c, primary, false)()
		local r1, g1, b1, a1 = KeyFace(make, c, primary, true)()
		return r0 + (r1 - r0) * press, g0 + (g1 - g0) * press, b0 + (b1 - b0) * press, a0 + (a1 - a0) * press
	end
end
UI.KeyFace = KeyFace

-- What stands on a button against its face: the contrast floor, the glyphs' lift, the make's gloss, edge and
-- hover (UI.KeySeen, UI.KeyFloor, UI.KeyLift, UI.KeyLifted, UI.KeyGloss, UI.KeyRim, UI.KeyHover).
do
-- The accent where a piece stands (a gradient's color at its middle: across the screen, or along its frame).
local function AccentAt(f)
	local left, right = f:GetLeft(), f:GetRight()
	if issecretvalue(left) or issecretvalue(right) or not (left and right) or right < left then return Theme.Accent() end
	local g = Theme.Stops()
	local mid = (left + right) / 2
	if g.spread == "along" then
		local frame = f:GetParent()
		local fl, fr = frame and frame:GetLeft(), frame and frame:GetRight()
		if issecretvalue(fl) or issecretvalue(fr) or not (fl and fr) or fr <= fl then return Theme.Accent() end
		return Theme.At((mid - fl) / (fr - fl))
	end
	local scale, screen = f:GetEffectiveScale(), UIParent:GetWidth() * UIParent:GetEffectiveScale()
	if issecretvalue(scale) or not (scale and screen and screen > 0) then return Theme.Accent() end
	return Theme.At(mid * scale / screen)
end

-- The face as it is seen: its color, the accent's wash over it at `wash` (the color where the piece stands), a
-- clear pane over the panel it stands on. What the words and glyphs on it are read against.
local function Seen(f, face, wash)
	return function()
		local r, g, b, a = face()
		if a and a < 1 then
			local p = C.panel
			r, g, b = Blend(p[1], p[2], p[3], r, g, b, a)
		end
		if wash and wash > 0 then
			local ar, ag, ab = AccentAt(f)
			r, g, b = Blend(r, g, b, ar, ag, ab, wash)
		end
		return r, g, b, 1
	end
end
UI.KeySeen = Seen

-- An ink made to read on what it stands on (the contrast floor): kept while it reads at `lc`, else drawn toward
-- the face's own ink just far enough. Whatever the accent or the ramp, a glyph or a word never sinks into its face.
-- `polar` ("light" or "dark", the button's at rest: UI.KeyPolar) holds it to one side: drawn only toward white, or
-- only toward black, so a hover's lighter face never flips light words dark (and their shadow white) for a frame.
local function Floor(ink, seen, lc, polar)
	local want = lc or Theme.LC_LABEL
	return function()
		local ir, ig, ib = Color(ink)
		local fr, fg, fb = seen()
		if not polar then
			local r, g, b = Theme.Readable(ir, ig, ib, fr, fg, fb, want)
			return r, g, b, 1
		end
		local Lc = Theme.Lc
		if abs(Lc(ir, ig, ib, fr, fg, fb)) >= want then return ir, ig, ib, 1 end
		local to = polar == "light" and 1 or 0
		local lo, hi = 0, 1
		for _ = 1, 12 do
			local t = (lo + hi) / 2
			if abs(Lc(ir + (to - ir) * t, ig + (to - ig) * t, ib + (to - ib) * t, fr, fg, fb)) >= want then hi = t else lo = t end
		end
		return ir + (to - ir) * hi, ig + (to - ig) * hi, ib + (to - ib) * hi, 1
	end
end
UI.KeyFloor = Floor

-- Which ink a face wants, light or dark, as seen at rest: what reads better on it, white or black.
function UI.KeyPolar(seen)
	local r, g, b = seen()
	return abs(Theme.Lc(1, 1, 1, r, g, b)) >= abs(Theme.Lc(0, 0, 0, r, g, b)) and "light" or "dark"
end

-- Words on a face, worked out from the face's color where it stands (a gradient's color there):
--   the ink    the owner's own while it reads on the face (APCA, Theme.LC_LABEL), else the face's own ink
--              (Theme.InkOn: a neutral of its hue, light or dark, whichever reads), never a half-way grey
--   the shadow (worn wherever the text effect is a shadow, through Theme.ShadeOn) light words take one of the face's
--              own hue, deep (its HSL lightness brought down, some of its saturation kept, so it sits in the face
--              rather than smudging it), only as dark as the contrast falls short: a mid green a firm one, near
--              black a whisper; dark words no dark shadow at all, but a faint pale lift under them, as letterpress.
--              The strength setting deepens it a little, never to a hard double.
-- Kept up as the theme changes; asked again by the owner when the piece moves or its state changes.
--   UI.FaceInk(fs, piece, face, ink)   face: a palette table or color function (Theme.Accent: the ramp where the
--                                       piece stands); ink: the owner's own (C.text unless told)
local FACE_SHADE = { least = 0.2, most = 0.7, firm = 90, short = 30, deep = 0.09, keep = 0.6, lift = 0.22, pale = 0.6,
	reach = 0.5 }
local faced = setmetatable({}, { __mode = "k" })

local function FaceColor(piece, face)
	if face == Theme.Accent then return AccentAt(piece) end
	local r, g, b, a = Color(face)
	if a < 1 then
		local p = C.panel
		r, g, b = Blend(p[1], p[2], p[3], r, g, b, a)
	end
	return r, g, b
end

-- The shadow worked out for a string (Theme.ShadeOn's): dx, dy, r, g, b, a.
local function FaceShade(fs, strength)
	local w = faced[fs]
	local S = FACE_SHADE
	if not (w and w.shade) then return 1, -1, 0, 0, 0, S.least end
	local sh = w.shade
	if sh.light then
		local o = 1 + S.reach * strength
		return o, -o, sh[1], sh[2], sh[3], min(1, sh[4] * (1 + S.reach * strength))
	end
	return 0, -1, sh[1], sh[2], sh[3], sh[4]
end

local function FaceDress(fs)
	local w = faced[fs]
	if not w then return end
	local S = FACE_SHADE
	local fr, fg, fb = FaceColor(w.piece, w.face)
	local ir, ig, ib = Color(w.ink)
	local Lc = Theme.Lc
	if abs(Lc(ir, ig, ib, fr, fg, fb)) < Theme.LC_LABEL then ir, ig, ib = Theme.InkOn(fr, fg, fb) end
	local lc = Lc(ir, ig, ib, fr, fg, fb)
	local h, s, l = Theme.ToHSL(fr, fg, fb)
	if lc < 0 then
		local short = max(0, min(1, (S.firm + lc) / S.short))
		local sr, sg, sb = Theme.FromHSL(h, s * S.keep, min(l, S.deep))
		w.shade = { sr, sg, sb, S.least + (S.most - S.least) * short, light = true }
	else
		local pr, pg, pb = Theme.FromHSL(h, s * S.keep, l + (1 - l) * S.pale)
		w.shade = { pr, pg, pb, S.lift, light = false }
	end
	-- (Inked through the theme, so it holds; the shadow through the text effect, so the setting is kept.)
	Theme.Ink(fs, function() return ir, ig, ib, 1 end)
	Theme.ShadeOn(fs, FaceShade)
end

function UI.FaceInk(fs, piece, face, ink)
	local w = faced[fs] or {}
	faced[fs] = w
	w.piece, w.face, w.ink = piece, face, ink or C.text
	FaceDress(fs)
end

Shy:On("SHY_THEME", function()
	for fs in pairs(faced) do FaceDress(fs) end
end)

-- A unit's health through this curve is 1 while any is missing and 0 at full: an alpha for what shows only once
-- they are hurt (a percent), passed straight to SetAlpha, since the health itself may be secret. Made once.
--   region:SetAlpha(UnitHealthPercent(unit, true, UI.HurtCurve()))
local hurt
function UI.HurtCurve()
	if not hurt then
		hurt = C_CurveUtil.CreateCurve()
		hurt:SetType(Enum.LuaCurveType.Linear)
		hurt:AddPoint(0, 1)
		hurt:AddPoint(0.9999, 1)
		hurt:AddPoint(1, 0)
	end
	return hurt
end

-- A page to read on (a quest's words, a letter): a card a shade off the ground with hairline edges, or a paper of the
-- game's laid to cover it at whatever size it is given (scaled by the side that asks more, cropped at the other, its
-- top kept), its edges feathered into the page so a crop never shows a cut. It clips what stands on it.
--   local page = UI.PaperPage(parent, { feather = 22 })
--   page:Lay(paper) -> face, ink    on every new paper and new size; ink the words with UI.FaceInk(fs, page, face, ink)
--     paper nil: the card. Else one of:
--       { atlas = name, material = "Parchment" }                       one picture
--       { material = "Stone", pieces = true }                           an item text material's four pieces
--       { files = { { file, x, y, w, h }, ... }, spread = { w, h }, material = "Parchment" }   pictures laid as one
--     face: what the words stand on (a function on the card, so a theme change reads it again); ink: the game's for
--     that paper (GetMaterialTextColors), the theme's text on the card.
--   page.on: the paper laid, or nil
UI.PAPER_TONE = {   -- each paper's tone as words see it (measured off the game's art)
	Parchment = { 0.80, 0.70, 0.52 }, Stone = { 0.20, 0.19, 0.21 }, Marble = { 0.76, 0.77, 0.77 },
	Silver = { 0.27, 0.29, 0.31 }, Bronze = { 0.82, 0.55, 0.18 }, Valentine = { 0.91, 0.88, 0.80 },
}
UI.PAPER_PIECES = {   -- a material's four pieces as one picture, and the height their art reaches
	files = { { "TopLeft", 0, 0, 256, 256 }, { "TopRight", 256, 0, 64, 256 }, { "BotLeft", 0, 256, 256, 128 }, { "BotRight", 256, 256, 64, 128 } },
	spread = { 320, 356 },
}

local function PaperCard()
	return C.bg[1], C.bg[2], C.bg[3], 0.55
end

local function PaperLay(page, paper)
	local wide, tall = page:GetWidth(), page:GetHeight()
	if issecretvalue(wide) or issecretvalue(tall) then wide, tall = 1, 1 end
	page.on = paper
	page.paper:Hide()
	for _, piece in ipairs(page.pieces) do piece:Hide() end
	for _, f in ipairs(page.feather) do f:SetShown(paper ~= nil) end
	for _, edge in ipairs(page.line) do edge:SetShown(paper == nil) end
	if not paper then
		UI.Paint(page.card, C.bg, 0.55)
		page.card:Show()
		return PaperCard, C.text
	end
	page.card:Hide()
	local tone = UI.PAPER_TONE[paper.material] or UI.PAPER_TONE.Parchment
	local files, spread = paper.files, paper.spread
	if paper.pieces then
		files, spread = {}, UI.PAPER_PIECES.spread
		for i, def in ipairs(UI.PAPER_PIECES.files) do
			files[i] = { "Interface\\ItemTextFrame\\ItemText-" .. paper.material .. "-" .. def[1], def[2], def[3], def[4], def[5] }
		end
	end
	local w, h
	if paper.atlas then
		local info = C_Texture.GetAtlasInfo(paper.atlas)
		w, h = info.width, info.height
	else
		w, h = spread[1], spread[2]
	end
	local k = max(wide / w, tall / h)
	local left = (wide - w * k) / 2
	if paper.atlas then
		page.paper:SetAtlas(paper.atlas)
		page.paper:ClearAllPoints()
		page.paper:SetPoint("TOPLEFT", page, "TOPLEFT", left, 0)
		page.paper:SetSize(w * k, h * k)
		page.paper:Show()
	else
		for i, def in ipairs(files) do
			local piece = page.pieces[i]
			if not piece then
				piece = page:CreateTexture(nil, "BACKGROUND", nil, -6)
				page.pieces[i] = piece
			end
			piece:SetTexture(def[1])
			piece:ClearAllPoints()
			piece:SetPoint("TOPLEFT", page, "TOPLEFT", left + def[2] * k, -def[3] * k)
			piece:SetSize(def[4] * k, def[5] * k)
			piece:Show()
		end
	end
	-- The feather: the paper's own tone darkened, from the page's edge in.
	local r, g, b = tone[1] * 0.35, tone[2] * 0.35, tone[3] * 0.35
	for _, f in ipairs(page.feather) do
		f:SetGradient(f.way, CreateColor(r, g, b, 0.85 * f.from), CreateColor(r, g, b, 0.85 * f.to))
	end
	return tone, GetMaterialTextColors(paper.material)
end

function UI.PaperPage(parent, opts)
	local feather = opts and opts.feather or 22
	local page = CreateFrame("Frame", nil, parent)
	page:SetClipsChildren(true)
	page.card = page:CreateTexture(nil, "BACKGROUND", nil, -8)
	page.card:SetAllPoints()
	page.line = {}
	for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local edge = page:CreateTexture(nil, "BORDER")
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
		edge:SetColorTexture(1, 1, 1, i == 1 and 0.08 or 0.05)
		page.line[i] = edge
	end
	-- The paper: one picture (an atlas), or pieces laid as one.
	page.paper = page:CreateTexture(nil, "BACKGROUND", nil, -6)
	page.pieces = {}
	for i = 1, 4 do page.pieces[i] = page:CreateTexture(nil, "BACKGROUND", nil, -6) end
	page.feather = {}
	for i, way in ipairs({ { "TOP", "VERTICAL", 0, 1 }, { "BOTTOM", "VERTICAL", 1, 0 }, { "LEFT", "HORIZONTAL", 1, 0 }, { "RIGHT", "HORIZONTAL", 0, 1 } }) do
		local f = page:CreateTexture(nil, "BACKGROUND", nil, -4)
		f:SetColorTexture(1, 1, 1, 1)
		f:SetPoint(way[1])
		if i <= 2 then
			f:SetPoint("LEFT")
			f:SetPoint("RIGHT")
			f:SetHeight(feather)
		else
			f:SetPoint("TOP")
			f:SetPoint("BOTTOM")
			f:SetWidth(feather)
		end
		f.way, f.from, f.to = way[2], way[3], way[4]
		page.feather[i] = f
	end
	page.Lay = PaperLay
	return page
end

-- How a look lifts what stands on its buttons off the face (make.lift): a shadow under the words and a dark copy
-- under each glyph, a unit down and right, this dark; 0: none. Panes over the world (Glass, Frosted) lift most.
local function Lift(make)
	return make.lift or 0.6
end
UI.KeyLift = Lift

-- A glyph's shadow: a dark copy of it under it, following it wherever it stands (its sink too).
local function GlyphShade(glyph)
	local t = glyph.shyShade
	if not t then
		local layer, sub = glyph:GetDrawLayer()
		t = glyph:GetParent():CreateTexture(nil, layer, nil, max(-8, (sub or 0) - 1))
		t:SetPoint("TOPLEFT", glyph, "TOPLEFT", 1, -1)
		t:SetPoint("BOTTOMRIGHT", glyph, "BOTTOMRIGHT", 1, -1)
		glyph.shyShade = t
	end
	-- Its picture as the glyph's is now (a file, or an atlas), turned and cut as it is.
	local atlas = glyph.GetAtlas and glyph:GetAtlas()
	if type(atlas) == "string" and atlas ~= "" then
		t:SetAtlas(atlas)
	else
		t:SetTexture(glyph:GetTexture())
		t:SetTexCoord(glyph:GetTexCoord())
	end
	local turn = glyph.GetRotation and glyph:GetRotation()
	if type(turn) == "number" then t:SetRotation(turn) end
	return t
end

-- The glyphs on a keyed piece lifted off its face as its make says: each its dark copy. (Its words take the
-- theme's text effect, as all words do.)
local function Lifted(make, glyphs, shown)
	local a = Lift(make)
	for _, glyph in ipairs(glyphs or {}) do
		if a > 0 or glyph.shyShade then
			local t = GlyphShade(glyph)
			t:SetVertexColor(0, 0, 0, a)
			t:SetShown(a > 0 and glyph:IsShown() and shown ~= false)
		end
	end
end
UI.KeyLifted = Lifted

-- The gloss's strength in a make (true: the family's own).
function UI.KeyGloss(make)
	return type(make.gloss) == "number" and make.gloss or 0.18
end

-- The edge's color in a make, lit or at rest (rim: the control's edge at rest, toned by the look).
function UI.KeyRim(make, hot, rim)
	if hot and make.hot then return C.hot end
	if make.rim == "white" then return KEY.WHITE end
	if make.rim == "dark" then return KEY.DARK end
	return ToneBorder(rim or Theme.skin.metal)
end

-- A make's hover (make.hover), its own way of saying "live, click me": a wash of `color` coming over the face at
-- `lift` (the frost whitening, the leather lifting, the pane brightening), the light along its top rising to
-- `light`, the brushed sheen to `sheen`, the halo to `halo`. Each eased in and out (Fade). Pressed and on are
-- their own: held pushes the face in, on is lit steady (the hot edge, the accent's wash) and not lifted.
function UI.KeyHover(make)
	return make.hover or KEY.HOVER
end
end

-- The marks a make wears for a state, on a plated piece (plate false: a bare one at rest, none shown): lit (under
-- the mouse or on), over (under the mouse), held, the primary. A tone (a meaning color) keeps its own edge: the
-- caller tints it.
local function Marks(f, make, plate, lit, down, primary, now, over)
	f.shyPlate = plate
	local hover = UI.KeyHover(make)
	local s = f.shyButton
	local hb = s and s.blend and s.blend.hov or ((plate and over and not down and not (s and s.on)) and 1 or 0)
	local pb = s and s.blend and s.blend.press or ((plate and down and not make.own) and 1 or 0)
	-- The hover's lift over the face (a slice of the face's own shape), eased.
	if f.lift then
		local liftA = (hover.lift or 0) * hb * (1 - pb)
		if primary and not tone and liftA > 0 then liftA = min(0.22, liftA * 1.35) end
		if liftA > 0 then HoverVertex(f.lift, hover.color or KEY.WHITE) end
		f.lift:SetShown(plate and not make.own and liftA > 0.004)
		f.lift:SetAlpha(liftA)
	end
	if f.face then
		f.face:SetShown(plate and f.shyKeyMake == make and (make.grain or make.brushed or make.frost) ~= nil)
		if make.grain then f.face:SetVertexColor(1, 1, 1, make.grain * (primary and 0.5 or 1))
		elseif make.frost then f.face:SetVertexColor(1, 1, 1, make.frost)
		else f.face:SetVertexColor(1, 1, 1, 1) end
	end
	-- The brushed sheen: moving up as the light catches it under the mouse.
	if f.sheen then
		local sheenRest, sheenPeak = KEY.SHEEN, hover.sheen or KEY.SHEEN
		local sheenA = sheenRest + (sheenPeak - sheenRest) * hb * (1 - pb)
		f.sheen:SetShown(plate and make.brushed == true)
		f.sheen:SetAlpha(sheenA)
	end
	if f.footBand then f.footBand:SetShown(plate and make.foot ~= nil) end
	if f.inset then
		f.inset:SetShown(plate and not make.own and (down or pb > 0.004))
		f.inset:SetAlpha(down and pb or 0)
	end
	-- The light round it: up under the mouse, steadier while on, full on a primary that wears it.
	if f.halo then
		f.halo:SetShown(make.halo == true)
		local full = primary and make.prime == "halo"
		local haloA = 0
		if plate and make.halo then
			if full then
				haloA = 1
			else
				local idle = (lit and not down and 0.35) or (primary and 0.35) or (down and 0.3) or 0
				local peak = hover.halo or 0.6
				haloA = idle + (peak - idle) * hb * (1 - pb) + (0.3 - idle) * pb
			end
		end
		f.halo:SetAlpha(haloA)
	end
	-- Brackets: lit in the hot color, at rest (a make that keeps them) dim in the steel.
	if f.shyBrackets then
		local hot = lit or primary
		for _, t in ipairs(f.shyBrackets) do
			t:SetShown(plate and make.trim == "bracket" and (hot or make.bracketRest ~= nil))
			if hot then Theme.Tint(t, C.hot, 1) else Theme.Tint(t, Theme.skin.metal, make.bracketRest or 0) end
		end
	end
	Studs(f)
	if make.mark then make.mark(f, plate and lit, plate and down, primary) end
end

-- A keyed piece's edge and marks for a state, whoever paints the rest (a key of Talk's): lit (under the mouse or
-- chosen), held, the primary; rim its edge's color at rest.
function UI.KeyMarks(f, lit, down, primary, rim, now)
	local make = KeyDress(f)
	Theme.Tint(f.edge, UI.KeyRim(make, lit or primary, rim))
	f.gloss:SetShown(make.gloss and not make.own and true or false)
	f.gloss:SetAlpha(UI.KeyGloss(make))
	-- A make of the game's own art is its face and edge.
	f.fill:SetShown(not make.own)
	f.edge:SetShown(not make.own)
	Marks(f, make, true, lit, down, primary, now, lit)
end

-- A plated button's whole state, painted. Lit: under the mouse (its own hover, or a hot edge someone's hover
-- gave it) or on. The ink: the fill's on the primary, the tone's in a tone, the head's lit; at rest the
-- words keep the text ink (or anyone's own) and a glyph the dim one.
function KeyLook(b, now)
	local s = b.shyButton
	local make = KeyDress(b)
	local live = b:IsEnabled() and not b.dimmed
	local over = live and (s.over or s.rim == C.hot)
	local lit, down = over or s.on, live and s.down
	local primary, tone = s.fill == C.fill, s.tone
	-- Bare: the plate only while lit or held.
	local plate = not s.bare or lit or down or false
	s.blend = s.blend or { hov = 0, press = 0 }
	local hovTarget = (plate and not tone and not make.own and over and not down and not s.on) and 1 or 0
	local pressTarget = (plate and down and not make.own and not tone) and 1 or 0
	EaseBlend(s, "hov", hovTarget, now)
	EaseBlend(s, "press", pressTarget, now)
	local hb, pb = s.blend.hov, s.blend.press
	if tone then
		local face = Shade(tone, lit and 0.36 or 0.24)
		local held = Shade(tone, 0.17)
		if pb <= 0 then Theme.Tint(b.fill, face, 1)
		elseif pb >= 1 then Theme.Tint(b.fill, held, 1)
		else
			local r0, g0, b0 = Color(face)
			local r1, g1, b1 = Color(held)
			b.fill:SetVertexColor(r0 + (r1 - r0) * pb, g0 + (g1 - g0) * pb, b0 + (b1 - b0) * pb, 1)
		end
		Theme.Tint(b.edge, lit and Pale(tone, 0.6) or tone)
	else
		Theme.Tint(b.fill, KeyFacePress(make, s.fill, primary, pb))
		local rim = (s.rim == C.border or s.rim == C.hot) and Theme.skin.metal or s.rim
		Theme.Tint(b.edge, UI.KeyRim(make, lit or primary, rim))
	end
	b.gloss:SetAlpha(UI.KeyGloss(make) / (1 + 2 * pb))
	-- (A make of the game's own art is its face and edge: ours stand down, its wash with them.)
	local ours = plate and not make.own
	b.fill:SetShown(ours)
	b.gloss:SetShown(ours and make.gloss and true or false)
	b.edge:SetShown(ours)
	Marks(b, make, plate, lit and not tone, down, primary and not tone, now, over and not tone)
	-- The primary's own way: its color as light in a clear pane (a stronger wash), or as the light round a slab
	-- (no wash, no light along its top: the slab stays dark). On: the accent's wash steady; under the mouse a lighter
	-- one, the hover's lift and light doing the rest; held, a little.
	local prime = primary and not tone and make.prime
	local hover = UI.KeyHover(make)
	local function washRest()
		if tone or make.own then return 0 end
		if not primary then return s.on and 0.14 or 0 end
		if prime == "light" then return 0.4 end
		if prime == "halo" then return 0 end
		return s.on and 0.1 or 0
	end
	local function washAt(o, d)
		if tone or make.own then return 0 end
		if d then return 0.08 end
		local rest = washRest()
		if not o then return rest end
		-- Primary (Setup's Next, and the like): resting wash must not swallow hover; halo slabs and glass panes
		-- both need a clear under-mouse read on gradient themes.
		if primary and prime == "light" then return 0.52 end
		if primary and prime == "halo" then return 0.12 end
		return max(rest, 0.08)
	end
	local washIdle, washHov, washPress = washAt(false, false), washAt(true, false), washAt(true, true)
	local washTo = washIdle + (washHov - washIdle) * hb * (1 - pb) + (washPress - washIdle) * pb
	if washTo > 0.004 and not tone and not make.own then WashVertex(s.wash) end
	s.wash:SetAlpha(washTo)
	local rest = plate and not down and not tone and make.rest or 0
	local top = prime == "halo" and 0 or 0.9
	local function lightAt(o, d)
		-- (a make of the game's own art lights itself, its highlight: ours would lie on its bevel as a second rim)
		if make.own then return 0 end
		if primary and not tone then
			if prime == "halo" then
				if d then return 0.45 end
				return o and 0.38 or 0
			end
			return d and 0.45 or top
		end
		if o and not d and not tone then return max(rest, hover.light or 0.4) end
		if s.on and not d and not tone then return 0.3 end
		return rest
	end
	local lightIdle, lightHov, lightPress = lightAt(false, false), lightAt(true, false), lightAt(true, true)
	local lightTo = lightIdle + (lightHov - lightIdle) * hb * (1 - pb) + (lightPress - lightIdle) * pb
	if lightTo > 0.004 and b.light.shyTintBeforeFade then b.light.shyTintBeforeFade() end
	b.light:SetAlpha(lightTo)
	-- The ink, held to read on the face as it is seen (the contrast floor): the words at a label's, a glyph at a
	-- glyph's, whatever the accent or the ramp where the button stands.
	local face = tone and (down and Shade(tone, 0.17) or Shade(tone, lit and 0.36 or 0.24)) or KeyFace(make, s.fill, primary, down)
	local seen = UI.KeySeen(b, face, washTo + (over and not down and (hover.lift or 0) or 0))
	-- The side its ink keeps (light or dark), as its face is seen at rest: every state keeps it.
	local still = tone and Shade(tone, 0.24) or KeyFace(make, s.fill, primary, false)
	local polar = UI.KeyPolar(UI.KeySeen(b, still, prime == "light" and 0.4 or 0))
	local dyed = prime and prime ~= "fill" and UI.KeyFloor(C.head, face, Theme.LC_LABEL, polar) or nil
	local ink = (primary and (dyed or C.onFill)) or tone or s.mark or (lit and C.head) or nil
	if s.words and Ours(s.words, s.ink) then
		s.ink = plate and UI.KeyFloor(ink or C.text, seen, Theme.LC_LABEL, polar) or (ink or C.text)
		Theme.Ink(s.words, s.ink)
	end
	-- Its words in the theme's text effect, at least a shadow where the look lifts what stands on its buttons
	-- (again only when the look changed).
	if s.words and s.lettered ~= b.shyKeyLook then
		s.lettered = b.shyKeyLook
		Theme.Letter(s.words, { least = UI.KeyLift(make) > 0 and "shadow" or false })
	end
	-- (A bare piece at rest shows no face: its glyphs stand on what is behind them, in the ink their owner gave.)
	for _, glyph in ipairs(s.glyphs) do
		local mark = ink or s.rest or C.dim
		Theme.Tint(glyph, plate and UI.KeyFloor(mark, seen, KEY.GLYPH_LC, polar) or mark)
	end
	UI.KeyLifted(make, s.glyphs, plate or not s.bare)
	Sink(s, down)
	if b.OnLook then b:OnLook(s) end
end

-- UI.KeyPress: the family's button make and its states on a button of your own making: the plated twin of
-- UI.Press, with its interface (b.shyPress, b:SetOn, b:OnLook(state), sink).
--   UI.KeyPress(button, opts)   -- opts: fill (C.bgHot; C.fill is the primary), tone (a meaning color),
--                               --       words = the font string it inks, glyphs = { texture, ... } it tints,
--                               --       sink = { region, ... } held down a unit by a press
--   b:SetOn(on)                 -- lit while on (its menu open, its choice made)
--   b:SetPrimary(on)   b:SetTone(color or nil)   -- the whole button in a meaning color (a merchant's gold)
--   b:SetMark(color or nil)     -- its words and glyphs alone in a meaning color (bags changed since sorted)
--   b:SetBare(on)               -- the plate only while lit or held (a glyph in a strip)
--   b:SetRest(color)            -- its glyphs' ink at rest (C.dim)
function UI.KeyPress(b, opts)
	opts = opts or {}
	UI.Keyed(b)
	local s = { fill = opts.fill or C.bgHot, rim = C.border, tone = opts.tone, words = opts.words,
		glyphs = opts.glyphs or {}, sink = opts.sink or {}, step = 0, on = false, blend = { hov = 0, press = 0 }, _btn = b }
	s.wash = KeySliced(b, UI.KEY_FACE, "ARTWORK", 1)
	Theme.Tint(s.wash, Theme.AccentSolid)
	s.wash:SetAlpha(0)
	b.shyButton, b.shyPress, b.shyFill = s, s, s.fill
	b:HookScript("OnEnter", function(self) s.over = true; KeyLook(self) end)
	b:HookScript("OnLeave", function(self) s.over = false; KeyLook(self) end)
	b:HookScript("OnMouseDown", function(self) s.down = true; KeyLook(self) end)
	b:HookScript("OnMouseUp", function(self) s.down = false; KeyLook(self) end)
	-- Hidden while hovered or held: no OnLeave or OnMouseUp follows, so clear both.
	b:HookScript("OnHide", function(self)
		s.over, s.down = false, false
		EaseBlend(s, "hov", 0, true)
		EaseBlend(s, "press", 0, true)
		KeyLook(self, true)
	end)
	b:HookScript("OnEnable", function(self) KeyLook(self, true) end)
	b:HookScript("OnDisable", function(self) KeyLook(self, true) end)
	function b:SetOn(on)
		s.on = on == true
		KeyLook(self)
	end
	-- (Each of these sets only what changes: a button asked again for what it has, as a piece refreshing itself
	-- asks, isn't painted again; painted again it flashes.)
	function b:SetPrimary(on)
		local fill = on and C.fill or C.bgHot
		if s.fill == fill then return end
		UI.SetFill(self, fill)
	end
	function b:SetTone(c)
		s.tone = c
		KeyLook(self)
	end
	function b:SetMark(c)
		s.mark = c
		KeyLook(self)
	end
	function b:SetBare(on)
		s.bare = on == true
		KeyLook(self, true)
	end
	function b:SetRest(c)
		s.rest = c
		KeyLook(self, true)
	end
	keyed[b] = function(self) KeyLook(self, true) end
	KeyLook(b, true)
	return b
end

-- The make on a button of your own with words in the middle (a secure one: Finish, Reload): b.text made
-- here unless the button has its own.
function UI.ButtonFace(b, text, fill)
	if not b.text then
		b.text = UI.Text(b, text, 13, true)
		b.text:SetPoint("CENTER")
	end
	return UI.KeyPress(b, { fill = fill, words = b.text, sink = { b.text } })
end

function UI.Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 120, 24)
	-- Out of use: the reason, where one was given. (Its own scripts first: the make hooks them.)
	b:SetScript("OnEnter", function(self)
		if not self:IsEnabled() and self.why then UI.Tip(self, self.text:GetText(), self.why, { side = "RIGHT" }) end
	end)
	b:SetScript("OnLeave", function(self)
		if self.why then UI.TipHide(self) end
	end)
	b:SetScript("OnClick", function(self)
		Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		onClick(self)
	end)
	UI.ButtonFace(b, text)
	-- In use or not, and when not, why: a hover on the dimmed button says so.
	function b:SetUsable(on, why)
		on = on and true or false
		self.why = (not on and why) or nil
		if self:IsEnabled() ~= on then self:SetEnabled(on) end
		local alpha = on and 1 or 0.4
		if self:GetAlpha() ~= alpha then self:SetAlpha(alpha) end
		if not self.shyMotion then
			self.shyMotion = true
			self:SetMotionScriptsWhileDisabled(true)
		end
	end
	-- The words fit the button: cut with an ellipsis past its edges, never spilling.
	function b:SetLabel(text)
		text = text or ""
		local wide = self:GetWidth() - 12
		if self.shyLabel == text and self.shyLabelWide == wide and self.text:GetText() == text then return end
		self.shyLabel, self.shyLabelWide = text, wide
		self.text:SetText(text)
		self.text:SetWidth(wide)
		self.text:SetWordWrap(false)
		self.text:SetJustifyH("CENTER")
	end
	-- Its width is its place in a row: in a wider font its words are cut to it, never spilling past.
	UI.KeyWords(b, function(self)
		local room = self:GetWidth() - 12
		local wide = self.text:GetStringWidth()
		if issecretvalue(wide) or issecretvalue(room) or not wide or wide <= room then return end
		self:SetLabel(self.text:GetText())
	end)
	return b
end

-- A click that must be meant: the first shows "Sure?" for a few seconds, the second does it.
function UI.Twice(button, fn)
	local asking = 0
	-- Back to the button's own words, and its own width where "Sure?" needed more.
	local function Settle(self)
		if self.sure then self.text:SetText(self.sure) end
		if self.wasWide then
			self:SetWidth(self.wasWide)
			self.wasWide = nil
		end
	end
	button:SetScript("OnClick", function(self)
		if self.dimmed or not self:IsEnabled() then return end
		Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		if GetTime() < asking then
			asking = 0
			Settle(self)
			fn(self)
			return
		end
		self.sure = self.text:GetText()
		asking = GetTime() + 4
		self.text:SetText("Sure?")
		-- A narrow button (an "x") grows to hold the word while it asks (and again in another font).
		local function Hold(b)
			if GetTime() >= asking then return end
			local need = b.text:GetStringWidth() + 12
			if need > b:GetWidth() then
				b.wasWide = b.wasWide or b:GetWidth()
				b:SetWidth(need)
			end
		end
		Hold(self)
		UI.KeyWords(self, Hold, "sure")
		C_Timer.After(4, function()
			if GetTime() >= asking then Settle(self) end
		end)
	end)
end

-- Checkbox

-- A keyed box (UI.Keyed), as a button is made. Empty, a sunk well in a steel edge; checked, the accent's deep
-- shade in the hot edge, lit along its top, the check drawn in light. Under the mouse the edge goes hot and
-- the accent washes over the box. opts.box: the box's size (18); opts.size: the label's text size (the
-- default). A smaller box takes a smaller check and gap, for a checkbox on a plate in a corner.
function UI.Checkbox(parent, label, get, set, opts)
	local size = opts and opts.box or 18
	local gap = size < 18 and 6 or 8
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(size + 2)
	local box = CreateFrame("Frame", nil, b)
	box:SetSize(size, size)
	box:SetPoint("LEFT")
	UI.Keyed(box)
	local wash = KeySliced(box, UI.KEY_FACE, "ARTWORK", 1)
	Theme.Tint(wash, Theme.AccentSolid)
	wash:SetAlpha(0)
	wash.shyTintBeforeFade = function() WashVertex(wash) end
	local check = box:CreateTexture(nil, "OVERLAY")
	check:SetTexture(Shy.MEDIA .. (size < 16 and "GlyphCheckS" or "GlyphCheck"))
	check:SetSize(size - 4, size - 4)
	check:SetPoint("CENTER")
	Theme.Tint(check, C.onFill)
	b.check = check
	b.text = UI.Text(b, label, opts and opts.size)
	b.text:SetPoint("LEFT", box, "RIGHT", gap, 0)
	b:SetWidth(size + gap + b.text:GetStringWidth())
	UI.KeyWords(b, function(self) self:SetWidth(size + gap + self.text:GetStringWidth()) end)

	-- on: as get() last answered (made empty: it is asked from the first Refresh on).
	local over, on = false, false
	local function Look(now)
		local hot = over and not b.dimmed
		Theme.Tint(box.fill, on and ToneFill(C.fill) or Held(C.bg), 1)
		Theme.Tint(box.edge, (on or hot) and C.hot or ToneBorder(Theme.skin.metal))
		box.gloss:SetAlpha(on and 0.18 or 0.08)
		box.gloss:SetShown(UI.LookGloss())
		-- The light along a checked box's top is shown or hidden, as the check is (below).
		box.light:SetAlpha(0.9)
		box.light:SetShown(on)
		-- A tint sets a texture's alpha with its color: the wash is tinted at the alpha it has, and only the
		-- fade moves it.
		if hot then
			local a = wash:GetAlpha()
			WashVertex(wash)
			wash:SetAlpha(a)
		end
		Fade(wash, hot and (on and 0.1 or 0.16) or 0, now)
		-- The check is shown or hidden, always at full strength: the game drew one brought up from clear only
		-- once the box was drawn again (the mouse over it, or any box of its list ticked). (Ticking is a
		-- Refresh: nothing to ease.)
		Theme.Tint(check, C.onFill, 1)
		check:SetShown(on)
	end
	-- What it is set to shows at once: a page coming up is no change to ease in. Only the mouse eases.
	function b:Refresh()
		on = get() == true
		SetDimmed(self, not IsEnabled(opts))
		Look(true)
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		set(not get())
		Sound(get() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
		self:Refresh()
	end)
	b:SetScript("OnEnter", function()
		over = true
		Look()
	end)
	b:SetScript("OnLeave", function()
		over = false
		Look()
	end)
	AttachHelp(b, label, opts)
	keyed[b] = function() Look(true) end
	Look(true)
	return b
end

-- Slider: a rounded groove the whole width, the amount in the bars' fill in the accent running to the
-- knob's middle, and a round steel knob with the accent's dot in it, which lights and glows under the
-- mouse and glows brighter while held. The label at the left, the value at the right. The wheel steps it.
-- opts.color: a color (or a function giving one) for the fill, the dot and the glow instead of the accent,
-- read again on every Refresh (a color being made, shown as it is dragged).
-- opts.settle(value): called as the knob is let go and after a wheel step. A slider that sizes or lays out a
-- piece of the screen takes its value there, and only remembers it in `set` (with `get` giving that back while
-- the knob is held): a piece laid out again at every step jumps about under the knob, and takes the slider
-- with it where the slider stands by the piece. A slider that only paints (a color, an opacity) stays live.

local SLIDER = {
	trackH = 8,
	fillH = 6,
	knob = 18,  -- the groove, the fill in it, the knob's diameter
	knobArt = 26,
	dot = 8,
	halo = 44,
	fillMask = 512,  -- the pictures' sizes (the knob's holds its shadow)
}

function UI.Slider(parent, label, minV, maxV, step, get, set, opts)
	opts = opts or {}
	local width = opts.width or 260
	local fmt = opts.format or function(v) return tostring(v) end

	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 38)
	f.label = UI.Text(f, label)
	f.label:SetPoint("TOPLEFT")
	f.value = UI.Text(f, "", 13, true, C.head)
	f.value:SetPoint("TOPRIGHT")

	local s = CreateFrame("Slider", nil, f)
	s:SetPoint("BOTTOMLEFT", 0, 1)
	s:SetSize(width, SLIDER.knob)
	s:SetOrientation("HORIZONTAL")
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(true)
	f.slider = s

	-- The groove: the slider's whole width, under the label and the value, its ends round.
	local track = CreateFrame("Frame", nil, s)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(SLIDER.trackH)
	local cap = SLIDER.trackH / 2
	local function Groove(l, r)
		local t = track:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(Shy.MEDIA .. "SliderTrack")
		t:SetTexCoord(l, r, 0, 1)
		Theme.Tint(t, Theme.skin.inset, 1)
		return t
	end
	local left, right, middle = Groove(0, 0.25), Groove(0.75, 1), Groove(0.25, 0.75)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(cap)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(cap)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	-- The fill: the bars' fill in the accent, a unit in from the groove's edge, round at its left end and
	-- cut at the knob's middle (the knob covers the cut).
	local inset = (SLIDER.trackH - SLIDER.fillH) / 2
	local clip = CreateFrame("Frame", nil, track)
	clip:SetPoint("TOPLEFT", inset, -inset)
	clip:SetPoint("BOTTOMLEFT", inset, inset)
	clip:SetClipsChildren(true)
	local fill = clip:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT")
	fill:SetPoint("BOTTOMLEFT")
	fill:SetWidth(width - 2 * inset)
	Shy.Skin.Hatch(fill)
	Theme.Tint(fill, Theme.Accent, 1)
	local round = clip:CreateMaskTexture()
	round:SetTexture(Shy.MEDIA .. "SliderMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	round:SetSize(SLIDER.fillMask, SLIDER.fillH)
	round:SetPoint("LEFT", fill, "LEFT")
	fill:AddMaskTexture(round)

	-- The knob: the slider moves an unseen thumb; the knob, its glow and its dot stand on it, above the groove.
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(SLIDER.knob, SLIDER.knob)
	thumb:SetColorTexture(1, 1, 1, 0)
	s:SetThumbTexture(thumb)
	local over = CreateFrame("Frame", nil, s)
	over:SetAllPoints()
	over:SetFrameLevel(track:GetFrameLevel() + 2)
	local function Piece(file, size, layer)
		local t = over:CreateTexture(nil, layer)
		t:SetTexture(Shy.MEDIA .. file)
		t:SetSize(size, size)
		t:SetPoint("CENTER", thumb, "CENTER")
		return t
	end
	local halo = Piece("Glow", SLIDER.halo, "BACKGROUND")
	Theme.Tint(halo, Theme.Accent, 1)
	halo:SetAlpha(0)
	local knob = Piece("SliderKnob", SLIDER.knobArt, "ARTWORK")
	Theme.Tint(knob, Theme.skin.metal, 1)
	local dot = Piece("SliderDot", SLIDER.dot, "OVERLAY")
	Theme.Tint(dot, Theme.Accent, 1)
	f.knob, f.dot, f.halo = knob, dot, halo

	local function Snap(v) return floor((v - minV) / step + 0.5) * step + minV end
	local function Show(v)
		f.value:SetText(fmt(v))
		local share = maxV > minV and (v - minV) / (maxV - minV) or 0
		clip:SetWidth(max(1, SLIDER.knob / 2 - inset + share * (width - SLIDER.knob)))
	end
	local hovered, held = false, false
	local function Look()
		local lit = (hovered or held) and not f.dimmed
		Theme.Tint(knob, lit and Theme.skin.lit or Theme.skin.metal, 1)
		halo:SetAlpha(not lit and 0 or (held and 0.7 or 0.45))
	end

	s:SetScript("OnValueChanged", function(_, v)
		v = Snap(v)
		Show(v)
		if not f.refreshing and not f.dimmed and v ~= get() then
			set(v)
		end
	end)
	s:SetScript("OnMouseWheel", function(self, delta)
		if f.dimmed then return end
		self:SetValue(min(maxV, max(minV, get() + delta * step)))
		if opts.settle then opts.settle(Snap(self:GetValue())) end
	end)
	s:SetScript("OnEnter", function() hovered = true; Look() end)
	s:SetScript("OnLeave", function() hovered = false; Look() end)
	-- opts.settle(value): the knob let go (or a wheel step), for a value that is taken once it rests: one whose
	-- taking moves the slider itself or lays a piece of the screen out again, which a knob in the hand must not.
	-- The game doesn't always tell a frame the mouse was let go of off it, so the screen's own word ends a hold
	-- too; whichever comes first settles it, once.
	local settled = false
	local function Let(self)
		self:UnregisterEvent("GLOBAL_MOUSE_UP")
		held = false
		Look()
	end
	local function Settle(self)
		if opts.settle and not f.dimmed then opts.settle(Snap(self:GetValue())) end
	end
	s:SetScript("OnMouseDown", function(self)
		held, settled = true, false
		if opts.settle then self:RegisterEvent("GLOBAL_MOUSE_UP") end
		Look()
	end)
	s:SetScript("OnMouseUp", function(self)
		Let(self)
		if settled then
			settled = false
			return
		end
		Settle(self)
	end)
	s:SetScript("OnEvent", function(self)
		if not held then return end
		Let(self)
		settled = true
		Settle(self)
	end)
	-- Hidden in the hand: nothing was let go of, so nothing is taken.
	s:SetScript("OnHide", function(self)
		if held then Let(self) end
	end)

	-- A color of its own (before Look: a tint sets the glow's alpha, Look sets it back).
	local function Color()
		if not opts.color then return end
		for _, t in ipairs({ fill, halo, dot }) do Theme.Tint(t, opts.color, 1) end
	end
	Color()
	Look()

	function f:Refresh()
		self.refreshing = true
		s:SetValue(get())
		Show(get())
		self.refreshing = false
		SetDimmed(self, not IsEnabled(opts))
		s:EnableMouse(not self.dimmed)
		Color()
		Look()
	end
	AttachHelp(s, label, opts)
	return f
end

-- UI.Press: hover, pressed and on states for a flat button. Each state has its own channel so none
-- hides another: hover lifts the fill and shows an accent line down the left edge, a press darkens
-- the fill and shifts the content by one unit, and "on" keeps the fill and the line.
--
--   UI.Press(button, opts)   -- opts: fill = resting color (C.bg)
--                            --       bare = true: no background unless hovered or on
--                            --       sink = { region, ... }: regions shifted by a press (one anchor point each)
--   button:SetOn(true)
--   button:OnLook(state)     -- optional callback on every change: state.over, .down, .on

local function PressLook(b)
	local s = b.shyPress
	local live = not b.dimmed
	local over, down = s.over and live, s.down and live
	local plate = not s.bare or over or s.on
	b.shyBg:SetShown(plate)
	for _, e in ipairs(b.shyEdges) do e:SetShown(plate) end
	-- On: a menu's fill and edge, so an open menu reads as one piece with its button.
	if down then
		b.shyBg:SetColorTexture(0.03, 0.03, 0.03, 1)
	elseif s.on then
		Theme.Paint(b.shyBg, C.panel, 1)
	else
		UI.SetFill(b, over and C.bgHot or s.fill)
	end
	if s.on or over then
		for _, e in ipairs(b.shyEdges) do Theme.Paint(e, Theme.skin.metal, s.on and 0.6 or 0.45) end
	else
		UI.SetBorder(b, C.border)
	end
	s.line:SetShown(s.on or over or false)
	local step = down and 1 or 0
	if step ~= s.step then
		for _, region in ipairs(s.sink) do
			local point, to, toPoint, x, y = region:GetPoint(1)
			region:SetPoint(point, to, toPoint, x + step - s.step, y - step + s.step)
		end
		s.step = step
	end
	if b.OnLook then b:OnLook(s) end
end

function UI.Press(b, opts)
	opts = opts or {}
	local fill = opts.fill or C.bg
	if not b.shyBg then UI.Skin(b, fill) end
	local s = { fill = fill, bare = opts.bare, sink = opts.sink or {}, step = 0, on = false }
	b.shyPress = s
	s.line = b:CreateTexture(nil, "OVERLAY")
	s.line:SetPoint("TOPLEFT", 1, -1)
	s.line:SetPoint("BOTTOMLEFT", 1, 1)
	s.line:SetWidth(2)
	Theme.Paint(s.line, Theme.Accent)
	b:HookScript("OnEnter", function(self) s.over = true; PressLook(self) end)
	b:HookScript("OnLeave", function(self) s.over = false; PressLook(self) end)
	b:HookScript("OnMouseDown", function(self) s.down = true; PressLook(self) end)
	b:HookScript("OnMouseUp", function(self) s.down = false; PressLook(self) end)
	-- Hidden while hovered or pressed: no OnLeave or OnMouseUp follows, so clear both.
	b:HookScript("OnHide", function(self) s.over, s.down = false, false; PressLook(self) end)
	function b:SetOn(on)
		s.on = on == true
		PressLook(self)
	end
	PressLook(b)
	return b
end

-- UI.Menu: the one list every dropdown, picker and context menu opens.
--
--   UI.Menu(owner, items, opts)   -- opens at `owner`; called again by the same owner, it closes
--   UI.CloseMenu()                -- also closed by a click elsewhere, Esc, or the owner hiding
--   UI.MenuOwner()                -- owner of the open menu, or nil
--
-- `items` is a list, or a function returning one (called each time it opens):
--   { text = "Bank", click = function(item, owner) end }
--       detail = "1 free"       dim text at the row's right
--       sub = "Rogue, 24"       second, dimmer line
--       icon = file             on the left. A list of files is layered; { file, color } tints one,
--                               { atlas = name } uses an atlas, { coords = { l, r, t, b } } crops.
--                               iconText is written over it (initials)
--       color = { r, g, b }     text color; iconText takes it too
--       font = file             text font (a list of fonts)
--       on = true               current pick or checked state (may be a function)
--       disabled = true
--       keep = true             the menu stays open after the click
--       tip = "..."             hover text beside the menu
--       enter = function(item, row)   the mouse came onto the row (a pick shown before it is made)
--       items = { ... }         a submenu, opened in place with a back row
--       secure = { ... }        see "Secure rows"
--   { heading = "ShyBags" }
--   { divider = true }
-- `opts`:
--   width    minimum width (it grows to fit its text)
--   fit      true: at least as wide as its owner
--   side     "below" (default; flips above without room), "above", "right", "cursor"
--   align    "RIGHT": right edges aligned
--   join     true: its outline merges with the owner's (a UI.Press button)
--   at       frame to anchor to instead of the owner
--   rows     rows shown before it scrolls (12)
--   font     font object for the rows (UI.NameFont(11))
--   icon     icon slot size (16); `art`: drawn icon size (the same)
--   foot     a last line under a rule; a function returns left text, right text
--   keepOn   "RightButton": presses of that button elsewhere don't close it
--   onShow, onHide   function(owner)

-- The glyphs a menu row wears on its rail (MenuGlyphs.tga: 32px cells, eight across, drawn for a row's
-- 16 units at two texels a unit; this list is the sheet's cells, in their order).
--   UI.MenuGlyph(name, color)   the glyph as an entry's icon (entry:SetIcon): one layer, cropped, in a color
UI.MENU_GLYPHS = { "route", "group", "log", "guide", "shows", "errands", "options", "window",
	"point", "done", "skip", "back", "later", "link", "track", "share",
	"help", "abandon", "first", "hide", "lock", "size", "center", "reset", "info", "sword", "sum", "clock",
	"heal", "action" }
local MENU_CELL, MENU_ACROSS = {}, 8
for index, name in ipairs(UI.MENU_GLYPHS) do MENU_CELL[name] = index - 1 end
local MENU_ROWS = math.ceil(#UI.MENU_GLYPHS / MENU_ACROSS)

function UI.MenuGlyph(name, color)
	local cell = MENU_CELL[name] or MENU_CELL.log
	local col, row = cell % MENU_ACROSS, math.floor(cell / MENU_ACROSS)
	return { { Shy.MEDIA .. "MenuGlyphs", color or C.dim,
		coords = { col / MENU_ACROSS, (col + 1) / MENU_ACROSS, row / MENU_ROWS, (row + 1) / MENU_ROWS } } }
end

local MENU = {
	pad = 3,                          -- inside the edge
	row = 20, tall = 32,              -- row height; with a sub line
	head = 17, rule = 7,              -- heading; divider
	icon = 16, inset = 8, gap = 7,    -- icon size; padding at a row's ends; between its parts
	check = 10,
	rows = 16, min = 120, max = 440,  -- rows before a list scrolls; a menu's least and most width
	fade = 0.12,                      -- fade-in seconds
	edge = 2,                         -- outline: a black line, then a steel one
	rail = 22,                        -- dark rail down the left for icons and the check (wider for bigger icons)
	foot = 20,
}
local menu   -- the one menu frame, created on first use

-- Esc closes only the menu, not the window under it. Key propagation can't be changed in combat,
-- so this frame hides there and Esc closes the window (and the menu with it).
local menuKeys = CreateFrame("Frame", nil, UIParent)
menuKeys:SetSize(1, 1)
menuKeys:SetPoint("TOPLEFT")
menuKeys:Hide()
menuKeys:EnableKeyboard(true)
menuKeys:SetScript("OnKeyDown", function(self, key)
	if key == "ESCAPE" then
		self:SetPropagateKeyboardInput(false)
		UI.CloseMenu()
	else
		self:SetPropagateKeyboardInput(true)
	end
end)
menuKeys:RegisterEvent("PLAYER_REGEN_DISABLED")
menuKeys:SetScript("OnEvent", function(self) self:Hide() end)

local function IsOn(item)
	local on = item.on
	if type(on) == "function" then on = on(item) end
	return on and true or false
end

-- Hover: lifted fill plus an accent wash fading to the right. Pressed: dark, content shifted one unit.
-- On: its stretch of the left line lit, a fainter wash, and a check when the row has no icon.
local function MenuRowLook(row)
	local item = row.item
	local live = not item.disabled
	local over, down = row.over and live, row.down and live
	row.fill:SetShown(over)
	if down then row.fill:SetColorTexture(0.03, 0.03, 0.03, 1) else Theme.Paint(row.fill, C.bgHot, 1) end
	local wash = (down and 0) or (over and row.on and 0.30) or (over and 0.20) or (row.on and 0.12) or 0
	row.wash:SetShown(wash > 0)
	if wash > 0 then
		local r, g, b = Theme.Accent()
		row.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, wash), CreateColor(r, g, b, 0))
	end
	row.light:SetShown(row.on)
	row.check:SetShown(row.on and (not row.led or row.tickRight == true))
	row.more:SetShown(item.items ~= nil)
	row.back:SetShown(item.back == true)
	row.body:SetAlpha(live and 1 or 0.36)
	if live and not item.heading then row.text:SetAlpha((over or row.on) and 1 or 0.84) end
	local step = down and 1 or 0
	row.body:SetPoint("TOPLEFT", step, -step)
	row.body:SetPoint("BOTTOMRIGHT", step, -step)
end

local function MenuRow(index)
	local row = menu.rows[index]
	if row then return row end
	row = CreateFrame("Button", nil, menu.area.content)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")   -- the right button only on rows that ask for it (SetRightClick)
	row.fill = row:CreateTexture(nil, "BACKGROUND")
	row.fill:SetAllPoints()
	row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.wash:SetAllPoints()
	row.wash:SetColorTexture(1, 1, 1, 1)
	row.light = row:CreateTexture(nil, "BORDER")
	row.light:SetPoint("TOPLEFT", 0, -3)
	row.light:SetPoint("BOTTOMLEFT", 0, 3)
	row.light:SetWidth(2)
	Theme.Paint(row.light, Theme.light)
	-- The row's content is on its own frame, which shifts on a press.
	local body = CreateFrame("Frame", nil, row)
	row.body = body
	row.rule = body:CreateTexture(nil, "ARTWORK")
	row.rule:SetHeight(1)
	Theme.Paint(row.rule, C.border, 0.9)
	row.art = {}
	row.iconText = body:CreateFontString(nil, "OVERLAY")
	row.iconText:SetFontObject(UI.NameFont(9))
	row.iconText:SetShadowColor(0, 0, 0, 0)
	row.text = body:CreateFontString(nil, "OVERLAY")
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)
	Theme.Wear(row.text)
	row.sub = UI.Words(body, UI.NameFont(10), nil, { wrap = false })
	Theme.Ink(row.sub, C.dim)
	row.detail = UI.Words(body, 10.5, nil, { justify = "RIGHT" })
	row.check = body:CreateTexture(nil, "ARTWORK")
	row.check:SetTexture(Shy.MEDIA .. "GlyphCheckS")   -- the check drawn for 12 units and under
	row.check:SetSize(MENU.check, MENU.check)
	Theme.Tint(row.check, Theme.light)

	row:SetScript("OnEnter", function(self)
		self.over = true
		MenuRowLook(self)
		local item = self.item
		if item.tip then UI.Tip(self, item.text or "", item.tip, { side = "RIGHT" }) end
		if item.enter then item.enter(item, self) end
	end)
	row:SetScript("OnLeave", function(self)
		self.over, self.down = false, false
		MenuRowLook(self)
		if self.item and self.item.tip then UI.TipHide(self) end
	end)
	row:SetScript("OnMouseDown", function(self) self.down = true; MenuRowLook(self) end)
	row:SetScript("OnMouseUp", function(self) self.down = false; MenuRowLook(self) end)
	-- Submenu caret at the right; back caret at the left.
	row.more = body:CreateTexture(nil, "ARTWORK")
	row.more:SetTexture(Shy.MEDIA .. "GlyphCaret")
	row.more:SetSize(10, 10)
	row.more:SetPoint("RIGHT", -MENU.inset, 0)
	row.more:SetRotation(math.pi / 2)
	Theme.Tint(row.more, C.dim)
	row.back = body:CreateTexture(nil, "ARTWORK")
	row.back:SetTexture(Shy.MEDIA .. "GlyphCaret")
	row.back:SetSize(10, 10)
	row.back:SetRotation(-math.pi / 2)
	Theme.Tint(row.back, C.head)

	row:SetScript("OnClick", function(self, mouseButton)
		local item, owner = self.item, menu.owner
		if item.disabled then return end
		if mouseButton == "RightButton" and not item.anyButton then return end
		Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		-- Submenus replace the list in place.
		if item.items or item.back then
			if item.back then
				menu.source = table.remove(menu.trail)
			else
				menu.trail[#menu.trail + 1] = menu.source
				local list = { { text = item.text, back = true }, { divider = true } }
				for _, child in ipairs(item.items) do list[#list + 1] = child end
				list.rows = item.items.rows
				menu.source = list
			end
			menu:Fill()
			menu.area:SetVerticalScroll(0)
			menu.area:Update()
			return
		end
		-- A secure row is clicked through the secure button over it. In combat that button is hidden
		-- and the row does nothing.
		if item.secure and not item.click then return end
		if not item.keep then UI.CloseMenu() end
		if item.click then item.click(item, owner, mouseButton or "LeftButton") end
		if item.keep and menu:IsShown() and menu.owner == owner then
			menu:Fill()
			-- The row under the mouse may say something else now.
			local now = self.item
			if self.over and now and now.tip then
				UI.Tip(self, now.text or "", now.tip, { side = "RIGHT" })
			elseif self.over and item.tip then
				UI.TipHide(self)
			end
		end
	end)
	menu.rows[index] = row
	return row
end

local function MenuRowArt(row, item, rail, drawn)
	local icon = item.icon
	local layers = type(icon) == "table" and icon or { icon }
	for index, layer in ipairs(layers) do
		local t = row.art[index]
		if not t then
			t = row.body:CreateTexture(nil, "ARTWORK", nil, index)
			row.art[index] = t
		end
		local file, color = layer, nil
		if type(layer) == "table" then file, color = layer[1], layer[2] end
		if type(layer) == "table" and layer.atlas then
			t:SetAtlas(layer.atlas)
		else
			t:SetTexture(file)
			-- Always set the coords: an atlas shown on this texture earlier leaves its crop behind.
			local crop = type(layer) == "table" and layer.coords
			if crop then t:SetTexCoord(crop[1], crop[2], crop[3], crop[4]) else t:SetTexCoord(0, 1, 0, 1) end
		end
		t:SetSize(drawn, drawn)
		t:SetPoint("CENTER", row.body, "LEFT", rail / 2, 0)
		if color then Theme.Tint(t, color) else t:SetVertexColor(1, 1, 1, 1) end
		t:Show()
	end
	for index = #layers + 1, #row.art do row.art[index]:Hide() end
	row.iconText:SetText(item.iconText or "")
	row.iconText:SetPoint("CENTER", row.body, "LEFT", rail / 2, 0)
	Theme.Ink(row.iconText, item.color or C.text)
end

-- A font string's width, with a guess by its letters where the engine has none to give yet (a
-- font family not drawn before measures as nothing, and the row would be cut to the menu's least).
local function StringWidth(fs)
	local width = fs:GetStringWidth()
	if (not width or width == 0) then
		local text = fs:GetText()
		-- Generous: the rounded face's capitals and bold letters run near 7.5 at 11 (a guess of 6 cut "Hide Passives").
		if text and text ~= "" then width = #text * 7.5 end
	end
	return width or 0
end

-- Lays the rows out. Returns total height, needed width, and the y of the first row that is on.
local function MenuRows(items, opts)
	local size = opts.icon or MENU.icon
	local led = false
	for _, item in ipairs(items) do
		if item.icon or item.iconText then led = true end
	end
	local rail = led and max(MENU.rail, size + 10) or MENU.rail
	local textX, tail = rail + MENU.inset, MENU.inset + 2
	local y, wide, onY = 0, 0, nil
	menu.railWidth = rail

	for index, item in ipairs(items) do
		local row = MenuRow(index)
		local plain = not (item.divider or item.heading)
		row.item, row.over, row.down, row.led = item, false, false, led
		row.on = plain and IsOn(item)
		local height = (item.divider and MENU.rule) or (item.heading and MENU.head)
			or max(item.sub and MENU.tall or MENU.row, led and (size + 6) or 0)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -y)
		row:SetPoint("RIGHT")
		row:SetHeight(height)
		row:EnableMouse(plain)
		row.rule:SetShown(item.divider == true)
		row.rule:SetPoint("LEFT", rail, 0)
		row.rule:SetPoint("RIGHT", 0, 0)
		-- A checkbox among rows with pictures keeps its tick, at the row's right end (the rail holds its picture).
		row.tickRight = led and item.keep == true and item.on ~= nil
		row.check:ClearAllPoints()
		if row.tickRight then
			row.check:SetPoint("CENTER", row.body, "RIGHT", -(tail + MENU.check / 2), 0)
		else
			row.check:SetPoint("CENTER", row.body, "LEFT", rail / 2, 0)
		end
		row.back:SetPoint("CENTER", row.body, "LEFT", rail / 2, 0)

		local text = row.text
		text:ClearAllPoints()
		text:SetAlpha(1)
		if item.heading then
			text:SetFontObject(UI.NameFont(9))
			text:SetPoint("BOTTOMLEFT", textX, 3)
			Theme.Ink(text, C.dim)
		else
			if item.font then text:SetFont(item.font, 13, "") else text:SetFontObject(opts.font or UI.NameFont(11)) end
			text:SetPoint("LEFT", textX, item.sub and 6 or 0)
			Theme.Ink(text, item.color or C.text)
		end
		local words = item.heading or item.text or ""
		-- Upper-case a plain heading; one with escape codes is left as written.
		if item.heading and not words:find("|", 1, true) then words = words:upper() end
		text:SetText(words)
		row.sub:SetText(plain and item.sub or "")
		row.sub:SetPoint("LEFT", textX, -7)
		row.detail:SetText(plain and item.detail or "")
		row.detail:SetPoint("RIGHT", -tail, item.sub and 6 or 0)
		Theme.Ink(row.detail, C.dim)

		if plain and (item.icon or item.iconText) then
			MenuRowArt(row, item, rail, opts.art or size)
		else
			for _, t in ipairs(row.art) do t:Hide() end
			row.iconText:SetText("")
		end

		local need = textX + max(StringWidth(text), StringWidth(row.sub)) + tail + (item.items and 14 or 0)
		if plain and item.detail then need = need + MENU.gap * 2 + StringWidth(row.detail) end
		if row.tickRight then need = need + MENU.check + MENU.gap end
		wide = max(wide, need)
		-- The text ends before the detail (and a tick at the right).
		if not item.heading then
			local right = tail + (item.detail and (row.detail:GetStringWidth() + MENU.gap) or 0) + (row.tickRight and MENU.check + MENU.gap or 0)
			text:SetPoint("RIGHT", -right, item.sub and 6 or 0)
		end

		if row.on and not onY then onY = y end
		MenuRowLook(row)
		row:Show()
		y = y + height
	end
	for index = #items + 1, #menu.rows do menu.rows[index]:Hide() end
	return y, wide, onY
end

local function MenuPlace(opts)
	local at = opts.at or menu.owner
	menu:SetScale(at:GetEffectiveScale() / UIParent:GetEffectiveScale())
	menu:ClearAllPoints()
	local side, right = opts.side or "below", opts.align == "RIGHT"
	local accent = menu.accent
	accent:ClearAllPoints()
	accent:SetPoint("TOPLEFT", MENU.edge, -MENU.edge)
	accent:SetPoint("BOTTOMLEFT", MENU.edge, MENU.edge)
	if side == "cursor" then
		local x, y = GetCursorPosition()
		local scale = menu:GetEffectiveScale()
		menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 2, y / scale - 2)
		menu.gap:Hide()
		return
	end
	local height, below = menu:GetHeight(), at:GetBottom() or 0
	if side == "below" and below < height + 6 and (at:GetTop() or 0) > below then side = "above" end
	-- join: the menu overlaps the button's outline and the stretch between them is covered (menu.gap),
	-- so button and menu read as one piece. Otherwise it sits 3 units clear.
	local join = opts.join and not right
	local lap, clear = join and MENU.edge or -3, join and -1 or 0
	local gap = menu.gap
	gap:SetShown(join == true)
	gap:ClearAllPoints()
	if side == "right" then
		-- Down from the owner's top, or up from its bottom when it is low on the screen.
		local up = below < height
		menu:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", at, up and "BOTTOMRIGHT" or "TOPRIGHT", -lap, up and clear or -clear)
		gap:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", 0, up and 2 or -2)
		gap:SetSize(MENU.edge, at:GetHeight() - 2)
	elseif side == "above" then
		menu:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", at, right and "TOPRIGHT" or "TOPLEFT", clear, -lap)
		gap:SetPoint("BOTTOMLEFT", 2, 0)
		gap:SetSize(at:GetWidth() - 2, MENU.edge)
		-- Joined, the accent line runs through into the button's own.
		if join then accent:SetPoint("BOTTOMLEFT", MENU.edge, 0) end
	else
		menu:SetPoint(right and "TOPRIGHT" or "TOPLEFT", at, right and "BOTTOMRIGHT" or "BOTTOMLEFT", clear, lap)
		gap:SetPoint("TOPLEFT", 2, 0)
		gap:SetSize(at:GetWidth() - 2, MENU.edge)
		if join then accent:SetPoint("TOPLEFT", MENU.edge, 0) end
	end
end

-- Secure rows: protected actions (raid markers, pings) are blocked from addon code even on a hardware
-- click, but work from a SecureActionButton. An item may carry that button's attributes:
--   secure = { type = "raidtarget", action = "set", marker = 8, unit = "target" }
--   secure = { type = "macro", macrotext = "/ping [@target] 1" }
-- and a secure button is laid over its row to take the click.
--
-- The buttons are children of UIParent positioned by absolute coordinates, never parented or anchored
-- to the menu: anything a protected frame is anchored to becomes protected, and the menu must stay
-- free to move and hide in combat. They are created, placed and hidden only out of combat, and are
-- hidden at PLAYER_REGEN_DISABLED (which fires just before lockdown); such rows then do nothing
-- until the menu is reopened after combat.
local secureRows = {}

local function SecureRow(index)
	local b = secureRows[index]
	if b then return b end
	b = CreateFrame("Button", "ShyMenuSecureRow" .. index, UIParent, "SecureActionButtonTemplate")
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b:SetFrameLevel(200)   -- above the menu's rows
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:Hide()
	b.set = {}
	-- Forward hover and press to the row under it, for its look.
	local function Tell(script)
		return function(self)
			local row = self.row
			local fn = row and row:GetScript(script)
			if fn then fn(row) end
		end
	end
	b:SetScript("OnEnter", Tell("OnEnter"))
	b:SetScript("OnLeave", Tell("OnLeave"))
	b:HookScript("OnMouseDown", Tell("OnMouseDown"))
	b:HookScript("OnMouseUp", Tell("OnMouseUp"))
	b:SetScript("PostClick", function(self, _, down)
		if down then return end
		Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		local item = self.row and self.row.item
		-- What a secure row does of its own, after the game's action (a tell menu remembering the chat picked).
		if item and item.after then item.after(item, menu and menu.owner) end
		if not (item and item.keep) then UI.CloseMenu() end
	end)
	secureRows[index] = b
	return b
end

local function HideSecureRows(from)
	if InCombatLockdown() then return end
	for index = from or 1, #secureRows do
		local b = secureRows[index]
		b:Hide()
		b.row, b.item, b.at = nil, nil, nil
	end
end

-- Lays a secure button over every visible secure row, at the row's current position.
local function PlaceSecureRows()
	if InCombatLockdown() or not (menu and menu:IsShown()) then return end
	local used = 0
	local top, bottom = menu.area:GetTop(), menu.area:GetBottom()
	local scale = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
	for _, row in ipairs(menu.rows) do
		local item = row:IsShown() and row.item
		local secure = item and not item.disabled and item.secure
		if secure and top and bottom then
			local left, foot, width, height = row:GetLeft(), row:GetBottom(), row:GetWidth(), row:GetHeight()
			-- Skip rows scrolled out of view.
			if left and foot and foot >= bottom - 1 and foot + height <= top + 1 then
				used = used + 1
				local b = SecureRow(used)
				if b.item ~= item then
					for key in pairs(b.set) do b:SetAttribute(key, nil) end
					wipe(b.set)
					for key, value in pairs(secure) do
						b:SetAttribute(key, value)
						b.set[key] = true
					end
					b.item = item
				end
				b.row = row
				local at = ("%.1f %.1f %.1f %.1f"):format(left * scale, foot * scale, width * scale, height * scale)
				if b.at ~= at then
					b.at = at
					b:ClearAllPoints()
					b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, foot * scale)
					b:SetSize(width * scale, height * scale)
				end
				b:Show()
			end
		end
	end
	HideSecureRows(used + 1)
end

-- Hide them while it is still allowed.
local secureWatch = CreateFrame("Frame")
secureWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
secureWatch:SetScript("OnEvent", function()
	for _, b in ipairs(secureRows) do
		b:Hide()
		b.row, b.item, b.at = nil, nil, nil
	end
end)

-- The secure buttons currently shown.
function UI.MenuSecureRows()
	local shown = {}
	for _, b in ipairs(secureRows) do
		if b:IsShown() then shown[#shown + 1] = b end
	end
	return shown
end

-- A menu's housing, the one every menu wears (ours, and the game's own as ShySkin dresses them): a black
-- outline, a steel one inside it, the panel's fill inside that, the dark rail down the left of the fill (for the
-- rows' icons and checks; its width the caller's) with a rule along it, and the accent line, the menu's only
-- accent color, which the caller stands (down the left edge, inside the outline). Textures on `f`'s BACKGROUND
-- layer, painted by the theme. UI.MENU_ROW is a row's measures, for laying one out as ours are.
--   local parts = UI.MenuHousing(f)   -- fill, steel, inside, rail, railRule, accent
-- (rail: the rail's width; railIcons: its width in a menu whose rows wear pictures, `icon` across.)
UI.MENU_ROW = { edge = MENU.edge, pad = MENU.pad, rail = MENU.rail, railIcons = math.max(MENU.rail, MENU.icon + 10),
	inset = MENU.inset, gap = MENU.gap, check = MENU.check, icon = MENU.icon, row = MENU.row, rule = MENU.rule }

function UI.MenuHousing(f)
	local parts = {}
	parts.fill = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	parts.fill:SetAllPoints()
	parts.fill:SetColorTexture(0, 0, 0, 1)
	parts.steel = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	parts.steel:SetPoint("TOPLEFT", 1, -1)
	parts.steel:SetPoint("BOTTOMRIGHT", -1, 1)
	Theme.Paint(parts.steel, Theme.skin.metal, 0.6)
	parts.inside = f:CreateTexture(nil, "BACKGROUND", nil, -6)
	parts.inside:SetPoint("TOPLEFT", MENU.edge, -MENU.edge)
	parts.inside:SetPoint("BOTTOMRIGHT", -MENU.edge, MENU.edge)
	Theme.Paint(parts.inside, C.panel, 1)
	parts.rail = f:CreateTexture(nil, "BACKGROUND", nil, -5)
	parts.rail:SetPoint("TOPLEFT", MENU.edge, -MENU.edge)
	parts.rail:SetPoint("BOTTOMLEFT", MENU.edge, MENU.edge)
	parts.rail:SetWidth(MENU.rail)
	parts.rail:SetColorTexture(0, 0, 0, 0.38)
	parts.railRule = f:CreateTexture(nil, "BACKGROUND", nil, -4)
	parts.railRule:SetPoint("TOPLEFT", parts.rail, "TOPRIGHT", -1, 0)
	parts.railRule:SetPoint("BOTTOMLEFT", parts.rail, "BOTTOMRIGHT", -1, 0)
	parts.railRule:SetWidth(1)
	Theme.Paint(parts.railRule, C.border, 1)
	parts.accent = f:CreateTexture(nil, "BACKGROUND", nil, -1)
	parts.accent:SetWidth(2)
	Theme.Paint(parts.accent, Theme.Accent)
	return parts
end

local function MenuBuild()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)   -- so a click between rows doesn't fall through
	f:SetIgnoreParentAlpha(true)   -- just asked for: solid over a faded or quiet screen
	f:Hide()
	-- The housing (UI.MenuHousing): its rail as wide as the rows' pictures need (Fill).
	local parts = UI.MenuHousing(f)
	f.accent, f.rail, f.railRule = parts.accent, parts.rail, parts.railRule
	-- Covers the outline where the menu joins its button (MenuPlace).
	f.gap = f:CreateTexture(nil, "BACKGROUND", nil, -2)
	Theme.Paint(f.gap, C.panel, 1)
	f.area = UI.ScrollArea(f, 100, 100)
	f.area:SetPoint("TOPLEFT", MENU.edge, -MENU.edge - 1)
	Theme.Paint(f.area.thumb, Theme.skin.metal, 0.75)
	f.rows = {}
	f.footRule = f:CreateTexture(nil, "ARTWORK")
	f.footRule:SetHeight(1)
	Theme.Paint(f.footRule, C.border, 0.9)
	f.footLeft = UI.Words(f, UI.NameFont(10), C.dim)
	f.foot = UI.Words(f, 10.5, C.text, { justify = "RIGHT" })
	f.fade = f:CreateAnimationGroup()
	local alpha = f.fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(MENU.fade)

	function f:Fill()
		local owner, opts = self.owner, self.opts
		local items = self.source
		if type(items) == "function" then items = items(owner) end
		local height, wide, onY = MenuRows(items, opts)
		local foot, total = opts.foot, nil
		if type(foot) == "function" then foot, total = foot(owner) end
		self.footLeft:SetText(foot or "")
		self.foot:SetText(total or "")
		self.footRule:SetShown(foot ~= nil)
		local rail = self.railWidth
		if foot then wide = max(wide, rail + MENU.inset * 2 + 12 + self.footLeft:GetStringWidth() + self.foot:GetStringWidth()) end
		self.rail:SetWidth(rail)

		-- A scrolling list ends on half a row, to show there is more, and its rows give up 8 to the
		-- bar: the width makes room for that, so no row loses its tail.
		local most = (items.rows or opts.rows or MENU.rows) * MENU.row
		local view = height > most and (most - MENU.row / 2) or height
		local scrolls = height > view
		local width = max(MENU.min, opts.width or 0, opts.fit and (owner:GetWidth() - MENU.edge * 2 + 2) or 0,
			min(MENU.max, wide + (scrolls and 8 or 0)))
		self:SetSize(width + MENU.edge * 2, view + MENU.edge * 2 + 2 + (foot and MENU.foot or 0))
		self.area:SetSize(width, view)
		self.area.content:SetSize(width - (scrolls and 8 or 0), height)
		if foot then
			self.footRule:SetPoint("BOTTOMLEFT", MENU.edge + rail, MENU.edge + MENU.foot - 1)
			self.footRule:SetPoint("BOTTOMRIGHT", -MENU.edge, MENU.edge + MENU.foot - 1)
			self.footLeft:SetPoint("BOTTOMLEFT", MENU.edge + rail + MENU.inset, MENU.edge + 5)
			self.foot:SetPoint("BOTTOMRIGHT", -(MENU.edge + MENU.inset + 2), MENU.edge + 5)
		end
		return #items, view, height, onY
	end

	f:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
	f:SetScript("OnHide", function(self)
		self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		HideSecureRows()
	end)
	f:SetScript("OnEvent", function(self, _, button)
		-- opts.keepOn: that button elsewhere doesn't close the menu (the right button turns the camera).
		if button ~= nil and self.opts.keepOn == button then return end
		-- A click on the owner is left to the owner, which toggles the menu. A cursor menu has no owner button.
		local onOwner = self.opts.side ~= "cursor" and self.owner:IsMouseOver()
		if not self:IsMouseOver() and not onOwner then UI.CloseMenu() end
	end)
	f:SetScript("OnUpdate", function(self)
		if not self.owner:IsVisible() then
			UI.CloseMenu()
			return
		end
		PlaceSecureRows()   -- every frame: the list may have scrolled or been refilled
	end)
	return f
end

function UI.MenuOwner()
	return menu and menu:IsShown() and menu.owner or nil
end

-- True when frame is part of the menu (one of its rows).
function UI.InMenu(frame)
	while frame do
		if frame == menu then return true end
		frame = frame:GetParent()
	end
	return false
end

function UI.CloseMenu()
	if not (menu and menu:IsShown()) then return end
	local owner, opts = menu.owner, menu.opts
	menu:Hide()
	menuKeys:Hide()
	if Shy.Hover then
		Shy.Hover.Close()
		Shy.Hover.Restack()
	end
	if opts.onHide then opts.onHide(owner) end
end

function UI.Menu(owner, items, opts)
	opts = opts or {}
	if UI.MenuOwner() == owner and opts.side ~= "cursor" then
		UI.CloseMenu()
		return
	end
	UI.CloseMenu()
	menu = menu or MenuBuild()
	menu.owner, menu.opts, menu.source, menu.trail = owner, opts, items, {}
	local count, view, height, onY = menu:Fill()
	if count == 0 then return end
	MenuPlace(opts)
	-- A long list opens scrolled to its current pick.
	menu.area:SetVerticalScroll(max(0, min(height - view, (onY or 0) - (view - MENU.row) / 2)))
	menu:Show()
	-- The hover of what it was opened on goes: the menu is what you read now. One kept up slips under it.
	if Shy.Hover then
		Shy.Hover.Close()
		Shy.Hover.Restack()
	end
	menu.area:Update()
	menu.fade:Stop()
	menu.fade:Play()
	menuKeys:SetShown(not InCombatLockdown())
	if opts.onShow then opts.onShow(owner) end
	return menu
end

-- Menus built entry by entry, with the method names of Blizzard's MenuUtil descriptions.
--
--   UI.ContextMenu(owner, function(root) ... end, opts)   -- at the cursor; opts as UI.Menu's
--   UI.DropMenu(owner, function(root) ... end, opts)      -- under the owner
--   root:CreateTitle(text)                    root:CreateDivider()
--   root:CreateSection(text)                  -- a heading over what follows; left out when nothing follows it
--   root:CreateButton(text, onClick)          -- returns the entry; entries created on it form a submenu
--   root:CreateCheckbox(text, isOn, toggle)   -- the menu stays open
--   root:CreateRadio(text, isOn, pick)
--   root:Count()                              -- entries written here so far (headings and dividers not counted)
--   entry:SetEnabled(false)                   entry:SetTooltip("hover text")
--   entry:SetSub("a second line, dim")        entry:SetDetail("at the right, dim")
--   entry:SetIcon(file)                       -- a picture before the words (buttons only)
--   entry:SetRightClick()                     -- a right click runs it too: onClick(item, owner, mouseButton)
--   entry:SetScrollMode(height)               -- submenu height before it scrolls
--
-- A menu written by several hands (a window's rows, then the addon's, then the box's) is tidied before it
-- opens: a section heading with nothing under it goes, and so do dividers that would stand at an end or
-- against another. So every writer may close its part with a divider and open it with a section, and
-- the menu reads as one.

local Entries = {}
Entries.__index = Entries

local function Entry(list, item)
	list[#list + 1] = item
	return setmetatable({ item = item }, Entries)
end

local function ListOf(self)
	if self.list then return self.list end
	self.item.items = self.item.items or {}
	return self.item.items
end

function Entries:CreateTitle(text) return Entry(ListOf(self), { heading = text }) end
function Entries:CreateSection(text) return Entry(ListOf(self), { heading = text, section = true }) end
function Entries:CreateDivider() return Entry(ListOf(self), { divider = true }) end
function Entries:Count()
	local n = 0
	for _, item in ipairs(ListOf(self)) do
		if not (item.heading or item.divider) then n = n + 1 end
	end
	return n
end
function Entries:CreateButton(text, onClick)
	return Entry(ListOf(self), { text = text, click = onClick })
end
function Entries:CreateCheckbox(text, isOn, toggle)
	return Entry(ListOf(self), { text = text, on = isOn, click = toggle, keep = true })
end
function Entries:CreateRadio(text, isOn, pick)
	return Entry(ListOf(self), { text = text, on = isOn, click = pick })
end
function Entries:SetEnabled(enabled) self.item.disabled = not enabled end
-- The row runs a protected action through a secure button (see "Secure rows" above); `after` runs once
-- the game has (not in a fight: the row is hidden there).
function Entries:SetSecure(attributes, after)
	self.item.secure, self.item.after = attributes, after
end
function Entries:SetTooltip(text) self.item.tip = text end
function Entries:SetSub(text) self.item.sub = text end
function Entries:SetDetail(text) self.item.detail = text end
-- A picture on the rail before the words, as UI.Menu's item.icon (a file, or { atlas = name }). On a
-- checkbox its tick moves to the row's right end; not on a radio, whose mark stands on the rail.
function Entries:SetIcon(icon) self.item.icon = icon end
-- The row answers a right click too; onClick is told which button (its third argument).
function Entries:SetRightClick(on) self.item.anyButton = on ~= false end
function Entries:SetScrollMode(height)
	ListOf(self).rows = max(4, floor(height / MENU.row))
end

-- A section heading with no entry straight under it (the next thing a heading, a divider or the end)
-- goes; a divider at either end, or straight after another or a section, goes too. Submenus the same.
-- (A title, CreateTitle, is the writer's own and stays as written.)
local function Tidy(list)
	local out = {}
	for index, item in ipairs(list) do
		local keep = true
		if item.section then
			local next_ = list[index + 1]
			keep = next_ ~= nil and not next_.heading and not next_.divider
		elseif item.divider then
			local last = out[#out]
			keep = last ~= nil and not last.divider and not last.section
		end
		if keep then
			if item.items then Tidy(item.items) end
			out[#out + 1] = item
		end
	end
	while out[#out] and out[#out].divider do out[#out] = nil end
	for index = 1, #list do list[index] = out[index] end
	return list
end

local function Written(owner, write, side, opts)
	local list = {}
	write(setmetatable({ list = list }, Entries))
	Tidy(list)
	local menuOpts = { side = side }
	for key, value in pairs(opts or {}) do menuOpts[key] = value end
	return UI.Menu(owner, list, menuOpts)
end

function UI.ContextMenu(owner, write, opts)
	return Written(owner, write, "cursor", opts)
end

function UI.DropMenu(owner, write, opts)
	return Written(owner, write, "below", opts)
end

-- The game's own menus, in ours. A game dropdown (a DropdownButton) is written by a generator into a menu
-- description of the game's; this reads one back entry by entry into a writer of ours: titles, dividers,
-- buttons, checkboxes, radios and submenus, each row's pick the game's own (the description's Pick), so it
-- does what the game's row does, and a picture the game keeps with a row (its data's texture: tracking's) is
-- shown before its words. Only for menus whose rows do nothing protected: a pick runs in our code, and the
-- game refuses a protected action from it (Edit Mode's layouts and the unit menus stay the game's).
--   UI.GameEntries(root, description)   a description's entries, written into a writer (root or an entry)
--   UI.GameDescription(dropdown)        a game dropdown's menu as a description, or nil
--   UI.GameMenu(dropdown, opts)         from now on the dropdown opens ours: opts.when() false lets the game's
--                                       open; opts.menu is UI.Menu's opts; opts.icons gives rows a glyph on the
--                                       rail (a checkbox's state is then its light and wash). A dropdown on the
--                                       right of the screen opens its menu leftwards, right edges aligned,
--                                       unless opts.menu says.
--   UI.GameEntries(root, description, icons)   the same, with icons as above
--   icons: { [row's words] = a UI.MenuGlyph name }, or function(words, description) -> a name or nil (a row known by
--          its data: the description's GetData). UI.MenuIcon(icons, words, description) reads either. ShySkin's
--          dress for the game's own menus reads the same.
function UI.MenuIcon(icons, words, description)
	if type(icons) == "function" then return icons(words, description) end
	return icons and words and icons[words]
end
local function GameIcon(data)
	if type(data) ~= "table" then return "" end
	local texture = data.texture
	if issecretvalue(texture) or (type(texture) ~= "number" and type(texture) ~= "string") then return "" end
	-- Cropped of an icon's dark rim, as the game's own menu shows a spell's.
	return ("|T%s:16:16:0:0:64:64:5:57:5:57|t "):format(tostring(texture))
end

function UI.GameEntries(root, description, icons)
	for _, desc in description:EnumerateElementDescriptions() do
		local text = MenuUtil.GetElementText(desc)
		local nested = desc:HasElements()
		local entry
		if type(text) ~= "string" or text == "" then
			if not nested then root:CreateDivider() end   -- a divider or a spacer
		else
			local label = GameIcon(desc:GetData()) .. text
			local function Pick() desc:Pick(MenuInputContext.MouseButton, "LeftButton") end
			local function Selected() return desc:IsSelected() end
			if desc:IsCheckbox() then
				entry = root:CreateCheckbox(label, Selected, Pick)
			elseif desc:IsRadio() then
				entry = root:CreateRadio(label, Selected, Pick)
			elseif desc:HasResponder() or nested then
				entry = root:CreateButton(label, (not nested or desc:ShouldRespondIfSubmenu()) and Pick or nil)
			else
				entry = root:CreateTitle(text)
			end
			if nested then UI.GameEntries(entry, desc, icons) end
			if entry and not desc:IsEnabled() then entry:SetEnabled(false) end
			local glyph = UI.MenuIcon(icons, text, desc)
			if entry and glyph then entry:SetIcon(UI.MenuGlyph(glyph)) end
		end
	end
end

function UI.GameDescription(dropdown)
	local generator = dropdown and dropdown.menuGenerator
	if type(generator) ~= "function" then return nil end
	local description = MenuUtil.CreateRootMenuDescription(dropdown.menuMixin or MenuVariants.GetDefaultMenuMixin())
	Menu.PopulateDescription(generator, dropdown, description)
	return description
end

local gameMenus = setmetatable({}, { __mode = "k" })   -- dropdown -> its opts

function UI.GameMenu(dropdown, opts)
	if not dropdown or type(dropdown.OpenMenu) ~= "function" then return end
	local hooked = gameMenus[dropdown] ~= nil
	gameMenus[dropdown] = opts or {}
	if hooked then return end
	-- The game's opens first (the same click): it is closed at once and ours opened from the same button.
	hooksecurefunc(dropdown, "OpenMenu", function(self)
		local o = gameMenus[self]
		if not o or (o.when and not o.when()) then return end
		local description = UI.GameDescription(self)
		if not description then return end
		Menu.GetManager():CloseMenus()
		-- On the right of the screen, the menu opens leftwards under its button, toward the window it serves.
		local menuOpts = o.menu or {}
		if menuOpts.align == nil and (self:GetRight() or 0) > UIParent:GetRight() / 2 then
			local aligned = { align = "RIGHT" }
			for key, value in pairs(menuOpts) do aligned[key] = value end
			menuOpts = aligned
		end
		UI.DropMenu(self, function(root) UI.GameEntries(root, description, o.icons) end, menuOpts)
	end)
end

-- Telling chat: a menu entry over every chat the player can speak in, which sends a line there ending in
-- the game's map pin link.
--
--   UI.TellMenu(root, label, line, where, opts)   line(): the words; where(): map, x, y (shares) or nil, for the pin
--                                           opts.usual: a chat's key (see UI.Chats) that stands first, marked
--                                           "usual"; opts.remember(key): told which chat was picked
--   UI.Chats()                              every chat the player can speak in now: { { label, key, kind,
--                                           target } }, key "SAY", "YELL", "GROUP", "GUILD" or a channel's own name
--   UI.PinLink(map, x, y)                   the game's map pin link there, the one its map shares
--   UI.PinBorrowed()                        true while UI.PinLink holds the player's pin: a waypoint
--                                           change then is not theirs
--   UI.ChatLocked()                         the game lets no macro or addon send chat now
--
-- The game blocks an addon's own send to these chats, even from a click: each chat is a secure row whose
-- macro ("/2 the line") the game sends itself, so the line and its pin are made when the menu opens. The
-- game gives a map pin link only for the player's own pin, so it is borrowed and put back. Secure rows
-- are no use in a fight, and opening the chat box for the player would spoil their own send too (the
-- box's OnShow sets its chat type in the caller's taint): the entry waits for the fight's end.

local borrowing = false

function UI.PinBorrowed() return borrowing end

function UI.PinLink(map, x, y)
	-- (Borrowing the pin in a fight with the world map open is blocked: Shy.Waypoint.)
	if not (map and C_Map.CanSetUserWaypointOnMap(map)) or Shy.Waypoint.Held() then return nil end
	local had = C_Map.GetUserWaypoint()
	borrowing = true
	local ok, link = pcall(function()
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
		return C_Map.GetUserWaypointHyperlink()
	end)
	if had then C_Map.SetUserWaypoint(had) else C_Map.ClearUserWaypoint() end
	borrowing = false
	if not ok then
		geterrorhandler()(link)
		return nil
	end
	return link
end

function UI.ChatLocked()
	return C_ChatInfo.InChatMessagingLockdown() or InCombatLockdown()
end

-- Say, yell, the group, the guild and every channel joined. A chat's key names it across sessions: the
-- group's is one key whether it is a party or a raid, a channel's is its own name without the zone.
function UI.Chats()
	local out = { { label = SAY, kind = "SAY", key = "SAY" }, { label = YELL, kind = "YELL", key = "YELL" } }
	if IsInRaid() then
		out[#out + 1] = { label = RAID, kind = "RAID", key = "GROUP" }
	elseif IsInGroup() then
		out[#out + 1] = { label = PARTY, kind = "PARTY", key = "GROUP" }
	end
	if IsInGuild() then out[#out + 1] = { label = GUILD, kind = "GUILD", key = "GUILD" } end
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		if not list[i + 2] then
			-- "LocalDefense - Elwynn Forest" -> "LocalDefense", shown as "Local Defense"
			local key = list[i + 1]:gsub("%s+%-%s+.*$", "")
			local name = key:gsub("(%l)(%u)", "%1 %2")
			out[#out + 1] = { label = name, kind = "CHANNEL", target = list[i], key = key }
		end
	end
	return out
end
local Chats = UI.Chats

-- The slash that speaks in each kind of chat; a channel's is its number.
local SLASH = { SAY = SLASH_SAY1, YELL = SLASH_YELL1, PARTY = SLASH_PARTY1, RAID = SLASH_RAID1, GUILD = SLASH_GUILD1 }
local LONGEST = 255   -- a chat message's length

function UI.TellMenu(root, label, line, where, opts)
	opts = opts or {}
	local text = line()
	local link = where and UI.PinLink(where())
	local said = link and (text .. " " .. link) or text
	local tell = root:CreateButton(label)
	tell:SetTooltip(said)
	if UI.ChatLocked() then
		tell:SetEnabled(false)
		tell:SetSub("After the fight")
	end
	-- The usual chat first, then the rest in their order.
	local chats, usual = Chats(), nil
	for index, chat in ipairs(chats) do
		if chat.key == opts.usual then usual = table.remove(chats, index) break end
	end
	if usual then
		table.insert(chats, 1, usual)
		usual.usual = true
	end
	for index, chat in ipairs(chats) do
		if index == 2 and usual then tell:CreateDivider() end
		local words = #said <= LONGEST and said or text:sub(1, LONGEST)
		local slash = chat.kind == "CHANNEL" and ("/" .. chat.target) or SLASH[chat.kind]
		local entry = tell:CreateButton(chat.label)
		entry:SetSecure({ type = "macro", macrotext = slash .. " " .. words },
			opts.remember and function() opts.remember(chat.key) end or nil)
		if chat.usual then
			entry:SetDetail("usual")
		elseif chat.kind == "CHANNEL" then
			entry:SetDetail(tostring(chat.target))
		end
	end
	return tell
end

-- UI.MenuButton: a button that opens a UI.Menu and stays on while it is open: plated, a button of the
-- family's make (UI.KeyPress) whose menu opens just under it; else a quiet UI.Press one, its menu joined.
--
--   local b = UI.MenuButton(parent, {
--       items = list or function(button) return list end,   -- as UI.Menu's
--       menu = { ... },      -- UI.Menu's opts
--       plate = true,        -- background always shown (default: only hovered or open)
--       width = 260,         -- fixed width with the caret at the right end (default: fits its text)
--       font = fontObject,   -- default UI.TextFont(12)
--       height = 18, tip = "Choose a character",
--       inset = 9,           -- where its words begin (default 9: clear of the accent line on the left)
--       caretY = -1,         -- the caret's place against the middle of the words' line (default -1, for UI.TextFont)
--       drag = box,          -- it stands on that Shy.HUD box's title bar: pressed and moved a few pixels it
--                            -- drags the window and opens nothing (Shy.HUD.Carry)
--   })
--   b:SetLabel(text, color, most)   -- sizes the button to the text, up to `most`
--   b:SetIcon(file)                 -- a 12 unit glyph before the words (nil: none), counted in its width
--   b:SetChoices(false)             -- nothing to choose: no caret, no mouse
--   b:SetGlyph(file)                -- a glyph and its caret, no words (a settings cog), evenly spaced
--   b:Open()                        -- opens its menu (or closes it, when it is up)

local MENU_ROOM = {
	icon = 12,  -- a menu button's icon, and the room it takes before the words
	pad = 5,
	gap = 3,  -- a glyph-only menu button (SetGlyph): room at each end; glyph to caret
	split = 8,  -- words to caret on a split button: the hairline stands halfway, room either side
}
-- A menu button's measures, for a dropdown of the game's dressed as one (ShySkin's ns.Dropdown, "chooser"): room at
-- each end, the glyph, glyph (or words) to caret, the caret, and the caret's place against the words' middle.
UI.MENU_BUTTON = { pad = MENU_ROOM.pad, glyph = MENU_ROOM.icon, gap = MENU_ROOM.gap, caret = 10, caretY = -1 }

function UI.MenuButton(parent, opts)
	opts = opts or {}
	local inset = opts.inset or 9
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(opts.height or 18)
	b.text = UI.Words(b, opts.font or UI.TextFont(12), C.text, { wrap = false })
	b.text:SetPoint("LEFT", inset, 0)
	b.caret = b:CreateTexture(nil, "ARTWORK")
	b.caret:SetTexture(Shy.MEDIA .. "GlyphCaret")
	b.caret:SetSize(10, 10)
	-- The caret stands on the middle of the words' small letters, which is not the middle of their line:
	-- a face with tall lines (one with every alphabet) has its letters high in it, and takes opts.caretY.
	local caretY = opts.caretY or -1
	local gap = opts.caretGap or 4   -- between the words and the caret (a split button's hairline stands in it)
	if opts.width then
		b:SetWidth(opts.width)
		b.text:SetWidth(opts.width - 27 - gap)
		b.caret:SetPoint("RIGHT", -7, caretY)
	else
		b.caret:SetPoint("LEFT", b.text, "RIGHT", gap, caretY)
	end
	-- Plated: a button of the family's make (UI.KeyPress); else the quiet one (UI.Press).
	local sink = opts.width and { b.text, b.caret } or { b.text }
	if opts.plate then
		UI.KeyPress(b, { words = b.text, sink = sink })
	else
		UI.Press(b, { fill = C.bg, bare = true, sink = sink })
	end
	function b:OnLook(state)
		Theme.Tint(self.caret, (state.over or state.on) and C.text or C.dim)
		-- Open: the caret flips.
		if state.on then self.caret:SetTexCoord(0, 1, 1, 0) else self.caret:SetTexCoord(0, 1, 0, 1) end
	end
	b:OnLook(b.shyPress)

	local menuOpts = {}
	for key, value in pairs(opts.menu or {}) do menuOpts[key] = value end
	-- A quiet button's menu joins it, one outline; a plated one's rounded make opens it just under.
	menuOpts.join = not opts.plate
	local shown, hidden = menuOpts.onShow, menuOpts.onHide
	menuOpts.onShow = function(self) self:SetOn(true); if shown then shown(self) end end
	menuOpts.onHide = function(self) self:SetOn(false); if hidden then hidden(self) end end
	function b:Open()
		local items = opts.items
		-- opts.write builds the menu entry by entry each time, as UI.DropMenu's writer does.
		if opts.write then
			items = {}
			opts.write(setmetatable({ list = items }, Entries))
		end
		UI.Menu(self, items, menuOpts)
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		-- The press dragged the window it stands on: no click.
		if opts.drag and Shy.HUD.WasDragged(opts.drag) then return end
		-- (self.act: a split button's words have a click of their own, UI.SplitButton. Its menu, if up, goes.)
		if self.act then
			if UI.MenuOwner() == self then UI.CloseMenu() end
			self.act(self)
		else
			self:Open()
		end
	end)
	if opts.tip then
		b:HookScript("OnEnter", function(self)
			if UI.MenuOwner() == self then return end
			UI.Tip(self, opts.tip, nil, { side = "TOP" })
		end)
		b:HookScript("OnLeave", function(self) UI.TipHide(self) end)
		b:HookScript("OnMouseDown", function(self) UI.TipHide(self) end)
	end
	if opts.drag then Shy.HUD.Carry(opts.drag, b) end

	local lead, most = inset, nil   -- where the words begin (past the icon, if any); SetLabel's last `most`
	function b:SetLabel(text, color, widest)
		most = widest
		if color then Theme.Ink(self.text, color) end
		if opts.width then
			self.text:SetText(text or "")
			return
		end
		self.text:SetWidth(0)
		self.text:SetText(text or "")
		local tail = self.caret:IsShown() and gap + 16 or 6
		local width = math.ceil(self.text:GetStringWidth())   -- whole units: what is laid after it stays on them
		-- The words are only held to a width when they must be cut. Held to the width they measure, a face
		-- not loaded yet when they were measured (or a pixel's rounding) cuts them short ("Lay...").
		if most and width > most - lead - tail then
			width = max(10, most - lead - tail)
			self.text:SetWidth(width)
		end
		self:SetWidth(lead + width + tail)
	end
	-- Sized to its words: measured again in another font (one of a set width is cut to it as before).
	if not opts.width then
		UI.KeyWords(b, function(self) self:SetLabel(self.text:GetText(), nil, most) end)
	end
	-- A glyph before its words (nil: none). The words move past it and the button grows to hold both, so
	-- the caret and anything laid after the button keep their room. The caller tints b.icon with the words.
	function b:SetIcon(file)
		local step = self.shyPress.step   -- pressed: the sunk regions are a unit down and right
		if file and not self.icon then
			self.icon = self:CreateTexture(nil, "OVERLAY")
			self.icon:SetSize(MENU_ROOM.icon, MENU_ROOM.icon)
			self.icon:SetPoint("CENTER", self, "LEFT", inset + 1 + step, -step)
			Theme.Tint(self.icon, C.text)
			table.insert(self.shyPress.sink, self.icon)
		end
		if self.icon then
			self.icon:SetShown(file ~= nil)
			if file then self.icon:SetTexture(file) end
		end
		lead = file and inset + MENU_ROOM.icon or inset
		self.text:SetPoint("LEFT", lead + step, -step)
		if not opts.width then self:SetLabel(self.text:GetText(), nil, most) end
	end
	function b:SetChoices(any)
		self.caret:SetShown(any)
		self:EnableMouse(any)
	end
	-- A glyph and its caret without words (a settings cog): the same room each side of the pair, a little
	-- between the two, and the button just as wide as that.
	function b:SetGlyph(file)
		self:SetIcon(file)
		self.text:SetText("")
		local pad, gap = MENU_ROOM.pad, MENU_ROOM.gap
		local step = self.shyPress.step
		self.icon:ClearAllPoints()
		self.icon:SetPoint("LEFT", pad + step, -step)
		self.caret:ClearAllPoints()
		self.caret:SetPoint("LEFT", pad + MENU_ROOM.icon + gap, caretY)
		self:SetWidth(pad + MENU_ROOM.icon + gap + self.caret:GetWidth() + pad)
	end
	return b
end

-- UI.SplitButton: a UI.MenuButton in two parts. Its words do something of their own; its caret opens
-- the menu. One button to the eye: one plate under the mouse, a hairline between the two parts, and the
-- caret answering the mouse only on its own part.
--
--   local b = UI.SplitButton(parent, {
--       click = function(button) end,   -- the words' own click. nil: they open the menu too
--       ...                             -- UI.MenuButton's opts
--   })
--   b:SetAction(fn)        -- the words' click from now on (nil: they open the menu, as a menu button's)
--   b:SetChoices(false)    -- nothing to choose: no caret; the words still click while they have an action
--   b.drop                 -- the caret's own button
--   b:OnLook(state)        -- as UI.Press's, with state.tail: the mouse is on the caret's part


function UI.SplitButton(parent, opts)
	opts = opts or {}
	local b = UI.MenuButton(parent, setmetatable({ caretGap = MENU_ROOM.split }, { __index = opts }))
	local state = b.shyPress
	b.act = opts.click

	-- The caret's part: the button's tail, from the hairline halfway between the words and the caret.
	local drop = CreateFrame("Button", nil, b)
	b.drop = drop
	drop:SetPoint("TOPRIGHT")
	drop:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", -(opts.width and 22 or 16 + MENU_ROOM.split / 2), 0)
	b.split = b:CreateTexture(nil, "OVERLAY")
	b.split:SetWidth(1)
	b.split:SetPoint("TOPLEFT", drop, "TOPLEFT", 0, -3)
	b.split:SetPoint("BOTTOMLEFT", drop, "BOTTOMLEFT", 0, 3)
	Theme.Paint(b.split, C.border, 1)

	local look = b.OnLook
	function b:OnLook(s)
		look(self, s)
		local both = self.act ~= nil and self.caret:IsShown()
		self.split:SetShown(both and (s.over or s.on) or false)
		if both then Theme.Tint(self.caret, (s.tail or s.on) and C.text or C.dim) end
	end

	-- The mouse on the caret's part has left the button, to the game: the button is told it is still on
	-- it, so its plate stays, and which part it is on.
	local telling = false
	local function Tell(script, tail)
		return function()
			telling, state.tail = true, tail
			local fn = b:GetScript(script)
			if fn then fn(b) end
			telling = false
		end
	end
	drop:SetScript("OnEnter", Tell("OnEnter", true))
	drop:SetScript("OnLeave", Tell("OnLeave", false))
	drop:SetScript("OnMouseDown", Tell("OnMouseDown", true))
	drop:SetScript("OnMouseUp", Tell("OnMouseUp", true))
	drop:SetScript("OnClick", function()
		if not b.dimmed then b:Open() end
	end)
	b:HookScript("OnEnter", function(self)
		if telling then return end
		state.tail = false
		self:OnLook(state)
	end)

	function b:SetAction(fn)
		self.act = fn
		self:EnableMouse(fn ~= nil or self.caret:IsShown())
		self:OnLook(state)
	end
	function b:SetChoices(any)
		self.caret:SetShown(any)
		drop:SetShown(any)
		self:EnableMouse(any or self.act ~= nil)
		self:OnLook(state)
	end
	b:OnLook(state)
	return b
end

-- Dropdown. items = { { value = v, text = "Label", font = optionalFontPath, icon = optionalIcon }, ... }; f:SetItems(items)
-- (icon: a picture beside the words in the open list, as UI.Menu's item.icon)
-- opts.preview(value): the value the mouse is on in the open list, shown before it is picked; nil as the list
-- closes (a pick has been set by then).

function UI.Dropdown(parent, label, items, get, set, opts)
	opts = opts or {}
	local width = opts.width or 260

	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 46)
	f.label = UI.Text(f, label)
	f.label:SetPoint("TOPLEFT")

	local preview = opts.preview
	local btn = UI.MenuButton(f, {
		plate = true, width = width, height = 24, font = GameFontHighlight,
		menu = { fit = true, font = GameFontHighlight, onHide = preview and function() preview(nil) end },
		items = function()
			local current, list = get(), {}
			for i, item in ipairs(items) do
				list[i] = {
					text = item.text, font = item.font, icon = item.icon, on = item.value == current,
					enter = preview and function() preview(item.value) end,
					click = function()
						set(item.value)
						f:Refresh()
					end,
				}
			end
			return list
		end,
	})
	btn:SetPoint("BOTTOMLEFT")

	local function ApplyFont(fs, item)
		local base, size = GameFontHighlight:GetFont()
		fs:SetFont(item and item.font or base, item and item.font and size + 2 or size, "")
	end

	function f:Refresh()
		local current, found = get(), false
		for _, item in ipairs(items) do
			if item.value == current then
				found = true
				btn:SetLabel(item.text)
				ApplyFont(btn.text, item)
			end
		end
		if not found then btn:SetLabel("") end   -- nothing picked, or the pick is no longer in the list
		btn:SetChoices(#items > 0)   -- nothing to pick from: no caret, no empty menu
		SetDimmed(self, not IsEnabled(opts))
		btn.dimmed = self.dimmed
	end
	function f:SetItems(other)
		items = other
		if UI.MenuOwner() == btn then UI.CloseMenu() end
		self:Refresh()
	end
	-- A dropdown is picked by clicking alone: it takes no keys (the arrow keys are chat's history) and no wheel
	-- (the wheel scrolls the page it stands on).
	AttachHelp(btn, label, opts)
	return f
end

-- The theme's font (Theme.FONTS), each named in its own face. The font the mouse is on in the open list is on
-- screen at once (Theme.PreviewFont); the list closed without a pick puts the worn one back. It shows the font
-- worn whenever a preset or anything else changes it.
--   UI.FontPicker(parent, opts)   -- opts: UI.Dropdown's (width, desc, disabled), label ("Font"), onPick(key)
local pickers = setmetatable({}, { __mode = "k" })

function UI.FontPicker(parent, opts)
	opts = opts or {}
	local items = {}
	for _, font in ipairs(Theme.FONTS) do items[#items + 1] = { value = font.key, text = font.name, font = font.file } end
	local o = {}
	for key, value in pairs(opts) do o[key] = value end
	o.preview = Theme.PreviewFont
	o.desc = opts.desc or "The lettering of every title, header and button."
	local f = UI.Dropdown(parent, opts.label or "Font", items, Theme.Font, function(key)
		Theme.SetFont(key)
		if opts.onPick then opts.onPick(key) end
	end, o)
	f:Refresh()
	pickers[f] = true
	return f
end

Shy:On("SHY_THEME", function()
	for picker in pairs(pickers) do picker:Refresh() end
end)

-- A swatch of a bar's fill: a bar as the HUD's, filled with `file` in your color (the Bar fill pick's preview).
--   local swatch = UI.FillSwatch(parent, width, height); swatch:SetFill(file)
function UI.FillSwatch(parent, width, height)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	UI.Skin(f, C.bg, Theme.skin.metal)
	f.fill = f:CreateTexture(nil, "ARTWORK")
	f.fill:SetPoint("TOPLEFT", 1, -1)
	f.fill:SetPoint("BOTTOMLEFT", 1, 1)
	f.fill:SetWidth((width - 2) * 0.72)
	f.fill:SetHorizTile(true)
	Theme.Tint(f.fill, Theme.Accent)
	function f:SetFill(file)
		self.fill:SetTexture(file, "REPEAT", "CLAMP")
		self.fill:SetHorizTile(true)
	end
	return f
end

-- Two slots at their true size, one empty and one holding a picture (your attack's), in a finish and a look
-- of their own: the pick seen before it is made. f:SetStyle(key, look); nil: the pick's, the theme's.
local SWATCH_SPELL = 6603   -- Attack
function UI.SlotSwatch(parent)
	local Slot = Shy.Slot
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(2 * Slot.SIZE + Slot.GAP, Slot.SIZE)
	f.slots, f.icons = {}, {}
	local picture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(SWATCH_SPELL) or "Interface\\Icons\\INV_Misc_QuestionMark"
	for i = 1, 2 do
		local tile = CreateFrame("Frame", nil, f)
		tile:SetSize(Slot.SIZE, Slot.SIZE)
		tile:SetPoint("LEFT", (i - 1) * (Slot.SIZE + Slot.GAP), 0)
		tile:EnableMouse(true)   -- a finish's light under the mouse shows here too
		local icon = tile:CreateTexture(nil, "BORDER")
		icon:SetAllPoints()
		if i == 2 then icon:SetTexture(picture) end
		f.icons[i] = icon
		f.slots[i] = Slot.New(tile, { icon = icon, size = Slot.SIZE })
	end
	f.slots[1]:Empty(true)
	function f:SetStyle(key, look)
		for i, slot in ipairs(self.slots) do slot:Set({ icon = self.icons[i], size = Slot.SIZE, style = key, look = look }) end
	end
	return f
end

-- Color swatch. get() -> r, g, b ; set(r, g, b)

function UI.OpenColorPicker(r, g, b, callback)
	local function picked() callback(ColorPickerFrame:GetColorRGB()) end
	local function cancel() callback(r, g, b) end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r, g = g, b = b, hasOpacity = false,
		swatchFunc = picked, cancelFunc = cancel,
	})
end

function UI.ColorSwatch(parent, label, get, set, opts)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(20)
	local swatch = CreateFrame("Frame", nil, b)
	swatch:SetSize(30, 18)
	swatch:SetPoint("LEFT")
	UI.Skin(swatch)
	b.text = UI.Text(b, label)
	b.text:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
	b:SetWidth(38 + b.text:GetStringWidth())
	UI.KeyWords(b, function(self) self:SetWidth(38 + self.text:GetStringWidth()) end)

	function b:Refresh()
		local r, g, bb = get()
		UI.SetFill(swatch, { r, g, bb, 1 })
		SetDimmed(self, not IsEnabled(opts))
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		UI.OpenColorPicker(get(), function(r, g, bb) set(r, g, bb); self:Refresh() end)
	end)
	b:SetScript("OnEnter", function() UI.SetBorder(swatch, C.hot) end)
	b:SetScript("OnLeave", function() UI.SetBorder(swatch, C.border) end)
	AttachHelp(b, label, opts)
	return b
end

-- Tabs. Returns a frame with :Select(i); onSelect(i) is called on change.
--
-- On a page the tabs sit on a thin rule with an accent line under the open one. In a window's title
-- strip, pass the window's UI.Panel as `strip` and anchor the tabs to the strip's foot: they then sit
-- on the panel's own accent line, and the open tab is the lit stretch of it.
--   local tabs = UI.Tabs(header, labels, onSelect, nil, 17, box)   -- box: a UI.Panel with a title
--   tabs:SetPoint("BOTTOMLEFT", 230, 0)
-- opts, the seventh: `tall`, the tabs' height (30), and `mid`, where their words stand down from their top (a
-- piece's strip: UI.HEAD_MID); the open tab's glow rises no higher than the tabs.
-- A strip whose tabs come and go (a window's conversations):
--   tabs:SetLabels(labels)   other tabs in place of these; returns the tabs, for scripts of the caller's own
--   tabs:SetTint(i, color)   tab i's lit stretch and glow in this color (nil: the theme's)
--   tabs:SetInk(i, open, rest)  tab i's words in colors of their own, open (or under the mouse) and at rest (nil: the strip's)
--   tabs:SetCount(i, n)      a quiet dim count after tab i's words (nil: none); SetBadge is the gold one, for attention
--   tabs:SetRoom(width)      the most they take: past it they scroll (the wheel; the open tab is kept in view),
--                            and an edge they run past is shaded, the strip's face thickening over them, a click
--                            there scrolling that way. tabs.overflow says whether they do
--   tabs:ScrollBy(dx)        scrolls them dx along (held within what there is)
--   tabs:Reveal(i)           scrolls tab i into view

-- An edge that tabs run past (a strip scrolled along): the strip's own face thickening over them, and at the very edge
-- a glint in your color, held to read on that face (drawn lighter on a dark strip, darker on a light one, just far
-- enough: Theme.Legible), so it shows there is more that way. UI.EdgeArt makes the two on a frame along its `side`;
-- UI.PaintEdge paints them for a face of r, g, b (again as the theme changes).
-- The face's and the glint's alpha at the edge, the glint's share of the width, and how far it stands off the face.
local EDGE = { face = 0.95, glint = 0.5, reach = 0.5, ratio = 3 }

function UI.EdgeArt(frame, side)
	local fill = frame:CreateTexture(nil, "ARTWORK")
	fill:SetAllPoints()
	fill:SetColorTexture(1, 1, 1, 1)
	local glint = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	glint:SetPoint("TOP" .. side)
	glint:SetPoint("BOTTOM" .. side)
	glint:SetWidth(math.max(1, frame:GetWidth() * EDGE.reach))
	glint:SetColorTexture(1, 1, 1, 1)
	return fill, glint
end

function UI.PaintEdge(fill, glint, side, r, g, b)
	local solid, clear = CreateColor(r, g, b, EDGE.face), CreateColor(r, g, b, 0)
	local ar, ag, ab = Theme.AccentSolid()
	local ir, ig, ib = Theme.Legible(ar, ag, ab, r, g, b, EDGE.ratio)
	local lit, unlit = CreateColor(ir, ig, ib, EDGE.glint), CreateColor(ir, ig, ib, 0)
	if side == "LEFT" then
		fill:SetGradient("HORIZONTAL", solid, clear)
		glint:SetGradient("HORIZONTAL", lit, unlit)
	else
		fill:SetGradient("HORIZONTAL", clear, solid)
		glint:SetGradient("HORIZONTAL", unlit, lit)
	end
end

-- GLOW the height of the open tab's glow in a title strip; FADE how much of the room tabs that run past it fade
-- out over; WHEEL how far a notch of the wheel scrolls them; WASH how much of the accent the open tab's glow lays
-- under its words.
local TAB = { GLOW = 28, FADE = 24, WHEEL = 40, WASH = 0.35 }

-- What a tab's words stand on: the window's strip as its look paints it, or the panel on a page.
local function PanelFace()
	local p = C.panel
	return p[1], p[2], p[3], 1
end

local function StripLight(tab, panel, tall)
	local glow = tab:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(UI.GLOSS)
	glow:SetTexCoord(0, 1, 1, 0)   -- flipped: light from below
	glow:SetPoint("BOTTOMLEFT", 0, 2)
	glow:SetPoint("BOTTOMRIGHT", 0, 2)
	glow:SetHeight(math.min(TAB.GLOW, tall - 2))
	Theme.Tint(glow, C.hot)
	local mark = UI.LineMark(panel, panel.shyLine)
	mark:Span(tab)
	return glow, mark
end

function UI.Tabs(parent, labels, onSelect, width, size, strip, opts)
	opts = opts or {}
	local tall = opts.tall or 30
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(tall)
	f.tabs = {}
	f.scroll = 0
	local sides = opts.sides or (size and size < 17 and 20 or 28)
	local gap = opts.gap or 4   -- between one tab and the next
	local face = PanelFace
	if strip then
		face = strip.shyStripFace or function() return Color(strip.shyStripColor or C.panel) end
	end
	local function Make(i, label)
		local t = CreateFrame("Button", nil, f)
		t.text = UI.TitleText(t, label, size or 17, C.text)
		-- Its words held to read on what they stand on (the contrast floor), the open one's on its glow too:
		-- made once, worked out again only as the theme or the look changes.
		t.inkRest = UI.KeyFloor(C.dim, UI.KeySeen(t, face, 0), Theme.LC_LABEL)
		t.inkHot = UI.KeyFloor(C.text, UI.KeySeen(t, face, 0), Theme.LC_LABEL)
		t.inkOpen = UI.KeyFloor(C.text, UI.KeySeen(t, face, strip and TAB.WASH or 0), Theme.LC_LABEL)
		if opts.mid then
			t.text:SetPoint("CENTER", t, "TOP", 0, -opts.mid)
		else
			t.text:SetPoint("CENTER", 0, 2)
		end
		t:SetSize(t.text:GetStringWidth() + sides, tall)
		if strip then
			t.glow, t.bar = StripLight(t, strip, tall)
			strip.shyLine.shyMarks:SetFrameLevel(f:GetFrameLevel() + 3)   -- the open tab's mark over the tabs
		else
			t.bar = UI.HeadLine(t)
			t.bar:SetPoint("BOTTOMLEFT")
			t.bar:SetPoint("BOTTOMRIGHT")
		end
		t:SetScript("OnClick", function()
			Sound("IG_CHARACTER_INFO_TAB")
			f:Select(i)
		end)
		t:SetScript("OnEnter", function(self) if f.selected ~= i then Theme.Ink(self.text, self.inkHot) end end)
		t:SetScript("OnLeave", function(self) if f.selected ~= i then Theme.Ink(self.text, self.inkRest) end end)
		f.tabs[i] = t
		return t
	end
	-- Each shown tab after the one before it, less the scroll; with a room, cut to it and faded where cut.
	local Shade
	local function Line()
		local total = 0
		for _, t in ipairs(f.tabs) do
			if t:IsShown() then total = total + t:GetWidth() + gap end
		end
		local room = f.room
		f.overflow = room ~= nil and total - gap > room + 0.5
		f.scroll = f.overflow and math.max(0, math.min(f.scroll, total - gap - room)) or 0
		local at = -f.scroll
		for _, t in ipairs(f.tabs) do
			if t:IsShown() then
				t:ClearAllPoints()
				t:SetPoint("LEFT", at, 0)
				at = at + t:GetWidth() + gap
			end
		end
		if not room then
			f:SetWidth(math.max(1, total))
			Shade(false, false)
			return
		end
		f:SetWidth(math.max(1, math.min(total, room)))
		f:EnableMouseWheel(f.overflow)
		Shade(f.scroll > 0.5, f.overflow and total - gap - f.scroll > room + 0.5)
	end
	-- The edges the tabs run past: the strip's own face thickening over them, a click scrolling that way.
	function Shade(left, right)
		if not (left or right or f.shades) then return end
		if not f.shades then
			f.shades = {}
			for i, side in ipairs({ "LEFT", "RIGHT" }) do
				local s = CreateFrame("Button", nil, f)
				s:SetPoint("TOP" .. side)
				s:SetPoint("BOTTOM" .. side)
				s:SetWidth(TAB.FADE)
				s:SetFrameLevel(f:GetFrameLevel() + 6)
				s.fill, s.glint = UI.EdgeArt(s, side)
				s.way = i == 1 and -1 or 1
				s:SetScript("OnClick", function(self) f:ScrollBy(self.way * TAB.WHEEL * 2) end)
				s:Hide()
				f.shades[i] = s
			end
			Shy:On("SHY_THEME", function() if f.room then Line() end end)
		end
		local r, g, b = face()
		for i, on in ipairs({ left == true, right == true }) do
			local s = f.shades[i]
			s:SetShown(on)
			if on then UI.PaintEdge(s.fill, s.glint, i == 1 and "LEFT" or "RIGHT", r, g, b) end
		end
	end
	function f:ScrollBy(dx)
		self.scroll = self.scroll + dx
		Line()
	end
	f:SetScript("OnMouseWheel", function(self, delta) self:ScrollBy(-delta * TAB.WHEEL) end)
	for i, label in ipairs(labels) do Make(i, label) end
	if not strip then
		local rule = f:CreateTexture(nil, "BACKGROUND")
		Theme.Paint(rule, C.border, 0.7)
		rule:SetSize(width or 580, 1)
		rule:SetPoint("BOTTOMLEFT")
	end
	Line()

	function f:Select(i)
		self.selected = i
		for j, t in ipairs(self.tabs) do
			t.bar:SetShown(j == i)
			if t.glow then t.glow:SetShown(j == i) end
			Theme.Ink(t.text, j == i and t.inkOpen or t.inkRest)
		end
		if self.room then self:Reveal(i) end
		onSelect(i)
	end
	function f:Reveal(i)
		local t = self.tabs[i]
		if not (t and t:IsShown() and self.overflow) then return end
		local x = 0
		for j = 1, i - 1 do
			if self.tabs[j]:IsShown() then x = x + self.tabs[j]:GetWidth() + gap end
		end
		-- Clear of the fade on either side, unless it is the first or last.
		local w = t:GetWidth()
		if x - self.scroll < (x > 0 and TAB.FADE or 0) then
			self.scroll = x - (x > 0 and TAB.FADE or 0)
		elseif x + w - self.scroll > self.room - TAB.FADE then
			self.scroll = x + w - self.room + TAB.FADE
		end
		Line()
	end
	function f:SetRoom(room)
		if self.room == room then return end
		self.room = room
		self:SetClipsChildren(room ~= nil)
		Line()
		if self.selected then self:Reveal(self.selected) end
	end
	-- Tab i's words in a color of their own (a whisper's): `open` while it is the open one or under the mouse, `rest`
	-- otherwise. nil: the strip's inks again.
	function f:SetInk(i, open, rest)
		local t = self.tabs[i]
		if not t then return end
		if not t.made then t.made = { t.inkRest, t.inkHot, t.inkOpen } end
		if open then
			t.inkRest, t.inkHot, t.inkOpen = rest or open, open, open
		else
			t.inkRest, t.inkHot, t.inkOpen = t.made[1], t.made[2], t.made[3]
		end
		Theme.Ink(t.text, self.selected == i and t.inkOpen or t.inkRest)
	end
	function f:SetTint(i, color)
		local t = self.tabs[i]
		if not (t and t.glow) then return end
		t.bar.shyColor = color or Theme.light
		Theme.Tint(t.bar, t.bar.shyColor, 1)
		Theme.Tint(t.glow, color or C.hot)
	end
	-- Other tabs in place of these (a window's conversations come and go): a tab is made for each label
	-- beyond those made before, the rest are hidden. Nothing is selected again: Select once they are set.
	-- Returns the tabs, so the caller can give a new one scripts of its own.
	function f:SetLabels(list)
		for i, label in ipairs(list) do
			local t = self.tabs[i] or Make(i, label)
			t.text:SetText(label)
			t.badgeWidth = nil
			t:SetWidth(t.text:GetStringWidth() + sides + (t.badge and t.badge:IsShown() and 24 or 0))
			t:Show()
		end
		for i = #list + 1, #self.tabs do
			self.tabs[i]:Hide()
			if self.tabs[i].badge then self.tabs[i].badge:Hide() end
		end
		if self.selected and self.selected > #list then self.selected = nil end
		Line()
		return self.tabs
	end
	-- Each tab as wide as its words: measured again in another font, the ones after it moved along.
	UI.KeyWords(f, function(self)
		for _, t in ipairs(self.tabs) do
			t.badgeWidth = nil
			t:SetWidth(t.text:GetStringWidth() + sides + (t.badge and t.badge:IsShown() and 24 or 0))
		end
		Line()
	end)
	-- A count on a tab (unread replies): gold, after the words. The tab grows to hold it and the
	-- tabs after it move along; nothing is shown for zero.
	-- A quiet count after a tab's words (how many it holds), dim; the tab grows for it. nil: none.
	-- A tab's room for what follows its words (a quiet count, a badge): the tab grows by it and the words step left by
	-- half of it, so words and all sit in the tab's middle. One place for both, so neither undoes the other's room.
	local function Fit(t)
		if t.badge then
			-- The badge after the count when there is one, else after the words.
			t.badge:ClearAllPoints()
			t.badge:SetPoint("LEFT", (t.count and t.count:IsShown()) and t.count or t.text, "RIGHT", 6, 0)
		end
		local room = 0
		if t.count and t.count:IsShown() then room = room + t.count:GetStringWidth() + 4 end
		if t.badge and t.badge:IsShown() then room = room + 24 end
		local want = t.text:GetStringWidth() + sides + room
		if t.fitted == want and t.fittedRoom == room then return end
		t.fitted, t.fittedRoom = want, room
		t.text:ClearAllPoints()
		if opts.mid then
			t.text:SetPoint("CENTER", t, "TOP", -room / 2, -opts.mid)
		else
			t.text:SetPoint("CENTER", -room / 2, 2)
		end
		t:SetWidth(want)
		Line()
	end
	function f:SetCount(i, n)
		local t = self.tabs[i]
		if not t then return end
		if not t.count then
			t.count = UI.Words(t, UI.NameFont(10), C.dim)
			t.count:SetPoint("LEFT", t.text, "RIGHT", 4, 0)
		end
		local text = n and tostring(n) or ""
		if t.count:GetText() == text and t.count:IsShown() == (n ~= nil) then return end
		t.count:SetText(text)
		t.count:SetShown(n ~= nil)
		Fit(t)
	end
	function f:SetBadge(i, n)
		local t = self.tabs[i]
		if not t then return end
		if not t.badge then
			local badge = CreateFrame("Frame", nil, t)
			badge:SetSize(18, 18)
			badge.bg = badge:CreateTexture(nil, "BACKGROUND")
			badge.bg:SetAllPoints()
			Theme.Paint(badge.bg, C.alert)
			badge.text = UI.Text(badge, "", 11, true, C.onAlert)
			badge.text:SetShadowColor(0, 0, 0, 0)   -- no shadow under dark text on gold
			badge.text:SetPoint("CENTER")
			t.badge = badge
		end
		local shown = (n or 0) > 0
		t.badge:SetShown(shown)
		t.badge.text:SetText(shown and n or "")
		Fit(t)
	end
	return f
end

-- Rail: a window's rooms down its left side, one open at a time: a column flush with the window's edge (the
-- caller draws the rule down its right), the rows edge to edge. A row is its glyph, its name and a few words
-- under that (what it holds now), with a check at its right end once it is done. Rows may stand in groups, each
-- under a quiet caption. The open one is lifted: a bar of your color down the column's edge with the color
-- washing in from there, its glyph lit and glowing. Under the mouse a row lifts a little. A click opens a row.
--   local rail = UI.Rail(parent, onSelect, opts)   -- opts.width (220), opts.height;
--                                                  -- opts.again: a click on the open row tells onSelect again
--   rail:SetItems({ { key = "theme", label = "Theme", sub = "Forged", glyph = "star" }, { caption = "Your screen" }, ... })
--                              -- top down, made as needed; an item with a caption alone heads a group
--   rail:SetSubs({ theme = "Forged", ... })   -- the words under each again, by key (a pick changed)
--   rail:Select(key, quiet)    -- open it, and onSelect(key) unless quiet
--   rail:SetDone(key, done)    -- checked off, or not
--   rail:SetKids(key, { { key = "moving", label = "How you move" }, ... })   -- what a row holds, a line each: they
--                              -- hang under it on a fine branch while it is open (unfolding as it opens, folding
--                              -- as another does; a click on the open row folds or unfolds them, a caret at its
--                              -- right turning with them); a click on one tells opts.onKid(key, kid)
--   rail:SetKid(kid)           -- the one in view: marked on the branch, its words lit
--   rail.selected              -- the open row's key;   rail.tall: how far down its rows reach
--   UI.GlyphArt(texture, name) -- a glyph by name on a texture, sized as it was drawn for: a hover glyph
--                              -- (Shy.Hover.GLYPHS), a menu glyph (UI.MENU_GLYPHS), else a file's path (sized by
--                              -- the caller). Returns the size it gave, or nil for a file
-- A row, a caption, the glyph's middle and where the words begin from a row's left; a glyph's size by its sheet.
-- KID: a held line's height; TICK: its branch's length; FOLD: seconds to unfold or fold; CARET: the caret's size.
local RAIL = { ROW = 40, CAPTION = 26, MID = 24, WORDS = 46, HOVER = 14, MENU = 16, KID = 26, TICK = 12, FOLD = 0.22,
	CARET = 10, lists = setmetatable({}, { __mode = "k" }) }

function UI.GlyphArt(texture, name)
	local Hover = Shy.Hover
	if not RAIL.hovers and Hover then
		RAIL.hovers = { check = true }
		for _, glyph in ipairs(Hover.GLYPHS) do RAIL.hovers[glyph] = true end
	end
	if RAIL.hovers and RAIL.hovers[name] then
		Hover.Glyph(texture, name, RAIL.HOVER)
		texture:SetSize(RAIL.HOVER, RAIL.HOVER)
		return RAIL.HOVER
	elseif MENU_CELL[name] then
		local layer = UI.MenuGlyph(name)[1]
		texture:SetTexture(layer[1])
		texture:SetTexCoord(layer.coords[1], layer.coords[2], layer.coords[3], layer.coords[4])
		texture:SetSize(RAIL.MENU, RAIL.MENU)
		return RAIL.MENU
	end
	texture:SetTexture(name)
	texture:SetTexCoord(0, 1, 0, 1)
end

-- A page coming up: its alpha from none to whole over `seconds`. The fade is the page's own, never that of
-- a frame holding every page (the game takes the beginning of a fade through all a frame holds, the pages out
-- of sight too: 226 ms of every room opened in the /shy window). One whose beginning still costs more than a
-- frame (FADE_IN.most ms) is not faded again this session: it shows at once.
local FADE_IN = { most = 8 }
function UI.FadeIn(frame, seconds)
	if frame.shyPlain then return end
	local fade = frame.shyFade
	if not fade then
		fade = frame:CreateAnimationGroup()
		local alpha = fade:CreateAnimation("Alpha")
		alpha:SetFromAlpha(0)
		alpha:SetToAlpha(1)
		alpha:SetDuration(seconds)
		frame.shyFade = fade
	end
	if fade:IsPlaying() then fade:Stop() end
	local from = debugprofilestop()
	fade:Play()
	if debugprofilestop() - from > FADE_IN.most then frame.shyPlain = true end
end

function UI.Rail(parent, onSelect, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(opts.width or 220, opts.height or 400)
	f.rows, f.captions, f.done, f.byKey, f.tall = {}, {}, {}, {}, 0
	f.order = {}             -- what stands down the rail, top down: { row = } or { caption = }
	f.kids, f.share, f.goal = {}, {}, {}   -- by row's key: its held lines; how far they are unfolded (0 to 1); where to

	local function Row()
		local row = CreateFrame("Button", nil, f)
		row:SetHeight(RAIL.ROW)
		-- The lift under the open row and the one under the mouse; over it the open row's wash, your color in
		-- from its left edge, and the bar of it there.
		row.lift = row:CreateTexture(nil, "BACKGROUND")
		row.lift:SetAllPoints()
		row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.wash:SetAllPoints()
		row.wash:SetColorTexture(1, 1, 1, 1)
		row.bar = row:CreateTexture(nil, "ARTWORK")
		row.bar:SetWidth(3)
		row.bar:SetPoint("TOPLEFT")
		row.bar:SetPoint("BOTTOMLEFT")
		row.bar:SetColorTexture(1, 1, 1, 1)
		row.glow = row:CreateTexture(nil, "ARTWORK")
		row.glow:SetTexture(B.GLOW)
		row.glow:SetBlendMode("ADD")
		row.glow:SetSize(RAIL.ROW + 6, RAIL.ROW + 6)
		row.glow:SetPoint("CENTER", row, "LEFT", RAIL.MID, 0)
		row.glyph = row:CreateTexture(nil, "OVERLAY")
		row.glyph:SetPoint("CENTER", row, "LEFT", RAIL.MID, 0)
		row.check = row:CreateTexture(nil, "OVERLAY")
		row.check:SetTexture(Shy.MEDIA .. "GlyphCheckS")   -- drawn for 12 units
		row.check:SetSize(12, 12)
		row.check:SetPoint("RIGHT", -12, 0)
		-- The caret of a row that holds lines: across while they are folded, down once they hang.
		row.caret = row:CreateTexture(nil, "OVERLAY")
		row.caret:SetTexture(Shy.Skin.GLYPH.caret)
		row.caret:SetSize(RAIL.CARET, RAIL.CARET)
		row.caret:SetPoint("RIGHT", -12, 0)
		row.label = UI.TitleText(row, "", 14, C.dim)
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(false)
		row.sub = UI.Text(row, "", 11, false, C.dim)
		row.sub:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
		row.sub:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		row.sub:SetJustifyH("LEFT")
		row.sub:SetWordWrap(false)
		-- What it holds: a frame under it that cuts its lines to how far they are unfolded.
		row.hold = CreateFrame("Frame", nil, f)
		row.hold:SetClipsChildren(true)
		row.hold:SetPoint("TOPLEFT", row, "BOTTOMLEFT")
		row.hold:SetPoint("RIGHT", f, "RIGHT")
		row.hold:SetHeight(1)
		row.hold:Hide()
		row.hold.lines = {}
		row.hold.trunk = row.hold:CreateTexture(nil, "ARTWORK")
		row.hold.trunk:SetWidth(1)
		row:SetScript("OnClick", function(self)
			if f.selected == self.key and f.kids[self.key] then   -- the open row: what it holds folds or unfolds
				Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
				f:Fold(self.key, f.goal[self.key] == 1)
				return
			end
			if f.selected == self.key and not opts.again then return end
			Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			f:Select(self.key)
		end)
		row:SetScript("OnEnter", function(self)
			self.hover = true
			f:Paint()
		end)
		row:SetScript("OnLeave", function(self)
			self.hover = false
			f:Paint()
		end)
		f.rows[#f.rows + 1] = row
		return row
	end

	-- A held line: its words where a row's begin, a tick from the branch to them, a mark on the branch while it is
	-- the one in view.
	local function Line(row, i)
		local line = row.hold.lines[i]
		if line then return line end
		line = CreateFrame("Button", nil, row.hold)
		line:SetHeight(RAIL.KID)
		line:SetPoint("TOPLEFT", 0, -(i - 1) * RAIL.KID)
		line:SetPoint("RIGHT")
		line.lift = line:CreateTexture(nil, "BACKGROUND")
		line.lift:SetAllPoints()
		line.tick = line:CreateTexture(nil, "ARTWORK")
		line.tick:SetHeight(1)
		line.tick:SetWidth(RAIL.TICK)
		line.tick:SetPoint("LEFT", RAIL.MID, 0)
		line.mark = line:CreateTexture(nil, "OVERLAY")
		line.mark:SetSize(3, RAIL.KID - 10)
		line.mark:SetPoint("CENTER", line, "LEFT", RAIL.MID, 0)
		line.mark:SetColorTexture(1, 1, 1, 1)
		line.label = UI.Text(line, "", 12)
		line.label:SetPoint("LEFT", RAIL.WORDS, 0)
		line.label:SetPoint("RIGHT", -12, 0)
		line.label:SetJustifyH("LEFT")
		line.label:SetWordWrap(false)
		line:SetScript("OnClick", function(self)
			Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			f.kid = self.key
			f:Paint()
			if opts.onKid then opts.onKid(row.key, self.key) end
		end)
		line:SetScript("OnEnter", function(self)
			self.hover = true
			f:Paint()
		end)
		line:SetScript("OnLeave", function(self)
			self.hover = false
			f:Paint()
		end)
		row.hold.lines[i] = line
		return line
	end

	local function Caption()
		local fs = UI.Text(f, "", 11, true, C.dim)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs.rule = f:CreateTexture(nil, "ARTWORK")
		fs.rule:SetHeight(1)
		Theme.Paint(fs.rule, C.border, 0.6)
		f.captions[#f.captions + 1] = fs
		return fs
	end

	-- Every row as it stands: open, done, under the mouse, or none of them; and the lines it holds.
	-- (Asked at every coming and going of the mouse: only a row, or a line, that stands otherwise than it was
	-- last painted is painted. Every row painted each time was some fifteen colors a row through the theme
	-- and two color objects for its wash, for one row's change.)
	function f:Paint()
		local r, g, b = Theme.Accent()
		for _, row in ipairs(self.rows) do
			local on, done = self.selected == row.key, row.key and self.done[row.key]
			local holds = row.key and self.kids[row.key] ~= nil
			local state = (on and 1 or 0) + (row.hover and 2 or 0) + (done and 4 or 0) + (holds and 8 or 0)
			local was = row.painted
			if not was then
				was = {}
				row.painted = was
			end
			local same = was.state == state and was.key == row.key and was.r == r and was.g == g and was.b == b
			if row.key then
				for _, line in ipairs(row.hold.lines) do
					local lit = line.key ~= nil and line.key == self.kid and on
					local stands = (lit and 1 or 0) + (line.hover and 2 or 0)
					if line.painted ~= stands then
						line.painted = stands
						line.lift:SetShown(line.hover or false)
						Theme.Paint(line.lift, C.row, 0.5)
						Theme.Paint(line.tick, C.border, 0.9)
						line.mark:SetShown(lit)
						Theme.Tint(line.mark, Theme.Accent)
						Theme.Ink(line.label, lit and C.head or line.hover and C.text or C.dim)
					end
				end
			end
			if row.key and not same then
				was.state, was.key, was.r, was.g, was.b = state, row.key, r, g, b
				row.lift:SetShown(on or row.hover or false)
				Theme.Paint(row.lift, C.row, on and 1 or 0.5)
				row.wash:SetShown(on)
				row.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.18), CreateColor(r, g, b, 0.02))
				row.bar:SetShown(on)
				Theme.Tint(row.bar, Theme.Accent)
				Theme.Tint(row.glow, Theme.Accent, 0.4)
				row.glow:SetShown(on)
				Theme.Tint(row.glyph, on and Theme.light or row.hover and C.text or C.dim)
				Theme.Ink(row.label, on and C.head or (done or row.hover) and C.text or C.dim)
				Theme.Ink(row.sub, on and C.text or C.dim)
				Theme.Tint(row.check, C.good)
				row.check:SetShown(done and not on and not holds or false)
				row.caret:SetShown(holds)
				Theme.Tint(row.caret, (on or row.hover) and C.text or C.dim, on and 1 or 0.7)
				Theme.Paint(row.hold.trunk, C.border, 0.9)
			end
		end
	end

	-- A row's words: its name alone on the row's middle, or over the few words under it.
	local function Words(row, sub)
		-- (Kept up several times a second: re-anchored only when the words change.)
		if row.said == (sub or "") then return end
		row.said = sub or ""
		row.sub:SetText(sub or "")
		row.sub:SetShown(sub ~= nil and sub ~= "")
		row.label:ClearAllPoints()
		-- (Both sides at one height: two sides at two heights leave which one holds to the game.)
		local up = row.sub:IsShown() and 7 or 0
		row.label:SetPoint("LEFT", row, "LEFT", RAIL.WORDS, up)
		row.label:SetPoint("RIGHT", row, "RIGHT", -26, up)
	end

	-- Down the rail as it stands now: each row, the lines it holds as far as they are unfolded, each caption.
	local function Ease(t) return t * t * (3 - 2 * t) end
	function f:Layout()
		local y = 0
		for _, item in ipairs(self.order) do
			local row, fs = item.row, item.caption
			if row then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -y)
				row:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				y = y + RAIL.ROW
				local kids = self.kids[row.key]
				local share = kids and Ease(self.share[row.key] or 0) or 0
				local full = kids and #kids * RAIL.KID or 0
				local open = math.floor(full * share + 0.5)
				row.hold:SetShown(open > 0)
				row.hold:SetHeight(math.max(open, 1))
				row.hold:SetAlpha(share)
				row.caret:SetRotation((1 - share) * math.pi / 2)
				y = y + open
			elseif fs then
				fs:ClearAllPoints()
				fs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 14, -(y + RAIL.CAPTION) + 5)
				fs.rule:ClearAllPoints()
				fs.rule:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y - 4)
				fs.rule:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				fs.rule:SetShown(y > 0)
				y = y + RAIL.CAPTION
			end
		end
		self.tall = y
	end

	-- The folding: each row's share moves to its goal over RAIL.FOLD, eased; the clock stops once all arrive.
	local function Step(self, elapsed)
		local moving = false
		for key, goal in pairs(self.goal) do
			local share = self.share[key] or 0
			if share ~= goal then
				local step = elapsed / RAIL.FOLD
				share = goal > share and math.min(goal, share + step) or math.max(goal, share - step)
				self.share[key] = share
				moving = moving or share ~= goal
			end
		end
		self:Layout()
		if not moving then self:SetScript("OnUpdate", nil) end
	end

	-- What a row holds unfolds (open) or folds; at once with `now`.
	function f:Fold(key, shut, now)
		if not self.kids[key] then return end
		self.goal[key] = shut and 0 or 1
		if now then
			self.share[key] = self.goal[key]
			self:Layout()
		else
			self:SetScript("OnUpdate", Step)
		end
	end

	function f:SetItems(items)
		local rows, captions = 0, 0
		wipe(self.byKey)
		wipe(self.order)
		for _, item in ipairs(items) do
			if item.key then
				rows = rows + 1
				local row = self.rows[rows] or Row()
				row.key = item.key
				self.byKey[item.key] = row
				row.label:SetText(item.label or "")
				local sized = UI.GlyphArt(row.glyph, item.glyph or "note")
				if not sized then row.glyph:SetSize(RAIL.MENU, RAIL.MENU) end
				Words(row, item.sub)
				row:Show()
				self.order[#self.order + 1] = { row = row }
			else
				captions = captions + 1
				local fs = self.captions[captions] or Caption()
				fs:SetText((item.caption or ""):upper())
				fs:Show()
				self.order[#self.order + 1] = { caption = fs }
			end
		end
		for i = rows + 1, #self.rows do
			self.rows[i].key = nil
			self.rows[i]:Hide()
			self.rows[i].hold:Hide()
		end
		for i = captions + 1, #self.captions do
			self.captions[i]:Hide()
			self.captions[i].rule:Hide()
		end
		if self.selected and not self.byKey[self.selected] then self.selected = nil end
		self:Layout()
		self:Paint()
	end

	function f:SetKids(key, kids)
		local row = self.byKey[key]
		if not row then return end
		if kids and #kids == 0 then kids = nil end
		self.kids[key] = kids
		for i, kid in ipairs(kids or {}) do
			local line = Line(row, i)
			line.key = kid.key
			line.label:SetText(kid.label or "")
			line:Show()
		end
		for i = #(kids or {}) + 1, #row.hold.lines do
			row.hold.lines[i].key = nil
			row.hold.lines[i]:Hide()
		end
		-- (the branch: from under the row's glyph to the middle of its last line)
		row.hold.trunk:ClearAllPoints()
		row.hold.trunk:SetPoint("TOP", row.hold, "TOPLEFT", RAIL.MID, 0)
		row.hold.trunk:SetHeight(math.max(1, (#(kids or {}) - 0.5) * RAIL.KID))
		if not kids then
			self.goal[key], self.share[key] = nil, nil
		elseif self.selected == key and self.goal[key] == nil then
			self:Fold(key, false)
		end
		self:Layout()
		self:Paint()
	end

	function f:SetKid(kid)
		if self.kid == kid then return end
		self.kid = kid
		self:Paint()
	end

	function f:SetSubs(subs)
		for key, row in pairs(self.byKey) do Words(row, subs[key]) end
	end

	-- Opening a row unfolds what it holds and folds every other's.
	function f:Select(key, quiet)
		if self.selected ~= key then
			self.kid = nil
			for other in pairs(self.kids) do
				if other ~= key then self:Fold(other, true) end
			end
			self:Fold(key, false)
		end
		self.selected = key
		self:Paint()
		if not quiet and onSelect then onSelect(key) end
	end

	function f:SetDone(key, done)
		done = done and true or nil
		if self.done[key] == done then return end
		self.done[key] = done
		self:Paint()
	end

	RAIL.lists[f] = true
	return f
end
Shy:On("SHY_THEME", function()
	for list in pairs(RAIL.lists) do list:Paint() end
end)

-- Text input. Commits on Enter or when focus leaves; Escape reverts. label may be nil.
-- opts.placeholder = function() -> text shown while empty
-- opts.live = true -> call set on every keystroke (search boxes)
-- opts.maxLetters

function UI.Input(parent, label, get, set, opts)
	opts = opts or {}
	local width = opts.width or 260

	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, label and 46 or 24)
	if label then
		f.label = UI.Text(f, label)
		f.label:SetPoint("TOPLEFT")
	end

	local box = CreateFrame("EditBox", nil, f)
	box:SetSize(width, 24)
	box:SetPoint("BOTTOMLEFT")
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlight)
	box:SetTextInsets(8, 8, 0, 0)
	box:SetMaxLetters(opts.maxLetters or 200)
	UI.Skin(box)
	f.box = box

	local placeholder = UI.Text(box, "", nil, false, C.dim)
	placeholder:SetPoint("LEFT", 8, 0)

	local function Commit(self)
		if self:GetText() ~= (get() or "") then set(self:GetText()) end
	end
	box:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
	-- Esc puts back what was there when editing began, which a live box has long since overwritten.
	box:SetScript("OnEscapePressed", function(self)
		local was = self.was or get() or ""
		self:SetText(was)
		if opts.live and was ~= (get() or "") then set(was) end
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusGained", function(self)
		self.was = self:GetText()
		UI.SetBorder(self, C.hot)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		UI.SetBorder(self, C.border)
		Commit(self)
	end)
	box:SetScript("OnTextChanged", function(self, userInput)
		placeholder:SetShown(self:GetText() == "")
		if opts.live and userInput then set(self:GetText()) end
	end)

	function f:Refresh()
		if not box:HasFocus() then box:SetText(get() or "") end
		placeholder:SetText(opts.placeholder and opts.placeholder() or "")
		placeholder:SetShown(box:GetText() == "")
		SetDimmed(self, not IsEnabled(opts))
		box:EnableMouse(not self.dimmed)
	end
	AttachHelp(box, label or "", opts)
	return f
end

-- Segmented: a pill of two or more choices, one lit by a pill of the accent that glides to whichever is
-- picked. Rests on a dark groove with a steel rim; the lit choice's words take the ink that reads on the accent,
-- the others are quiet until the mouse is over them.
--   UI.Segmented(parent, labels, get, set, opts) -> frame
--   get() -> the lit choice's index (false: none lit, the pill put away); set(index) when another is clicked;
--   f:Refresh() reads get again
--   opts.width (120), opts.height (22), opts.tips = { [index] = "hover text" }
function UI.Segmented(parent, labels, get, set, opts)
	opts = opts or {}
	local n = #labels
	local width, height = opts.width or 120, opts.height or 22
	local inset, ease = 2, 16               -- the groove's margin round the lit pill; how fast it glides (per second)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	f.groove = f:CreateTexture(nil, "BACKGROUND")
	f.groove:SetAllPoints()
	Theme.Paint(f.groove, C.bg, 0.9)
	UI.Skin(f)
	UI.SetBorder(f, Theme.skin.metal)
	local seg = (width - inset * 2) / n
	f.pill = f:CreateTexture(nil, "ARTWORK")
	f.pill:SetSize(seg, height - inset * 2)
	Theme.Paint(f.pill, Theme.Accent)
	f.at = nil                                -- where the pill stands now, in choices from the first (nil: not placed)
	local over = nil                          -- the choice under the mouse

	local function Place(at)
		f.at = at
		f.pill:ClearAllPoints()
		f.pill:SetPoint("LEFT", f, "LEFT", inset + at * seg, 0)
	end
	-- The lit choice; nil when none is (get() said false).
	local function Lit()
		local at = get()
		if at == false then return nil end
		return at or 1
	end
	local function Glide(self, elapsed)
		local goal = (Lit() or 1) - 1
		local gap = goal - self.at
		if math.abs(gap) < 0.01 then
			Place(goal)
			self:SetScript("OnUpdate", nil)
		else
			Place(self.at + gap * math.min(1, elapsed * ease))
		end
	end
	local buttons = {}
	local function Inks()
		local lit = Lit()
		for i, b in ipairs(buttons) do
			Theme.Ink(b.text, i == lit and C.onAccent or (over == i and C.text) or C.dim)
		end
	end
	for i, label in ipairs(labels) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(seg, height)
		b:SetPoint("LEFT", f, "LEFT", inset + (i - 1) * seg, 0)
		b:SetFrameLevel(f:GetFrameLevel() + 2)
		b.text = UI.Text(b, label, 11, true)
		b.text:SetPoint("CENTER")
		b:SetScript("OnEnter", function()
			over = i
			Inks()
			if opts.tips and opts.tips[i] then UI.Tip(b, label, opts.tips[i]) end
		end)
		b:SetScript("OnLeave", function()
			over = nil
			Inks()
			UI.TipHide(b)
		end)
		b:SetScript("OnClick", function()
			if Lit() == i then return end
			set(i)
			f:Refresh()
		end)
		buttons[i] = b
	end
	f.buttons = buttons

	function f:Refresh()
		local lit = Lit()
		local goal = (lit or 1) - 1
		-- (None lit: the pill goes, and comes back at the one picked next without gliding from where it stood.)
		self.pill:SetShown(lit ~= nil)
		if not lit then self.at = nil end
		if not self.at or not self:IsVisible() then
			Place(goal)
			self:SetScript("OnUpdate", nil)
		elseif self.at ~= goal then
			self:SetScript("OnUpdate", Glide)
		end
		Inks()
	end
	f:Refresh()
	return f
end

-- Switch: an on/off pill made of the slider's pieces. Its groove fills with the accent as the steel knob
-- slides across, the knob carries the accent's dot while on, and it lights and glows under the mouse as the
-- slider's does. Off, it is grey all through: groove, knob and glow carry none of the accent's hue. The
-- label is only used as the hover title.
-- The pill, and the knob's diameter; SPEED: it runs across in a seventh of a second.
local SWITCH = { W = 36, H = 18, KNOB = 14, SPEED = 7 }

function UI.Switch(parent, label, get, set, opts)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(SWITCH.W, SWITCH.H)
	local cap = SWITCH.H / 2
	-- The slider's groove in three pieces, its ends round.
	local function Groove(sub, color)
		local parts = {}
		for i, u in ipairs({ { 0, 0.25 }, { 0.75, 1 }, { 0.25, 0.75 } }) do
			local t = b:CreateTexture(nil, "BACKGROUND", nil, sub)
			t:SetTexture(Shy.MEDIA .. "SliderTrack")
			t:SetTexCoord(u[1], u[2], 0, 1)
			Theme.Tint(t, color, 1)
			parts[i] = t
		end
		local left, right, middle = parts[1], parts[2], parts[3]
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT")
		left:SetWidth(cap)
		right:SetPoint("TOPRIGHT")
		right:SetPoint("BOTTOMRIGHT")
		right:SetWidth(cap)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
		return parts
	end
	-- Off, the pill is the theme's steel with the accent's hue taken out, so it reads as off in any accent.
	-- run: the hue comes back as the knob runs across (the groove is under the fill by then, and stays grey).
	local function Hueless(color, run)
		return function()
			local r, g, bl = color[1], color[2], color[3]
			local y = 0.299 * r + 0.587 * g + 0.114 * bl
			return Blend(y, y, y, r, g, bl, run and b.pos or 0)
		end
	end
	local tone = {
		inset = Hueless(Theme.skin.inset), glow = Hueless(Theme.light),
		metal = Hueless(Theme.skin.metal, true), lit = Hueless(Theme.skin.lit, true),
	}
	local groove = Groove(0, tone.inset)
	local fill = Groove(1, Theme.Accent)
	-- The knob, its glow and its dot, at the slider's proportions.
	local function Piece(file, size, layer)
		local t = b:CreateTexture(nil, layer)
		t:SetTexture(Shy.MEDIA .. file)
		local s = floor(size * SWITCH.KNOB / SLIDER.knob + 0.5)
		t:SetSize(s, s)
		return t
	end
	local halo = Piece("Glow", SLIDER.halo, "BORDER")
	local knob = Piece("SliderKnob", SLIDER.knobArt, "ARTWORK")
	local dot = Piece("SliderDot", SLIDER.dot, "OVERLAY")
	Theme.Tint(dot, Theme.Accent, 1)
	halo:SetPoint("CENTER", knob, "CENTER")
	dot:SetPoint("CENTER", knob, "CENTER")
	UI.Concentric(knob, dot)
	b.groove, b.knob, b.halo = groove[3], knob, halo

	-- glow: the side the glow is tinted for (the accent once the knob is past the middle, grey light before).
	local over, held, glow = false, false, nil
	local function Look()
		local lit = (over or held) and not b.dimmed
		Theme.Tint(knob, lit and tone.lit or tone.metal, 1)
		-- (A tint sets the glow's alpha: tinted before it, and only when its side changes.)
		local on = b.pos >= 0.5
		if on ~= glow then
			glow = on
			Theme.Tint(halo, on and Theme.Accent or tone.glow, 1)
		end
		halo:SetAlpha(not lit and 0 or (held and 0.7 or 0.45))
	end
	local function Place(pos)
		b.pos = pos
		knob:SetPoint("CENTER", b, "LEFT", cap + pos * (SWITCH.W - 2 * cap), 0)
		for _, t in ipairs(fill) do t:SetAlpha(pos) end
		dot:SetAlpha(pos)
		Look()
	end
	Place(get() and 1 or 0)
	keyed[b] = function(self) Place(self.pos) end

	-- Run across to where get() says, then stop.
	local Run = Shy.Clocked("ui: a switch running", function(self, dt)
		local target = self.target
		local step = dt * SWITCH.SPEED
		Place(target > self.pos and min(target, self.pos + step) or max(target, self.pos - step))
		if self.pos == target then self:SetScript("OnUpdate", nil) end
	end)

	function b:Refresh()
		self.target = get() and 1 or 0
		if self.pos ~= self.target then
			if self:IsVisible() then self:SetScript("OnUpdate", Run) else Place(self.target) end
		end
		SetDimmed(self, not IsEnabled(opts))
		Look()
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		set(not get())
		Sound(get() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
		self:Refresh()
	end)
	b:SetScript("OnEnter", function() over = true; Look() end)
	b:SetScript("OnLeave", function() over = false; Look() end)
	b:SetScript("OnMouseDown", function() held = true; Look() end)
	b:SetScript("OnMouseUp", function() held = false; Look() end)
	-- Hidden while held, or while running: no OnMouseUp follows, and it stands where it was going.
	b:SetScript("OnHide", function(self)
		held = false
		self:SetScript("OnUpdate", nil)
		if self.target then Place(self.target) end
		Look()
	end)
	AttachHelp(b, label or "", opts)
	return b
end

-- UI.ThumbGrip(parent, thumb, opts) -> bar: a slim thumb on parent's right edge, made something to take
-- hold of. A bar down that edge takes the mouse: the thumb drags, a press elsewhere on the bar brings the
-- thumb's middle there and drags on from it, and the wheel over it is the parent's own. Under the mouse
-- and while held the thumb (and opts.track) widen. Show the bar only while there is something to scroll.
--   opts.drag(share)   called as it moves: 0 at the top, 1 at the foot
--   opts.width         the bar's width (10); opts.out: how far it reaches past the edge (0)
local GRIP = {
	w = 10,
	hot = 5,
}

function UI.ThumbGrip(parent, thumb, opts)
	local bar = CreateFrame("Button", nil, parent)
	local out = opts.out or 0
	bar:SetPoint("TOPRIGHT", out, 0)
	bar:SetPoint("BOTTOMRIGHT", out, 0)
	bar:SetWidth(opts.width or GRIP.w)
	bar:SetFrameLevel(parent:GetFrameLevel() + 10)   -- over the rows beside it
	local thin = thumb:GetWidth()
	local grab, over   -- where the thumb is held, down from its top; the mouse on the bar

	local function Wide()
		local w = (grab or over) and GRIP.hot or thin
		thumb:SetWidth(w)
		if opts.track then opts.track:SetWidth(w) end
	end
	local function CursorY()
		local _, y = GetCursorPosition()
		return y / bar:GetEffectiveScale()
	end
	local function Follow()
		local top, height, size = bar:GetTop(), bar:GetHeight(), thumb:GetHeight()
		if issecretvalue(top) or issecretvalue(height) or issecretvalue(size) or height <= size then return end
		opts.drag(max(0, min(1, (top - CursorY() - grab) / (height - size))))
	end
	local function Let()
		grab = nil
		bar:SetScript("OnUpdate", nil)
		Wide()
	end

	bar:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local y, top, size = CursorY(), thumb:GetTop(), thumb:GetHeight()
		if issecretvalue(top) or issecretvalue(size) then return end
		grab = (y <= top and y >= top - size) and top - y or size / 2
		Wide()
		Follow()
		-- Followed every frame while held; a release anywhere lets go.
		self:SetScript("OnUpdate", function()
			if IsMouseButtonDown("LeftButton") then Follow() else Let() end
		end)
	end)
	bar:SetScript("OnMouseUp", Let)
	bar:SetScript("OnHide", function()
		over = nil
		Let()
	end)
	bar:SetScript("OnEnter", function()
		over = true
		Wide()
	end)
	bar:SetScript("OnLeave", function()
		over = nil
		Wide()
	end)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(_, delta)
		local wheel = parent:GetScript("OnMouseWheel")
		if wheel then wheel(parent, delta) end
	end)
	return bar
end

-- Scroll area: wheel scrolling and a slim thumb to drag. Put widgets on area.content, set its height,
-- and call area:Update() after changing it. It may be re-anchored to stretch.
-- Use area:Range() and area:At() instead of the raw getters when comparing (see below).
-- opts (all optional):
--   smooth = true    the wheel glides to where it is going, eased, instead of jumping
--   shades = color   a soft shade at the top and the bottom while there is more that way, fading from
--                    `color` (the surface the area stands on: C.hud for a HUD piece, C.tip for a hover)
--   quiet = true     the wheel is the area's only while it has something to scroll (a HUD piece leaves the
--                    wheel to the camera otherwise)
--   onScroll = f     f(area, offset) after every change of where it is, and of its range
-- area:Reveal(top, bottom)  brings that stretch of the content into view (gliding with smooth)
-- area:Overflows()          whether the content is taller than the area

local SCROLL = { step = 48, ease = 14, shade = 18 }

-- A look's own scroll bar (UI.LookKind's `scroll`): told when an area starts wearing it and when it is put away.
SCROLL.looks = setmetatable({}, { __mode = "k" })   -- area -> the look it wears its bar in
function SCROLL.Look(area)
	local look = Theme.Look()
	if SCROLL.looks[area] == look then return end
	local was = KINDS[SCROLL.looks[area] or ""]
	if was and was.scroll then was.scroll(area, area.thumb, area.track, false) end
	SCROLL.looks[area] = look
	local kind = KINDS[look]
	if kind and kind.scroll then kind.scroll(area, area.thumb, area.track, true) end
end
Shy:On("SHY_THEME", function()
	for area in pairs(SCROLL.looks) do SCROLL.Look(area) end
end)

function UI.ScrollArea(parent, width, height, opts)
	opts = opts or {}
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetSize(width, height)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width - 14, 1)
	scroll:SetScrollChild(content)
	scroll.content = content

	local track = scroll:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("TOPRIGHT")
	track:SetPoint("BOTTOMRIGHT")
	track:SetWidth(3)
	Theme.Paint(track, C.border, 0.5)
	local thumb = scroll:CreateTexture(nil, "ARTWORK")
	thumb:SetWidth(3)
	Theme.Paint(thumb, C.hot, 0.9)
	scroll.thumb, scroll.track = thumb, track
	SCROLL.Look(scroll)

	-- Scroll range and offset become secret numbers while the content holds text sized by a secret
	-- value (chat or names in combat or instances), and secrets can't be compared. These keep the
	-- last readable value.
	local range, at = 0, 0
	function scroll:Range()
		local now = self:GetVerticalScrollRange()
		if not issecretvalue(now) then range = now end
		return range
	end
	function scroll:At()
		local now = self:GetVerticalScroll()
		if not issecretvalue(now) then at = now end
		return at
	end

	-- Where a smooth wheel is gliding to (nil: still).
	local goal
	local function Still()
		goal = nil
		scroll:SetScript("OnUpdate", nil)
	end

	local bar = UI.ThumbGrip(scroll, thumb, { track = track, drag = function(share)
		Still()
		at = share * scroll:Range()
		scroll:SetVerticalScroll(at)
		scroll:Update()
	end })
	bar:Hide()
	scroll.bar = bar

	-- The shades: over the content, under the bar.
	local top, foot
	if opts.shades then
		local over = CreateFrame("Frame", nil, scroll)
		over:SetAllPoints()
		over:SetFrameLevel(scroll:GetFrameLevel() + 8)
		top = over:CreateTexture(nil, "OVERLAY")
		top:SetPoint("TOPLEFT")
		top:SetPoint("TOPRIGHT")
		foot = over:CreateTexture(nil, "OVERLAY")
		foot:SetPoint("BOTTOMLEFT")
		foot:SetPoint("BOTTOMRIGHT")
		for _, shade in ipairs({ top, foot }) do
			shade:SetHeight(SCROLL.shade)
			shade:SetColorTexture(1, 1, 1, 1)
			shade:Hide()
		end
	end
	-- (Painted when shown: the surface's color and its strength follow the theme and the Background setting,
	-- so the shade is the surface itself thickening, never a band on a glassy piece.)
	local function Shade(shade, on, up)
		shade:SetShown(on)
		if not on then return end
		local c = opts.shades
		local solid, clear = CreateColor(c[1], c[2], c[3], (c[4] or 1) * 0.95), CreateColor(c[1], c[2], c[3], 0)
		if up then shade:SetGradient("VERTICAL", clear, solid) else shade:SetGradient("VERTICAL", solid, clear) end
	end

	function scroll:Overflows()
		return self:Range() > 0
	end

	function scroll:Update()
		local far, now = self:Range(), self:At()
		if now > far then
			self:SetVerticalScroll(far)
			now, at = far, far
		end
		track:SetShown(far > 0)
		thumb:SetShown(far > 0)
		bar:SetShown(far > 0)
		if far > 0 then
			local view = self:GetHeight()
			local h = max(24, view * view / (view + far))
			thumb:SetHeight(h)
			thumb:SetPoint("TOPRIGHT", 0, -(view - h) * now / far)
		end
		if top then
			Shade(top, far > 0 and now > 0.5, true)
			Shade(foot, far > 0 and now < far - 0.5, false)
		end
		if opts.quiet then self:EnableMouseWheel(far > 0) end
		if opts.onScroll then opts.onScroll(self, now) end
	end

	-- Eased toward the goal a frame at a time, and still once there.
	local function Glide(self, elapsed)
		if not goal then return Still() end
		local now = self:At()
		local gap = goal - now
		if math.abs(gap) < 0.5 then
			now = goal
			Still()
		else
			now = now + gap * min(1, elapsed * SCROLL.ease)
		end
		at = now
		self:SetVerticalScroll(now)
		self:Update()
	end
	local function Go(to)
		to = max(0, min(scroll:Range(), to))
		if opts.smooth and scroll:IsVisible() then
			goal = to
			scroll:SetScript("OnUpdate", Glide)
		else
			Still()
			at = to
			scroll:SetVerticalScroll(to)
			scroll:Update()
		end
	end

	function scroll:Reveal(from, to)
		local view, now = self:GetHeight(), goal or self:At()
		to = to or from
		if from < now then
			Go(from)
		elseif to > now + view then
			Go(min(from, to - view))
		end
	end

	scroll:EnableMouseWheel(not opts.quiet)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		Go((goal or self:At()) - delta * SCROLL.step)
	end)
	scroll:SetScript("OnScrollRangeChanged", function(self) self:Update() end)
	scroll:HookScript("OnHide", Still)
	return scroll
end

-- Text counted in letters, not bytes: a name comes in any alphabet.
--   UI.Letters(text)               how many letters it has
--   UI.Cut(text, first, last)      its letters first..last, counted from 1
--   UI.ShortName(name, limit)      a name in `limit` letters: one longer, of several words, keeps its last word and
--                                  the initials of the rest ("Lieutenant General Andorov" -> "LG. Andorov"); a single
--                                  long word is cut to the limit
do
	local function Step(text, at)
		local b = text:byte(at)
		if not b then return nil end
		if b <= 127 then return 1 elseif b <= 223 then return 2 elseif b <= 239 then return 3 end
		return 4
	end

	function UI.Letters(text)
		local at, count = 1, 0
		while true do
			local step = Step(text, at)
			if not step then return count end
			at, count = at + step, count + 1
		end
	end

	function UI.Cut(text, first, last)
		local at, index, from = 1, 0, nil
		while index < last do
			local step = Step(text, at)
			if not step then break end
			index = index + 1
			if index == first then from = at end
			at = at + step
		end
		if not from then return "" end
		return text:sub(from, at - 1)
	end

	function UI.ShortName(name, limit)
		if UI.Letters(name) <= limit or not name:find(" ") then return UI.Cut(name, 1, limit) end
		local initials = name:gsub(" *([^ ]+) *", function(word) return UI.Cut(word, 1, 1) end)
		initials = UI.Cut(initials, 1, UI.Letters(initials) - 1)
		-- Padding each space to 28 leaves the last 15 characters holding only the last word.
		local padded = name:gsub(" ", (" "):rep(28))
		local length = UI.Letters(padded)
		local last = UI.Cut(padded, math.max(1, length - 14), length):gsub(" ", "")
		return initials .. ". " .. UI.Cut(last, 1, limit)
	end
end

-- Copy box: a movable popup of lines to select and copy with Ctrl+C.
--
-- An edit box's own selection highlight is misplaced on lines with Chinese, Korean or Cyrillic
-- text, so the lines are drawn as font strings, one row each, with our own row highlight. Ctrl+C
-- copies from a hidden edit box that always holds the selected rows, fully selected.

-- Strips chat markup: links keep their label; colors and icons are removed.
function UI.PlainText(text)
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	return text
end

local COPY_BOX = {
	w = 640,
	h = 420,
	padX = 6,
	padY = 2,  -- padding around each row's text
}

local CopyBox = {}

function CopyBox:Row(i)
	local row = self.rows[i]
	if row then return row end
	local content = self.scroll.content
	row = CreateFrame("Button", nil, content)
	row.lit = row:CreateTexture(nil, "BACKGROUND")
	row.lit:SetAllPoints()
	Theme.Paint(row.lit, C.fill, 0.4)
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	Theme.Paint(hover, C.hot, 0.1)
	row.text = UI.Words(row, ChatFontNormal, C.text)
	row.text:SetPoint("TOPLEFT", COPY_BOX.padX, -COPY_BOX.padY)
	row.text:SetWidth(content:GetWidth() - 2 * COPY_BOX.padX)
	row.text:SetNonSpaceWrap(true)
	row:SetScript("OnMouseDown", function() self:Press(i) end)
	self.rows[i] = row
	return row
end

function CopyBox:Fill(text)
	local content = self.scroll.content
	self.lines, self.tops = {}, {}
	for line in (text .. "\n"):gmatch("(.-)\n") do self.lines[#self.lines + 1] = line end
	local top = 0
	for i, line in ipairs(self.lines) do
		local row = self:Row(i)
		row.text:SetText(line)
		local height = max(row.text:GetStringHeight(), 12) + 2 * COPY_BOX.padY
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
		row:SetSize(content:GetWidth(), height)
		row:Show()
		self.tops[i] = top
		top = top + height
	end
	for i = #self.lines + 1, #self.rows do self.rows[i]:Hide() end
	content:SetHeight(max(1, top))
end

function CopyBox:Status(copied)
	local total, picked = #self.lines, abs(self.last - self.anchor) + 1
	local what = picked == total and (total == 1 and "This line" or ("All " .. total .. " lines"))
		or (picked == 1 and "1 line" or (picked .. " lines"))
	Theme.Ink(self.status, copied and C.good or C.dim)
	self.status:SetText(copied and ("Copied: " .. what:lower() .. ".") or (what .. " selected."))
end

-- from and to in either order.
function CopyBox:Select(from, to)
	self.anchor, self.last = from, to
	local first, final = min(from, to), max(from, to)
	for i = 1, #self.lines do self.rows[i].lit:SetShown(i >= first and i <= final) end
	self.edit:SetText(table.concat(self.lines, "\n", first, final))
	self.edit:SetFocus()
	self.edit:HighlightText()
	self:Status()
end

-- Shift extends the current selection.
function CopyBox:Press(i)
	self:Select(IsShiftKeyDown() and self.anchor or i, i)
	self.dragging = true
end

-- The row at this offset below the top of the first (binary search).
function CopyBox:RowAt(offset)
	local low, high = 1, #self.lines
	while low < high do
		local mid = floor((low + high + 1) / 2)
		if self.tops[mid] <= offset then low = mid else high = mid - 1 end
	end
	return low
end

-- Extends the selection to the row under the mouse; scrolls when dragged past the top or bottom.
function CopyBox:Drag(elapsed)
	if not IsMouseButtonDown("LeftButton") then
		self.dragging = nil
		return
	end
	local scroll = self.scroll
	local _, y = GetCursorPosition()
	y = y / scroll:GetEffectiveScale()
	local top, bottom = scroll:GetTop(), scroll:GetBottom()
	if y > top or y < bottom then
		local step = (y > top and top - y or bottom - y) * elapsed * 12
		scroll:SetVerticalScroll(max(0, min(scroll:Range(), scroll:At() + step)))
		scroll:Update()
	end
	local row = self:RowAt(scroll:At() + top - max(bottom, min(top, y)))
	if row ~= self.last then self:Select(self.anchor, row) end
end

-- UI.Spinner(parent, size) -> frame: something is on its way. A comet of the accent turning round a
-- faint ring of it, a spark of light at its head; it turns while shown (the game turns it, so it costs
-- nothing a frame). Follows the theme. size: units square (24 if nil).
local SPIN = {
	art = Shy.MEDIA .. "Spinner",
	seconds = 0.9,  -- a turn
	track = 0.18,  -- the ring under the comet
}
function UI.Spinner(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size or 24, size or 24)
	local track = f:CreateTexture(nil, "ARTWORK")
	track:SetAllPoints()
	track:SetTexture(SPIN.art .. "Track", nil, nil, "TRILINEAR")
	UI.Tint(track, Theme.skin.on, SPIN.track)
	local turning = {}
	for i, part in ipairs({ { "Arc", Theme.skin.on, 1 }, { "Head", Theme.light, 0.9 } }) do
		local t = f:CreateTexture(nil, "ARTWORK", nil, i)
		t:SetAllPoints()
		t:SetTexture(SPIN.art .. part[1], nil, nil, "TRILINEAR")
		UI.Tint(t, part[2], part[3])
		local group = t:CreateAnimationGroup()
		local turn = group:CreateAnimation("Rotation")
		turn:SetDegrees(-360)
		turn:SetDuration(SPIN.seconds)
		group:SetLooping("REPEAT")
		turning[i] = group
	end
	-- (Both started together, of one length: the spark stays on the head.)
	local function Turn()
		for _, group in ipairs(turning) do group:Play() end
	end
	f:SetScript("OnShow", Turn)
	f:SetScript("OnHide", function()
		for _, group in ipairs(turning) do group:Stop() end
	end)
	if f:IsVisible() then Turn() end
	return f
end

local function CreateCopyBox()
	local f = Mixin(CreateFrame("Frame", nil, UIParent), CopyBox)
	f:SetSize(COPY_BOX.w, COPY_BOX.h)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	local head = UI.Head(f, { size = "window", title = "", close = function() f:Hide() end })
	-- What it holds stands on its body, clear of the look's work round the edge, the box that much bigger (UI.Body).
	local body = UI.Body(f)
	UI.BodyFit(f, COPY_BOX.w, COPY_BOX.h)
	f.rows = {}
	f.title = head.title
	local hint = UI.Text(head, "Click or drag to select  \194\183  Ctrl+A for all  \194\183  Ctrl+C to copy", 12, false, C.dim)
	hint:SetPoint("RIGHT", head.close, "LEFT", -10, 0)
	f.status = UI.Text(body, "", 12, false, C.dim)
	f.status:SetPoint("BOTTOMLEFT", 14, 10)

	local top = head:GetHeight() + 10
	f.scroll = UI.ScrollArea(body, COPY_BOX.w - 28, COPY_BOX.h - top - 32)
	f.scroll:SetPoint("TOPLEFT", 14, -top)

	-- The edit box Ctrl+C copies from. It has keyboard focus while the box is open, so it also
	-- handles Ctrl+A and Esc. It sits invisible in a 1x1 scroll frame.
	local holder = CreateFrame("ScrollFrame", nil, f)
	holder:SetSize(1, 1)
	holder:SetPoint("BOTTOMRIGHT")
	holder:SetAlpha(0)
	local edit = CreateFrame("EditBox", nil, holder)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(COPY_BOX.w)
	holder:SetScrollChild(edit)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	edit:SetScript("OnKeyDown", function(_, key)
		if not (IsControlKeyDown() or IsMetaKeyDown()) then return end
		if key == "A" then
			f:Select(1, #f.lines)
		elseif key == "C" then
			f:Status(true)
		end
	end)
	-- Typing would replace the selection: restore it.
	edit:SetScript("OnTextChanged", function(_, typed)
		if typed then f:Select(f.anchor, f.last) end
	end)
	f.edit = edit

	f:SetScript("OnUpdate", function(self, elapsed)
		if self.dragging then self:Drag(elapsed) end
	end)
	f:SetScript("OnHide", function(self) self.dragging = nil end)
	return f
end

function UI.ShowCopyBox(title, text)
	local f = UI.copyBox
	if not f then
		f = CreateCopyBox()
		UI.copyBox = f
	end
	f.title:SetText(title)
	f:Show()
	f:Fill(text)
	f:Select(1, #f.lines)
	-- Scroll to the newest lines, one frame later: the range isn't known until the rows are laid out.
	C_Timer.After(0, function()
		f.scroll:SetVerticalScroll(f.scroll:GetVerticalScrollRange())
		f.scroll:Update()
	end)
end

-- A copy field: a word, a link or a few lines to copy, laid over the piece that shows them with all of it selected,
-- so Ctrl+C takes it (an addon is given no clipboard of its own to write). It says so at its end, says "Copied" as
-- the keys are pressed and goes a moment after; Escape, a click anywhere else, the keyboard taken elsewhere or its
-- piece going out of sight put it away too.
--   UI.CopyField(owner, text, opts) -> the field   -- owner: the frame or region it lies over, from its top left
--       opts.width   at least this wide (the owner's width, and never under COPY.least)
--       opts.cursor  it stands at the cursor, not on the owner (a link in a line of chat); the owner going out of
--                    sight still puts it away
--   UI.CopyFieldOf() -> the field while one is up (.owner, .text), else nil;   UI.CopyFieldClose()
do
	local COPY = { hint = "Ctrl+C to copy", done = "Copied", least = 170, row = 22, pad = 7, gap = 10, stay = 0.7, size = 12 }
	local field

	local function Close()
		if not (field and field.owner) then return end
		field.owner, field.text = nil, nil
		field:Hide()
	end
	UI.CopyFieldClose = Close

	function UI.CopyFieldOf()
		return field and field.owner and field or nil
	end

	local function Make()
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetFrameStrata("DIALOG")
		f:SetToplevel(true)
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		-- (Solid under its field's fill: what it lies over must not show through.)
		f.back = f:CreateTexture(nil, "BACKGROUND", nil, -8)
		f.back:SetAllPoints()
		Theme.Paint(f.back, C.panel, 1)
		UI.Skin(f, C.bg, C.hot)
		f.hint = UI.Text(f, COPY.hint, 10, false, C.dim)
		f.measure = f:CreateFontString(nil, "BACKGROUND")
		f.measure:SetFontObject(UI.TextFont(COPY.size))
		f.measure:SetJustifyH("LEFT")
		f.measure:SetAlpha(0)
		local edit = CreateFrame("EditBox", nil, f)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(UI.TextFont(COPY.size))
		edit:SetJustifyH("LEFT")
		Theme.Ink(edit, C.head)
		edit:SetScript("OnEscapePressed", Close)
		edit:SetScript("OnEditFocusLost", Close)
		edit:SetScript("OnKeyDown", function(_, key)
			if key ~= "C" or not (IsControlKeyDown() or IsMetaKeyDown()) then return end
			f.hint:SetText(COPY.done)
			Theme.Ink(f.hint, C.good)
			local text = f.text
			C_Timer.After(COPY.stay, function()
				if f.text == text then Close() end
			end)
		end)
		-- Typing would replace what is selected: it is put back, selected.
		edit:SetScript("OnTextChanged", function(self, typed)
			if not typed or not f.text then return end
			self:SetText(f.text)
			self:HighlightText()
		end)
		f.edit = edit
		f:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
		f:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
		f:SetScript("OnEvent", function(self)
			if not self:IsMouseOver() then Close() end
		end)
		f:SetScript("OnUpdate", function(self)
			if self.owner and not self.owner:IsVisible() then Close() end
		end)
		f:Hide()
		return f
	end

	function UI.CopyField(owner, text, opts)
		opts = opts or {}
		field = field or Make()
		local f = field
		f.owner, f.text = owner, text
		local wide, tall = owner:GetWidth(), owner:GetHeight()
		if issecretvalue(wide) or not wide then wide = COPY.least end
		if issecretvalue(tall) or not tall then tall = COPY.row end
		if opts.cursor then wide, tall = 0, COPY.row end
		wide = max(COPY.least, opts.width or 0, wide)
		f.hint:SetText(COPY.hint)
		Theme.Ink(f.hint, C.dim)
		local hint = math.ceil(f.hint:GetStringWidth())
		-- On one line where it fits beside the hint; else its lines down the field, the hint under them.
		f.measure:SetWidth(0)
		f.measure:SetWordWrap(false)
		f.measure:SetText(text)
		local line = math.ceil(f.measure:GetStringWidth())
		local one = not text:find("\n", 1, true) and line + hint + 2 * COPY.pad + COPY.gap <= max(wide, COPY.least * 2)
		f.edit:ClearAllPoints()
		f.hint:ClearAllPoints()
		if one then
			wide = max(wide, line + hint + 2 * COPY.pad + COPY.gap)
			tall = max(tall, COPY.row)
			f.edit:SetPoint("LEFT", COPY.pad, 0)
			f.edit:SetWidth(line + 4)
			f.hint:SetPoint("RIGHT", -COPY.pad, 0)
		else
			f.measure:SetWidth(wide - 2 * COPY.pad)
			f.measure:SetWordWrap(true)
			f.measure:SetText(text)
			tall = max(tall, math.ceil(f.measure:GetStringHeight()) + 2 * COPY.pad + 14)
			f.edit:SetPoint("TOPLEFT", COPY.pad, -COPY.pad)
			f.edit:SetWidth(wide - 2 * COPY.pad)
			f.hint:SetPoint("BOTTOMRIGHT", -COPY.pad, 5)
		end
		f:SetSize(wide, tall)
		f:ClearAllPoints()
		if opts.cursor then
			local x, y = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			f:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / s - COPY.pad, y / s)
		else
			f:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
		end
		f:Show()
		f:Raise()
		f.edit:SetText(text)
		f.edit:SetFocus()
		f.edit:HighlightText()
		return f
	end
end

-- A write field: a line to type, laid over the piece it is for (a note's pin), in the copy field's look, what is
-- there now selected. Enter keeps it (done(text), trimmed); Escape, a click elsewhere or the piece going out of
-- sight let it go (done(nil)). One at a time: another closes the first as let go.
--   UI.WriteField(owner, text, done, opts) -> the field   opts.width (WRITE.wide), opts.hint ("Enter to keep"),
--       opts.most (letters, WRITE.most); UI.WriteFieldOf() -> the field while one is up, else nil
do
	local WRITE = { hint = "Enter to keep", wide = 240, most = 120, row = 24, pad = 7, size = 12 }
	local field

	local function Finish(text)
		local f = field
		if not (f and f.owner) then return end
		local done = f.done
		f.owner, f.done = nil, nil
		f:Hide()
		if done then done(text) end
	end

	function UI.WriteFieldOf()
		return field and field.owner and field or nil
	end

	local function Make()
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetFrameStrata("DIALOG")
		f:SetToplevel(true)
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f.back = f:CreateTexture(nil, "BACKGROUND", nil, -8)
		f.back:SetAllPoints()
		Theme.Paint(f.back, C.panel, 1)
		UI.Skin(f, C.bg, C.hot)
		f.hint = UI.Text(f, WRITE.hint, 10, false, C.dim)
		f.hint:SetPoint("RIGHT", -WRITE.pad, 0)
		local edit = CreateFrame("EditBox", nil, f)
		edit:SetAutoFocus(false)
		edit:SetFontObject(UI.TextFont(WRITE.size))
		edit:SetJustifyH("LEFT")
		edit:SetPoint("LEFT", WRITE.pad, 0)
		edit:SetPoint("RIGHT", f.hint, "LEFT", -WRITE.pad, 0)
		edit:SetHeight(WRITE.row)
		Theme.Ink(edit, C.head)
		edit:SetScript("OnEnterPressed", function(self) Finish(strtrim(self:GetText() or "")) end)
		edit:SetScript("OnEscapePressed", function() Finish(nil) end)
		f.edit = edit
		f:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
		f:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
		f:SetScript("OnEvent", function(self)
			if not self:IsMouseOver() then Finish(nil) end
		end)
		f:SetScript("OnUpdate", function(self)
			if self.owner and not self.owner:IsVisible() then Finish(nil) end
		end)
		f:Hide()
		return f
	end

	function UI.WriteField(owner, text, done, opts)
		opts = opts or {}
		Finish(nil)
		field = field or Make()
		local f = field
		f.owner, f.done = owner, done
		f.hint:SetText(opts.hint or WRITE.hint)
		f.edit:SetMaxLetters(opts.most or WRITE.most)
		f:SetSize(opts.width or WRITE.wide, WRITE.row + 4)
		f:ClearAllPoints()
		f:SetPoint("LEFT", owner, "RIGHT", 6, 0)
		f:Show()
		f:Raise()
		f.edit:SetText(text or "")
		f.edit:SetFocus()
		f.edit:HighlightText()
		return f
	end
end

-- A question to be sure of, laid under the piece it is about: a sentence or two, the button that does it and
-- Cancel. Enter does it; Escape, Cancel, a click elsewhere, a fight or the piece going out of sight let it go.
-- One at a time: another lets the first go.
--   UI.Confirm(owner, text, yes, done, opts) -> the card   yes: the button's words; done(): on yes only
--       opts.width (ASK.wide), opts.no ("Cancel"), opts.cancel(): called when it is let go
--   UI.ConfirmOf() -> the card while one is up, else nil;   UI.ConfirmClose() lets it go
do
	local ASK = { wide = 300, pad = 12, gap = 10, button = 24, least = 90, size = 12, apart = 6 }
	local card

	local function Finish(yes)
		local f = card
		if not (f and f.owner) then return end
		local done, cancel = f.done, f.cancel
		f.owner, f.done, f.cancel = nil, nil, nil
		f:Hide()
		if yes then
			if done then done() end
		elseif cancel then
			cancel()
		end
	end
	UI.ConfirmClose = function() Finish(false) end

	function UI.ConfirmOf()
		return card and card.owner and card or nil
	end

	local function Make()
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetFrameStrata("DIALOG")
		f:SetToplevel(true)
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f.back = f:CreateTexture(nil, "BACKGROUND", nil, -8)
		f.back:SetAllPoints()
		Theme.Paint(f.back, C.panel, 1)
		UI.Skin(f, C.bg, C.hot)
		f.text = UI.Text(f, "", ASK.size, false, C.text)
		f.text:SetPoint("TOPLEFT", ASK.pad, -ASK.pad)
		f.text:SetJustifyH("LEFT")
		f.text:SetWordWrap(true)
		f.no = UI.Button(f, "Cancel", ASK.least, function() Finish(false) end)
		f.no:SetPoint("BOTTOMRIGHT", -ASK.pad, ASK.pad)
		f.yes = UI.Button(f, "", ASK.least, function() Finish(true) end)
		f.yes:SetPoint("RIGHT", f.no, "LEFT", -ASK.apart, 0)
		-- (a modal: it has the keyboard while it is up, Enter and Escape its own)
		f:SetScript("OnKeyDown", function(_, key)
			if key == "ENTER" then
				Finish(true)
			elseif key == "ESCAPE" then
				Finish(false)
			end
		end)
		f:SetScript("OnShow", function(self)
			self:RegisterEvent("GLOBAL_MOUSE_DOWN")
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
		end)
		f:SetScript("OnHide", function(self)
			self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
			self:EnableKeyboard(false)
		end)
		f:SetScript("OnEvent", function(self, event)
			-- (the click that asked, heard the same frame, is not a click elsewhere)
			if event == "GLOBAL_MOUSE_DOWN" and (self.at == GetTime() or self:IsMouseOver()) then return end
			Finish(false)
		end)
		f:SetScript("OnUpdate", function(self)
			if self.owner and not self.owner:IsVisible() then Finish(false) end
		end)
		f:Hide()
		return f
	end

	function UI.Confirm(owner, text, yes, done, opts)
		opts = opts or {}
		Finish(false)
		card = card or Make()
		local f = card
		f.owner, f.done, f.cancel, f.at = owner, done, opts.cancel, GetTime()
		local wide = opts.width or ASK.wide
		f.text:SetWidth(wide - 2 * ASK.pad)
		f.text:SetText(text)
		f.no:SetLabel(opts.no or "Cancel")
		-- (the button as wide as its words, never under the least)
		f.yes.text:SetWidth(0)
		f.yes.text:SetText(yes)
		f.yes:SetWidth(max(ASK.least, math.ceil(f.yes.text:GetStringWidth()) + 24))
		f.yes:SetLabel(yes)
		local tall = math.ceil(f.text:GetStringHeight())
		f:SetSize(wide, ASK.pad + tall + ASK.gap + ASK.button + ASK.pad)
		f:ClearAllPoints()
		f:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -ASK.apart)
		f:Show()
		f:Raise()
		f:EnableKeyboard(true)
		return f
	end
end

-- Groups

local Group = {}
Group.__index = Group

function UI.Group(onChange)
	return setmetatable({ widgets = {}, onChange = onChange }, Group)
end

function Group:Add(w)
	table.insert(self.widgets, w)
	return w
end

function Group:Changed()
	if self.onChange then self.onChange() end
	self:Refresh()
end

function Group:Refresh()
	for _, w in ipairs(self.widgets) do w:Refresh() end
end

for _, kind in ipairs({ "Checkbox", "Switch", "Slider", "Dropdown", "ColorSwatch", "Input" }) do
	Group[kind] = function(self, parent, label, ...)
		local args = { ... }
		-- The setter is the argument just before opts; wrap it to notify the group.
		local setIndex = kind == "Slider" and 5 or (kind == "Dropdown" and 3 or 2)
		local set = args[setIndex]
		local opts = args[setIndex + 1]
		if kind == "Slider" and opts and opts.settle then
			-- A slider whose value is taken once its knob is let go (opts.settle): its steps change nothing
			-- yet, so the group hears of it when it settles.
			local own = {}
			for key, value in pairs(opts) do own[key] = value end
			own.settle = function(...) opts.settle(...); self:Changed() end
			args[setIndex + 1] = own
		else
			args[setIndex] = function(...) set(...); self:Changed() end
		end
		return self:Add(UI[kind](parent, label, unpack(args, 1, setIndex + 1)))
	end
end

-- Page header: emblem, title, accent line and tagline. Returns the emblem.

function UI.PageHeader(parent, addon, titleSize)
	local emblem = B.CreateEmblem(parent, addon.mark, 64)
	emblem:SetPoint("TOPLEFT", 24, -22)

	local title = B.CreateTitle(parent, addon.internal and "" or addon.suffix, titleSize or 40)
	title:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 22, 8)

	local bar = B.CreateLine(parent, 300, 2)
	bar:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, 0)

	local sub = UI.Text(parent, (addon.tagline or "") ..
		(addon.version and ("   |cff888888v" .. addon.version .. "|r") or ""), 13)
	sub:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -7)
	return emblem
end

-- UI.GlyphButton: a button holding a glyph rather than words, in the family's make (UI.KeyPress): the glyph
-- dim at rest, in the head's ink lit (under the mouse, or on), in the fill's on the primary.
--   UI.GlyphButton(parent, glyph, size, onClick, opts)   -- size: its height, and width unless opts.width
--       opts.glyph   the glyph's size (size - 8)          opts.fill   C.bgHot; C.fill for the primary
--       opts.tip     { title, text }: its hover
-- .glyph is the glyph's texture; b:SetOn, b:SetPrimary as UI.KeyPress's.
function UI.GlyphButton(parent, glyph, size, onClick, opts)
	opts = opts or {}
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(opts.width or size, size)
	b.glyph = b:CreateTexture(nil, "OVERLAY")
	b.glyph:SetTexture(glyph)
	b.glyph:SetPoint("CENTER")
	UI.GlyphFit(b.glyph, opts.glyph or size - 8)
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		onClick(self)
	end)
	if opts.tip then UI.Help(b, opts.tip[1], opts.tip[2]) end
	return UI.KeyPress(b, { fill = opts.fill, glyphs = { b.glyph }, sink = { b.glyph } })
end

-- The × that closes a window or card: a square glyph button of `size`, the cross drawn `glyph` across.
UI.CLOSE_GLYPH = Shy.MEDIA .. "GlyphClose"

function UI.Close(parent, size, glyph, onClick)
	local b = UI.GlyphButton(parent, UI.CLOSE_GLYPH, size, onClick, { glyph = glyph, fill = C.bg })
	b.cross = b.glyph
	return b
end

-- Custom headers stand their × once; a look option (Heritage Frame) moves the inner edge, so they
-- are stood again on SHY_THEME. Native windows go through kit:HeadRail on the same event.
local heads = setmetatable({}, { __mode = "k" })

local PlaceTabs
local function PlaceHead(head)
	local f, opts, size = head._house, head._opts, head.size
	local house = f and f.shyLook
	if house then house.owner = f end
	local mid = house and UI.HeadStripMid(house, size) or -head.mid
	head.mid = -mid
	-- From the left: the icon, then the words, nested inside the look's border (UI.HeadLeft).
	local x = UI.HeadLeft(house, size)
	if head.icon then
		head.icon:ClearAllPoints()
		head.icon:SetPoint("LEFT", head, "TOPLEFT", x, mid)
		x = x + (size.emblem and size.emblem + 12 or size.icon + 6)
	end
	head.x = x
	local lift = opts and opts.lift or 0
	if head.title then
		head.title:ClearAllPoints()
		head.title:SetPoint("LEFT", head, "TOPLEFT", x, mid + lift)
	end
	-- The controls, one tight cluster from the right: the ×, then each shown button `apart` from the one before.
	local apart, right = size.apart or 2, UI.HeadCloseRight(house, size)
	local any = false
	if head.close then
		head.close:ClearAllPoints()
		head.close:SetPoint("RIGHT", head, "TOPRIGHT", -right, mid)
		right = right + size.control + apart
		any = true
	end
	for i, b in ipairs(head.buttons or {}) do
		local def = opts.buttons[i]
		if not (def.hidden and not b:IsShown()) then
			b:ClearAllPoints()
			b:SetPoint("RIGHT", head, "TOPRIGHT", -right, mid)
			right = right + (def.glyph and size.control or def[2]) + apart
			any = true
		end
	end
	-- Past the cluster the title's gap; with no controls, the strip's pad.
	right = any and right - apart + (size.gap or 8) or right + size.pad
	head.right = right
	if head.title and not (opts and opts.brand) then
		head.title:SetPoint("RIGHT", head, "TOPRIGHT", -right, mid + lift)
	end
end

-- A header's tabs: after the title's words (a title stands to the controls, so its own width is the strip's), as far as
-- the controls, scrolling past that.
PlaceTabs = function(head)
	local tabs = head.tabs
	if not tabs then return end
	local title, words = head.title, 0
	if title then
		words = title.GetUnboundedStringWidth and title:GetUnboundedStringWidth() or title:GetWidth()
		if issecretvalue(words) or not words then words = 0 end
	end
	local left = head.x + (title and words + 30 or 0)
	tabs:ClearAllPoints()
	tabs:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", left, 0)
	local wide = head:GetWidth()
	if not issecretvalue(wide) and wide and wide > 0 and head.right then tabs:SetRoom(math.max(60, wide - left - head.right)) end
end

Shy:On("SHY_THEME", function()
	for head in pairs(heads) do
		PlaceHead(head)
		PlaceTabs(head)
	end
end)
Shy:On("SHY_FONT", function()
	for head in pairs(heads) do PlaceTabs(head) end
end)

-- A header: the title strip, the accent line and what stands in the strip, in one of the three
-- sizes of UI.HEAD. Draws the panel too, unless opts.panel is false.
--   local head = UI.Head(frame, {
--       size = "piece" | "window" | "main",   -- "piece" unless told
--       title = "Find",                       -- words in the display font, or
--       brand = "Quest",                      -- the lit Shy<suffix> logotype
--       height = 34,                         -- the strip's height (UI.HeadSize): taller than its size's own, for a header that
--                                            -- holds more (a search box, tabs); never under what its controls need
--       lift = 7,                             -- the title stands this far above the middle (a line under it)
--       icon = path,                         -- before the title: a small icon (window) or the glowing emblem (main)
--       close = function() end,               -- the × at the right
--       buttons = { { "Options", 76, fn }, { "Who", 54, fn } },   -- right to left, after the ×; a glyph control is
--                                            -- { glyph = path, tip = { title, words }, click = fn, hidden = true|nil }.
--                                            -- One made `hidden` comes and goes, keeping no room while away:
--                                            -- show or hide it, then head:Place()
--       tabs = { labels, onSelect },          -- standing on the accent line, after the title (main)
--       drag = box,                           -- a Shy.HUD box the header drags
--       panel = { hud, brackets, fill, cap, facets, line } or false,
--       body = true,                          -- a piece on screen (panel.hud) whose content can step in by the
--                                            -- look's clearance inside the size its plan gives it: it gets a body
--                                            -- (UI.Body) too. A window always has one; false: none
--   })
-- Returns the header frame, the panel's width and as tall as the header down to the line's foot:
-- .title, .icon, .close, .buttons, .tabs, .size (its UI.HEAD entry), .x (where the title starts),
-- .mid (the strip's middle, down from the top) and .right (how far in from the right edge the
-- controls end).
function UI.Head(f, opts)
	opts = opts or {}
	local size = UI.HeadSize(opts.size, opts.height)
	if opts.panel ~= false then
		local panel = opts.panel or {}
		-- A console piece's `title` is the whole header; a window's is the strip inside the edge.
		panel.title = panel.cap and size.line or size.line - 2
		panel.lip = size.lip
		-- A window wears the theme's look as the pieces on screen do, on a solid fill.
		if panel.window == nil and panel.looks == nil then panel.window = true end
		UI.Panel(f, panel)
		-- Where its content stands, clear of the look's work (UI.Body): every window's; a piece on screen's only where
		-- it says so (opts.body), since a piece keeps the size the screen's plan gives it and its content must have
		-- room to step in. (A piece without one wears no work inside its edge: g.cleared.)
		if opts.body or (opts.body == nil and not panel.hud) then UI.Body(f) end
		-- And the sheet it is read off, under the head: a window is two surfaces with a setting each, so
		-- every one of them answers the same two. (A piece on screen is one surface and keeps to the one
		-- setting; a window that lays its own, as the /shy window does, says where it goes.)
		if f.shyBody and panel.window and panel.sheet ~= false then UI.BodySheet(f, true) end
	end
	local head = CreateFrame("Frame", nil, f)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(size.line + UI.LINE)
	head.size, head.mid = size, UI.HeadMiddle(2, size.line - 2, size.lip)   -- the middle every header's words stand on
	if opts.drag then Shy.HUD.DragHandle(opts.drag, head) end

	local x = size.pad
	if opts.icon then
		if size.emblem then
			head.icon = B.CreateEmblem(head, opts.icon, size.emblem)
			head.icon:SetPoint("LEFT", head, "TOPLEFT", x, -head.mid)
			x = x + size.emblem + 12
		else
			head.icon = head:CreateTexture(nil, "ARTWORK")
			head.icon:SetSize(size.icon, size.icon)
			head.icon:SetPoint("LEFT", head, "TOPLEFT", x, -head.mid)
			Theme.Icon(head.icon, opts.icon)
			x = x + size.icon + 6
		end
	end
	head.x = x
	if opts.brand then
		head.title = B.CreateTitle(head, opts.brand, size.brand)
	elseif opts.title then
		head.title = UI.TitleText(head, opts.title, size.text)
		head.title:SetWordWrap(false)
	end
	if head.title then head.title:SetPoint("LEFT", head, "TOPLEFT", x, -head.mid + (opts.lift or 0)) end
	-- Its words are the head's title (a look may set them off: UI.LookTitle); a logotype stands as it is.
	if head.title and not opts.brand and f.shyLook then UI.LookTitle(f.shyLook, head.title, true) end

	head._house, head._opts = f, opts
	if opts.close then
		head.close = UI.Close(head, size.control, size.glyph, opts.close)
	end
	head.buttons = {}
	for i, def in ipairs(opts.buttons or {}) do
		local b
		if def.glyph then
			b = UI.GlyphButton(head, def.glyph, size.control, def.click, { glyph = size.glyph, fill = C.bg, tip = def.tip })
		else
			b = UI.Button(head, def[1], def[2], def[3])
			b:SetHeight(size.control)
			UI.SetFill(b, C.bg)
		end
		if def.hidden then b:Hide() end
		head.buttons[i] = b
	end
	head.Place = PlaceHead
	PlaceHead(head)
	heads[head] = true
	if opts.tabs then
		-- (A size with no tabs of its own, a window's, has them in its title's type and as tall as its strip.)
		head.tabs = UI.Tabs(head, opts.tabs[1], opts.tabs[2], nil, size.tabs or size.text, f,
			not size.tabs and { tall = size.line - size.lip } or nil)
		PlaceTabs(head)
	end
	return head
end

-- A window: a Shy.HUD box (window = true) on a solid panel with a header, over what is under it,
-- closed by Esc. opts are Shy.HUD.Create's (id, title, width, height, point, shown, secure, inCombat, hang, grip:
-- every corner and side scales a window unless `grip` says it flows) and:
--   name      a global name for the box, so Esc closes it (UISpecialFrames)
--   strata    frame strata
--   onClose   called when the window is hidden by Esc, its × or its own Hide, never by a parent's
--   close     what the × does (hides the window, unless told; a hide runs onClose)
--   head      UI.Head's opts; "main" unless told. The header drags the window.
--   maximize  true: a glyph in the header fills the screen with the window and puts it back (UI.Maximize)
-- Returns the box, with .head.

-- UI.Maximize(box, on, follow): a window fills the screen, over what is under it, or goes back to its own size and
-- place (follow: under the cursor, held at the same share of its width, as a maximized window dragged comes away).
-- A window flows, never scales: its grip's flow is told the new width and height each time, and it lays itself out
-- for them. box.maxed while it fills the screen; box.maxButton, if it has one, wears Maximize or Restore. A window
-- made with `maximize` that is dragged or sized while maximized is put back first.
function UI.Maximize(box, on, follow)
	on = on and true or false
	if on == (box.maxed ~= nil) then return end
	if InCombatLockdown() and box:IsProtected() then return end   -- (a protected window stays as it is in a fight)
	if on then
		box.maxed = { box:GetWidth(), box:GetHeight(), box:GetFrameStrata() }
		box:ClearAllPoints()
		box:SetAllPoints(UIParent)
		box:SetFrameStrata("HIGH")
		box:Raise()
	else
		local size = box.maxed
		box.maxed = nil
		box:ClearAllPoints()
		box:SetSize(size[1], size[2])
		if follow then
			local s = box:GetEffectiveScale()
			local x, y = GetCursorPosition()
			x, y = x / s, y / s
			local share = (x - (box:GetLeft() or x)) / math.max(1, UIParent:GetWidth())
			box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - share * size[1], y + (box.head and box.head.mid or 0))
		else
			Shy.HUD.Apply(box)
		end
		box:SetFrameStrata(size[3])
	end
	if box.maxButton then box.maxButton.glyph:SetTexture(Shy.MEDIA .. (on and "GlyphRestore" or "GlyphMaximize")) end
	if box.shyFlow then
		-- (told its body's size, as the grip tells it: UI.Body)
		local l, t, r, b = UI.BodyIn(box)
		local w, h = box:GetWidth(), box:GetHeight()
		if on then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
		box.shyFlow(box, w - l - r, h - t - b)
	end
end
-- A maximized window whose look's clearance changes is laid out again for the room its body has now.
Shy:On("SHY_BODY", function(box)
	if type(box) == "table" and box.maxed and box.shyFlow then box.shyFlow(box, UI.BodySize(box)) end
end)
Shy:On("SHY_HUD_MOVING", function(box)
	if type(box) == "table" and box.shyMaximize and box.maxed then UI.Maximize(box, false, true) end
end)

function UI.Window(opts)
	local box = Shy.HUD.Create({
		id = opts.id, title = opts.title, name = opts.name, width = opts.width, height = opts.height,
		point = opts.point, shown = opts.shown, secure = opts.secure, inCombat = opts.inCombat, hang = opts.hang, grip = opts.grip, window = true,
		dock = opts.dock,   -- (beside another window: Shy.HUD's `dock`)
	})
	box:SetToplevel(true)
	box:EnableMouse(true)   -- so clicks don't fall through to the world
	if opts.strata then box:SetFrameStrata(opts.strata) end
	if opts.name then
		_G[opts.name] = box
		table.insert(UISpecialFrames, opts.name)
	end
	if opts.onClose then
		-- OnHide also fires when a parent hides; only the window's own hide counts as closing.
		box:HookScript("OnHide", function(self)
			if not self:IsShown() then opts.onClose(self) end
		end)
	end
	local head = opts.head or {}
	head.size = head.size or "main"
	head.drag = box
	if head.close == nil then head.close = opts.close or function() box:Hide() end end
	-- (a flow of its own lays the window out for a size; `true` is the HUD's own: it is only resized)
	box.shyFlow = opts.grip and type(opts.grip.flow) == "function" and opts.grip.flow or nil
	if opts.maximize then
		-- (the first of the header's controls after the ×)
		head.buttons = head.buttons or {}
		table.insert(head.buttons, 1, { glyph = Shy.MEDIA .. "GlyphMaximize",
			click = function() UI.Maximize(box, not box.maxed) end })
	end
	box.head = UI.Head(box, head)
	-- Its content laid on its body (UI.Body), and the window as big as it was made with its look's clearance besides:
	-- one that flows through its grip, which counts it from here on (its made size is its body's: box.shyMade).
	if opts.grip and opts.grip.flow then
		box.shyMade = { opts.width, opts.height }
		local l, t, r, b = UI.BodyIn(box)
		-- (Docked `tall` beside a window that is there already: as tall as it from the first frame, before its grip
		-- has hold of it.)
		Shy.HUD.Resize(box, opts.width + l + r, Shy.HUD.DockTall(box) or opts.height + t + b)
	else
		UI.BodyFit(box, opts.width, opts.height)
	end
	if opts.maximize then
		box.shyMaximize = true
		box.maxButton = box.head.buttons[1]
	end
	return box
end

-- Tabbed windows: a family of windows whose tabs dock together and come apart as a browser's do. A tab dragged
-- along its strip moves there, onto another window joins it (on its strip where it is let go, anywhere else at
-- the end), anywhere off its window opens a window of its own there. A window dragged by its header (or its one
-- tab) onto another docks into it, every tab. While something is carried, every place that would take it lights
-- faintly (nothing else takes it), the window on top under the cursor that it would join lights whole, washed and
-- outlined in your color, and a bar in its strip marks where it goes (only moving along its own strip, the strip alone
-- lights); held at a strip's shaded edge, the tabs scroll. A carried tab shows as a tab where it would go or stay,
-- anywhere else as the window it would open there (its size, where it would stand), as the game carries its chat
-- windows whole. Windows
-- flow (resized, never scaled): tabs past
-- the strip scroll, shaded at the edges they run past, and a list button by the controls shows them all.
--   local set = UI.TabWindows({
--       id = "shychat.whispers", title = "Whispers", most = 8,   -- window n is the HUD box `id .. n`
--       width, height, point, least = { w, h }, step = 24,       -- a new window stands `step` down and right of the last
--       shown = function(win) end, onClose = function(win) end,  -- UI.Window's, for each window
--       controls = { { key = "max", glyph, tip, click = function(win) end }, ... },   -- right to left after the ×
--       list = { title, words },                                  -- the list button's hover
--       build = function(win) end,           -- each window's body, once, on win.box
--       label = function(key, win) end,      -- a tab's words
--       name = function(key) end,            -- its whole name: the list's rows, the carried tab
--       tint = function(key) end,            -- its color or nil: the carried tab's edge
--       picked = function(win, key) end,     -- a tab opened
--       moved = function(win) end,           -- a window's tabs changed (joined, left, moved along)
--       emptied = function(win) end,         -- its last tab left: the owner lets it go (hide it, quietly)
--       menu = function(tab, win, key) end,  -- a tab right-clicked
--       row = function(entry, key, win) end, -- a row of the list, to add a sub line or a detail
--       placed = function(key, win) end,     -- you carried a tab (or a window's every tab) into another window
--   })
-- set.wins[n]; set.of[key] the window a tab is in; win = { n, box, head, tabs, keys, current, open, buttons, room }
-- (open: it holds tabs). set:Window() a window with none (stepped from the last opened while that one shows; one
-- the owner marks `maxed` is not stepped from), set:Make(n), set:Join(win, key, at), set:Leave(key),
-- set:Show(key), set:Own(key, spot), set:Merge(from, to, at), set:Clear(win), set:Fits(win, label), set:Lay(win).
-- A host: a place of the owner's that holds tabs as a window does (the chat's own strip), carried into and out of
-- as any window. Never handed out by set:Window(); its one tab carries itself, not the host.
--   local win = set:Host({
--       box,      -- shows the open tab (the owner shows it); build(win) lays it out
--       zone,     -- where a carried tab or window lets go into it, while shown
--       strip,    -- its tabs stand on it: UI.Tabs' strip (shyLine, shyStripColor), sized by the owner
--       tall, mid, gap,                   -- the tabs' height, their words' middle and their spacing (UI.Tabs' opts)
--       band,                             -- optional: the row a drop lands along (its whole header), the strip's place
--                                         -- in it by the cursor (before the first when left of them)
--       up = function() end,              -- whether its open tab is in view: else none of its tabs reads as open
--   })   -- win.host is the table given; set.hosts lists them
-- set:Hint(win) lights `win` faintly as a place to go for a drag of the owner's own (a game window carried to the chat);
-- set:Unhint() puts it out.
do
	local K = {
		GHOST_H = 22,   -- a carried tab
		GRAB = { 40, 12 },   -- where the cursor holds a window a carried tab would open: in from its left, down from its top
		SHELL = 0.75,   -- how much of that window shows as it is carried
		HINT = { wash = 0.05, edge = 0.4 },   -- a place that would take what is carried, lit faintly the whole time
		NUDGE = 6,      -- a window let go of nearer than this to where it was pressed was only clicked
		CREEP = 6,      -- a carried tab held at a strip's shaded edge scrolls it this far a frame
		EDGE = 2,       -- the outline round a window it would join
		STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 },
		sets = {}, owners = setmetatable({}, { __mode = "k" }),
		driver = CreateFrame("Frame"),
	}

	-- What is carried: over a place that would take it (or along its own strip), the tab itself, by the bar marking
	-- where it goes; anywhere else the window it would open, as big as it would be and where it would stand, named in
	-- its header, as a window of the game's is carried whole off its dock. (K.Shape picks.)
	function K.Shell()
		if K.shell then return K.shell end
		local w = CreateFrame("Frame", nil, UIParent)
		w:SetFrameStrata("TOOLTIP")
		UI.Skin(w, C.bg, C.hot)
		w:SetAlpha(K.SHELL)
		w.head = w:CreateTexture(nil, "BORDER")
		w.head:SetPoint("TOPLEFT", 1, -1)
		w.head:SetPoint("TOPRIGHT", -1, -1)
		w.head:SetHeight(UI.HEAD_STRIP - 1)
		Theme.Paint(w.head, C.bgHot)
		w.line = w:CreateTexture(nil, "ARTWORK")
		w.line:SetPoint("TOPLEFT", w.head, "BOTTOMLEFT")
		w.line:SetPoint("TOPRIGHT", w.head, "BOTTOMRIGHT")
		w.line:SetHeight(UI.LINE)
		w.text = UI.TitleText(w, "", UI.TITLE_SIZE, C.text)
		w.text:SetPoint("LEFT", w, "TOPLEFT", 12, -UI.HEAD_MID)
		w:SetScript("OnUpdate", function(self)
			local x, y = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - K.GRAB[1], y / s + K.GRAB[2])
		end)
		w:Hide()
		K.shell = w
		return w
	end

	-- The size a window a tab is carried out into would be: its window's (a window of the set's make), else one the set
	-- has made, else the set's own.
	function K.Size(set, from)
		local box = from and not from.host and from.box
		if not box then
			for n = 1, set.most do
				if set.wins[n] then
					box = set.wins[n].box
					break
				end
			end
		end
		if box then return box:GetWidth(), box:GetHeight() end
		return set.opts.width, set.opts.height
	end

	function K.Shape(tab)
		local d = K.dragging
		if not d or d.tab == tab then return end
		d.tab = tab
		K.Ghost():SetShown(tab)
		K.Shell():SetShown(not tab)
	end

	-- Every place that would take what is carried, lit faintly the whole time it is carried (the one under the cursor
	-- lit full, K.Mark): what isn't lit takes nothing. A tab's own window takes it only along its strip.
	K.hints = {}
	function K.Hint(set, but, home, only)
		local n = 0
		for i = 1, set.most + #set.hosts do
			local win = set.wins[i] or set.hosts[i - set.most]
			if win and win ~= but and (not only or only == win) and (win.open or win.host) and K.Zone(win):IsVisible() then
				n = n + 1
				local h = K.hints[n]
				if not h then
					h = CreateFrame("Frame", nil, UIParent)
					h:SetFrameStrata("FULLSCREEN_DIALOG")
					h:EnableMouse(false)
					h.wash = h:CreateTexture(nil, "BACKGROUND")
					h.wash:SetAllPoints()
					h.edges = {}
					for e, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
						local t = h:CreateTexture(nil, "BORDER")
						local across = e <= 2
						t:SetPoint(across and (side .. "LEFT") or ("TOP" .. side))
						t:SetPoint(across and (side .. "RIGHT") or ("BOTTOM" .. side))
						if across then t:SetHeight(1) else t:SetWidth(1) end
						h.edges[e] = t
					end
					K.hints[n] = h
				end
				local over = win == home and (win.band or win.head) or K.Zone(win)
				h:ClearAllPoints()
				h:SetAllPoints(over)
				Theme.Paint(h.wash, C.hot, K.HINT.wash)
				for _, t in ipairs(h.edges) do Theme.Paint(t, C.hot, K.HINT.edge) end
				h:Show()
			end
		end
		for i = n + 1, #K.hints do K.hints[i]:Hide() end
	end

	function K.Unhint()
		for _, h in ipairs(K.hints) do h:Hide() end
	end

	function K.Ghost()
		if K.ghost then return K.ghost end
		K.ghost = CreateFrame("Frame", nil, UIParent)
		K.ghost:SetFrameStrata("TOOLTIP")
		K.ghost:SetSize(120, K.GHOST_H)
		UI.Skin(K.ghost, C.bg, C.hot)
		K.ghost.text = UI.TitleText(K.ghost, "", UI.TITLE_SIZE, C.text)
		K.ghost.text:SetPoint("CENTER")
		K.ghost:SetScript("OnUpdate", function(self)
			local x, y = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			self:ClearAllPoints()
			self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 8, y / s - 8)
		end)
		K.ghost:Hide()
		return K.ghost
	end

	-- What shows where a carried tab or window would go: the strip washed in your color, a bar at the place.
	-- A window it would join lights whole (washed and outlined); a strip it would only move along lights alone.
	-- Under the carried tab's ghost, over every window.
	function K.Drop()
		if K.drop then return K.drop end
		local d = CreateFrame("Frame", nil, UIParent)
		d:SetFrameStrata("FULLSCREEN_DIALOG")
		d.wash = d:CreateTexture(nil, "BACKGROUND")
		d.wash:SetAllPoints()
		d.edges = {}
		for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local e = d:CreateTexture(nil, "BORDER")
			local across = i <= 2
			e:SetPoint(across and (side .. "LEFT") or ("TOP" .. side))
			e:SetPoint(across and (side .. "RIGHT") or ("BOTTOM" .. side))
			if across then e:SetHeight(K.EDGE) else e:SetWidth(K.EDGE) end
			d.edges[i] = e
		end
		d.bar = d:CreateTexture(nil, "OVERLAY")
		d.bar:SetWidth(2)
		d:Hide()
		K.drop = d
		return d
	end

	-- Which of two windows stands over the other: by strata, then level.
	function K.Over(box)
		return (K.STRATA[box:GetFrameStrata()] or 0) * 100000 + box:GetFrameLevel()
	end

	function K.Index(win, key)
		for i, k in ipairs(win.keys) do
			if k == key then return i end
		end
	end

	-- Where along a strip the cursor would put a tab: before the first tab whose middle is past it.
	function K.Slot(win)
		local x = GetCursorPosition() / win.tabs:GetEffectiveScale()
		for i = 1, #win.keys do
			local t = win.tabs.tabs[i]
			local mid = t and t:GetCenter()
			if mid and x < mid then return i end
		end
		return #win.keys + 1
	end

	-- The strip under the cursor among the set's windows (never `but`'s), and the place in it.
	-- The window on top under the cursor (never `but`, the one carried) and where a tab would go in it: anywhere on
	-- another window joins it (on its strip at the place, elsewhere at the end); on `home`, the window a tab comes
	-- from, only its strip counts. Returns the window, the place, and whether it would join (not only move along).
	-- A window takes a drop while it holds tabs and shows; a host whenever its zone shows.
	function K.Zone(win) return win.zone or win.box end

	function K.Target(set, but, home)
		local best, over, strip
		for n = 1, set.most + #set.hosts do
			local win = set.wins[n] or set.hosts[n - set.most]
			local zone = win and K.Zone(win)
			if win and win ~= but and (win.open or win.host) and zone:IsVisible() then
				-- (a host's whole header row, when it names one: a drop over the tabs before its own lands first)
				local band = win.band or win.head
				local onStrip = band:IsVisible() and band:IsMouseOver()
				if onStrip or zone:IsMouseOver() then
					local rank = K.Over(zone)
					if not best or rank > over then best, over, strip = win, rank, onStrip end
				end
			end
		end
		if not best or (best == home and not strip) then return nil end
		return best, strip and K.Slot(best) or #best.keys + 1, best ~= home
	end

	function K.Mark(win, at, join)
		local d = K.Drop()
		if not win then
			d:Hide()
			return
		end
		local over = join and K.Zone(win) or win.tabs
		d:ClearAllPoints()
		d:SetPoint("TOPLEFT", over, "TOPLEFT")
		d:SetPoint("BOTTOMRIGHT", over, "BOTTOMRIGHT")
		Theme.Paint(d.wash, C.hot, join and 0.16 or 0.12)
		for _, e in ipairs(d.edges) do
			Theme.Paint(e, C.hot)
			e:SetShown(join == true)
		end
		Theme.Paint(d.bar, C.hot)
		local t, side = win.tabs.tabs[at], "LEFT"
		if at > #win.keys or not t then t, side = win.tabs.tabs[#win.keys], "RIGHT" end
		-- No tab yet: where the first will stand, at the strip's start.
		if #win.keys == 0 then t, side = win.tabs, "LEFT" end
		d.bar:ClearAllPoints()
		d.bar:SetPoint("TOP", t, "TOP" .. side, side == "LEFT" and -2 or 2, 0)
		d.bar:SetPoint("BOTTOM", t, "BOTTOM" .. side, side == "LEFT" and -2 or 2, 0)
		d.bar:SetHeight(t:GetHeight())
		d.bar:Show()
		d:Show()
	end

	-- A carried tab held over a strip's shaded edge scrolls it.
	function K.Creep(win)
		local tabs = win and win.tabs
		if not (tabs and tabs.overflow and tabs:GetLeft()) then return end
		local x = GetCursorPosition() / tabs:GetEffectiveScale() - tabs:GetLeft()
		if x < TAB.FADE then
			tabs:ScrollBy(-K.CREEP)
		elseif x > tabs:GetWidth() - TAB.FADE then
			tabs:ScrollBy(K.CREEP)
		end
	end

	function K.Follow()
		if K.dragging then
			local d = K.dragging
			local home = d.set.of[d.key]
			local win, at, join = K.Target(d.set, nil, home)
			K.Creep(win)
			K.Mark(win, at, join)
			-- A tab where it goes, or where it stays (over its own window); else the window it would open.
			K.Shape(win ~= nil or (home ~= nil and K.Zone(home):IsMouseOver()))
		elseif K.carrying then
			K.Mark(K.Target(K.carrying.set, K.carrying.win))
		end
	end

	function K.Start()
		K.driver:SetScript("OnUpdate", K.Follow)
		K.driver:RegisterEvent("GLOBAL_MOUSE_UP")
	end

	function K.Stop()
		K.driver:SetScript("OnUpdate", nil)
		K.driver:UnregisterEvent("GLOBAL_MOUSE_UP")
		K.Mark(nil)
		K.Unhint()
		if K.shell then K.shell:Hide() end
	end

	function K.Lift(set, win, key)
		K.dragging = { set = set, key = key }
		local tint = set.opts.tint and set.opts.tint(key) or C.hot
		local g = K.Ghost()
		g.text:SetText(set.opts.label(key, win))
		UI.SetBorder(g, tint)
		g:SetWidth(g.text:GetStringWidth() + 24)
		local w = K.Shell()
		w.text:SetText(set.opts.name and set.opts.name(key) or set.opts.label(key, win))
		UI.SetBorder(w, tint)
		Theme.Paint(w.line, tint)
		w:SetSize(K.Size(set, win))
		K.Shape(true)   -- it starts on its own strip
		K.Hint(set, nil, win)
		K.Start()
	end

	-- Let go of: onto a strip it goes there; over its own window it stays; anywhere else it is a window of its own.
	function K.Let()
		local d = K.dragging
		K.dragging = nil
		if K.ghost then K.ghost:Hide() end
		K.Stop()
		if not d then return end
		local set, key = d.set, d.key
		local from = set.of[key]
		if not from then return end
		local win, at = K.Target(set, nil, from)
		if win then
			set:Join(win, key, at)
			set:Show(key)
			win.box:Raise()
			if win ~= from then K.Placed(set, key, win) end
			return
		end
		if K.Zone(from):IsMouseOver() then return end
		-- Where the carried window showed it would stand.
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		local _, tall = K.Size(set, from)
		local own = set:Own(key, { x = x / s - K.GRAB[1], y = y / s + K.GRAB[2] - tall })
		if own then K.Placed(set, key, own) end
	end

	function K.Placed(set, key, win)
		if set.opts.placed then set.opts.placed(key, win) end
	end

	K.driver:SetScript("OnEvent", function()
		if K.dragging then K.Let() end
	end)

	-- A whole window carried by its header: docked into the strip it is let go of over.
	Shy:On("SHY_HUD_MOVING", function(box)
		local win = K.owners[box]
		if not (win and win.open) then return end
		local x, y = GetCursorPosition()
		K.carrying = { set = win.set, win = win, x = x, y = y }
		K.Hint(win.set, win)
		K.Start()
	end)
	Shy:On("SHY_HUD_MOVED", function(box)
		local c = K.carrying
		if not (c and c.win.box == box) then return end
		K.carrying = nil
		K.Stop()
		-- Only pressed, not carried: judged by the cursor, which goes where the window can't (past the screen's edge).
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		if (abs(x - c.x) + abs(y - c.y)) / s < K.NUDGE then return end
		local to, at = K.Target(c.set, c.win)
		if not to then return end
		local keys = { unpack(c.win.keys) }
		c.set:Merge(c.win, to, at)
		for _, key in ipairs(keys) do K.Placed(c.set, key, to) end
	end)

	local Set = {}
	Set.__index = Set

	-- The tabs' room: the strip up to the controls; the list button shows while they run past it.
	function K.Room(set, win)
		-- A host's tabs take what they need: the place it stands them in scrolls (the chat's tab row).
		if win.host then
			win.room = nil
			win.head:SetWidth(max(1, win.tabs:GetWidth()))
			return
		end
		local head = win.head
		win.tabs:ClearAllPoints()
		win.tabs:SetPoint("TOPLEFT", head, "TOPLEFT", head.x - 4, 0)
		local function Fit() return max(40, win.box:GetWidth() - head.x + 4 - head.right) end
		win.room = Fit()
		win.tabs:SetRoom(win.room)
		local over = win.tabs.overflow == true
		if over ~= win.more:IsShown() then
			win.more:SetShown(over)
			head:Place()
			win.room = Fit()
			win.tabs:SetRoom(win.room)
		end
	end

	function K.List(set, win)
		local opts = set.opts
		UI.DropMenu(win.more, function(root)
			root:CreateTitle(opts.list and opts.list[1] or opts.title)
			for _, key in ipairs(win.keys) do
				local entry = root:CreateButton(opts.name and opts.name(key) or opts.label(key, win), function() set:Show(key) end)
				if opts.row then opts.row(entry, key, win) end
			end
		end)
	end

	function K.Dress(set, win, tab)
		tab.shyTabbed = true
		tab:RegisterForDrag("LeftButton")
		tab:SetScript("OnDragStart", function(self)
			local key = win.keys[self.shyIndex]
			if key and (#win.keys > 1 or win.host) then K.Lift(set, win, key) end
		end)
		tab:SetScript("OnDragStop", function() if K.dragging then K.Let() end end)
		-- With one tab, the tab carries its window as the header does (a host's stays where it is).
		if not win.host then Shy.HUD.Manage(win.box, tab, false, function() return #win.keys < 2 end) end
		tab:HookScript("OnMouseUp", function(self, button)
			if button ~= "RightButton" or not set.opts.menu then return end
			local key = win.keys[self.shyIndex]
			if key then set.opts.menu(self, win, key) end
		end)
	end

	function Set:Lay(win)
		local labels = {}
		for i, key in ipairs(win.keys) do labels[i] = self.opts.label(key, win) end
		for i, tab in ipairs(win.tabs:SetLabels(labels)) do
			tab.shyIndex = i
			if i <= #labels and not tab.shyTabbed then K.Dress(self, win, tab) end
		end
		K.Room(self, win)
		local i = win.current and K.Index(win, win.current)
		-- A host's open tab reads as open only while it is in view.
		if win.host and not win.host.up() then
			if win.tabs.selected then win.tabs:Select(nil) end
		elseif i then
			win.tabs:Select(i)
		end
	end

	function K.Moved(set, win)
		win.open = win.keys[1] ~= nil
		if set.opts.moved then set.opts.moved(win) end
	end

	-- A window a tab left: laid again, or let go of once it holds none.
	function K.Settle(set, win)
		if win.keys[1] then
			set:Lay(win)
			K.Moved(set, win)
			return
		end
		win.current, win.open = nil, false
		if set.last == win then set.last = nil end
		set:Lay(win)
		if set.opts.emptied then set.opts.emptied(win) end
	end

	-- Out of its window, the open tab handed to its neighbour.
	function K.Take(set, win, key)
		local i = K.Index(win, key)
		if not i then return end
		table.remove(win.keys, i)
		set.of[key] = nil
		if win.current == key then win.current = win.keys[i] or win.keys[i - 1] end
	end

	function Set:Join(win, key, at)
		local from = self.of[key]
		if from == win then
			local i = K.Index(win, key)
			if not at or at == i or at == i + 1 then return end
			table.remove(win.keys, i)
			if at > i then at = at - 1 end
			table.insert(win.keys, at, key)
			self:Lay(win)
			K.Moved(self, win)
			return
		end
		if from then K.Take(self, from, key) end
		at = max(1, min(at or #win.keys + 1, #win.keys + 1))
		table.insert(win.keys, at, key)
		self.of[key] = win
		if not win.current then win.current = key end
		self:Lay(win)
		K.Moved(self, win)
		if from then K.Settle(self, from) end
	end

	function Set:Leave(key)
		local win = self.of[key]
		if not win then return end
		K.Take(self, win, key)
		K.Settle(self, win)
	end

	-- Every tab let go of at once, with no word to the owner (it is letting the window go itself).
	function Set:Clear(win)
		for _, key in ipairs(win.keys) do self.of[key] = nil end
		wipe(win.keys)
		win.current, win.open = nil, false
		if self.last == win then self.last = nil end
		self:Lay(win)
	end

	function Set:Show(key)
		local win = self.of[key]
		local i = win and K.Index(win, key)
		if i then win.tabs:Select(i) end
	end

	-- Whether a tab of these words fits beside the window's others without scrolling.
	function Set:Fits(win, label)
		win.probe:SetText(label)
		return win.tabs:GetWidth() + win.probe:GetStringWidth() + 24 <= win.room
	end

	function Set:Make(n)
		local opts, set = self.opts, self
		local win = { n = n, keys = {}, set = self, buttons = {}, open = false }
		local controls = {}
		for i, c in ipairs(opts.controls or {}) do
			controls[i] = { glyph = c.glyph, tip = c.tip, click = function() c.click(win) end }
		end
		controls[#controls + 1] = { glyph = Shy.MEDIA .. "GlyphCaret", tip = opts.list, hidden = true,
			click = function() K.List(set, win) end }
		local box = UI.Window({
			id = opts.id .. n, title = opts.title,   -- no name: Esc doesn't close it
			width = opts.width, height = opts.height, point = opts.point,
			shown = opts.shown and function() return opts.shown(win) end,
			grip = { flow = true, min = opts.least },
			onClose = opts.onClose and function() opts.onClose(win) end,
			head = { size = "piece", buttons = controls },
		})
		win.box, win.head = box, box.head
		for i, c in ipairs(opts.controls or {}) do
			if c.key then win.buttons[c.key] = box.head.buttons[i] end
		end
		win.more = box.head.buttons[#controls]
		local head = box.head
		win.tabs = UI.Tabs(head, {}, function(i) K.Pick(set, win, i) end, nil, UI.TITLE_SIZE, box,
			{ tall = head.size.line + UI.LINE, mid = head.mid })
		win.probe = UI.TitleText(head, "", UI.TITLE_SIZE)
		win.probe:Hide()
		K.owners[box] = win
		self.wins[n] = win
		if opts.build then opts.build(win) end
		box:HookScript("OnSizeChanged", function() K.Room(set, win) end)
		K.Room(self, win)
		return win
	end

	-- A tab opened (none: a host's put out of view).
	function K.Pick(set, win, i)
		local key = i and win.keys[i]
		if not key then return end
		win.current = key
		if set.opts.picked then set.opts.picked(win, key) end
	end

	function Set:Host(h)
		local set = self
		local strip = h.strip
		local win = { n = "host", keys = {}, set = self, buttons = {}, open = false, host = h,
			box = h.box, zone = h.zone, head = strip, band = h.band }
		win.tabs = UI.Tabs(strip, {}, function(i) K.Pick(set, win, i) end, nil, UI.TITLE_SIZE, strip,
			{ tall = h.tall, mid = h.mid, gap = h.gap })
		win.tabs:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT")
		win.probe = UI.TitleText(strip, "", UI.TITLE_SIZE)
		win.probe:Hide()
		self.hosts[#self.hosts + 1] = win
		if self.opts.build then self.opts.build(win) end
		strip:HookScript("OnSizeChanged", function() K.Room(set, win) end)
		K.Room(self, win)
		return win
	end

	-- What lights for a drag of the owner's own (a chat window of the game's carried towards the chat): `win` alone, faintly,
	-- as a place it can go, until Unhint.
	function Set:Hint(win) K.Hint(self, nil, nil, win) end
	function Set:Unhint() K.Unhint() end

	function Set:Window()
		local win
		for n = 1, self.most do
			local free = self.wins[n]
			if not free then
				win = self:Make(n)
				break
			elseif not free.open then
				win = free
				break
			end
		end
		if not win then return nil end
		local from = self.last
		if from and from ~= win and from.open and from.box:IsVisible() and not from.maxed then
			local k = from.box:GetEffectiveScale() / win.box:GetEffectiveScale()
			local left, top = from.box:GetLeft() * k, from.box:GetTop() * k
			Shy.HUD.SetSpot(win.box, { x = left + self.step, y = top - self.step - win.box:GetHeight() })
		end
		self.last = win
		return win
	end

	-- A tab out into a window of its own (`spot`: where its corner stands).
	function Set:Own(key, spot)
		local win = self:Window()
		if not win then return nil end
		if spot then Shy.HUD.SetSpot(win.box, spot) end
		self:Join(win, key)
		self:Show(key)
		win.box:Raise()
		return win
	end

	-- Every tab of one window docked into another at `at`, the one open there open here.
	function Set:Merge(from, to, at)
		local keys, current = { unpack(from.keys) }, from.current
		at = at or #to.keys + 1
		for i, key in ipairs(keys) do self:Join(to, key, at + i - 1) end
		if current then self:Show(current) end
		to.box:Raise()
	end

	Shy:On("SHY_THEME", function()
		for set in pairs(K.sets) do
			for _, win in pairs(set.wins) do
				win.head:Place()
				K.Room(set, win)
			end
			for _, win in ipairs(set.hosts) do K.Room(set, win) end
		end
	end)

	function UI.TabWindows(opts)
		local set = setmetatable({ opts = opts, wins = {}, hosts = {}, of = {}, most = opts.most or 8, step = opts.step or 24 }, Set)
		K.sets[set] = true
		return set
	end
end

-- Text with the accent in escape codes (B.Name, UI.Hex) keeps the color it was written in.
-- UI.Themed writes it now and again on every theme change.
--   UI.Themed(fontString, function() return B.Name("Tip") end)

local themed = setmetatable({}, { __mode = "k" })

function UI.Themed(fontString, write)
	themed[fontString] = write
	fontString:SetText(write())
end

Shy:On("SHY_THEME", function()
	for fontString, write in pairs(themed) do fontString:SetText(write()) end
end)

UI.Hex, UI.Wrap = Theme.Hex, Theme.Wrap

-- UI.Armed: an attention mark on a frame. Colored brackets on its corners and a light that crosses its
-- top edge, pauses, and repeats. Flat color bars a whole number of screen pixels thick; no art files.
--
--   local mark = UI.Armed(frame, opts)   -- a child frame over `frame`, hidden until armed
--       opts.arm     bracket arm length (9)
--       opts.thick   thickness in units (1.6: two pixels on most screens)
--       opts.out     distance outside the frame's edge (0; negative: inside)
--       opts.light   width of the light (40)
--   mark:Arm(color, cycle, crossing)     -- { r, g, b }; the light starts every `cycle` seconds (2.6)
--                                        -- and takes `crossing` seconds to cross (1.4)
--   mark:Disarm()

do
	local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

	local function Lit(c, white)
		return c[1] + (1 - c[1]) * white, c[2] + (1 - c[2]) * white, c[3] + (1 - c[3]) * white
	end

	local function Run(self)
		local t = (GetTime() - self.since) % self.cycle
		local span = self.clip:GetWidth() + self.wide
		self.light:SetPoint("LEFT", self.clip, "LEFT", min(t / self.crossing, 1) * span - self.wide, 0)
	end

	local function Arm(self, color, cycle, crossing)
		local r, g, b = Lit(color, 0.3)
		for _, t in ipairs(self.brackets) do t:SetColorTexture(r, g, b) end
		r, g, b = Lit(color, 0.6)
		local faint, lit = CreateColor(color[1], color[2], color[3], 0), CreateColor(r, g, b, 1)
		self.rise:SetGradient("HORIZONTAL", faint, lit)
		self.fall:SetGradient("HORIZONTAL", lit, faint)
		self.cycle, self.crossing = cycle or 2.6, crossing or 1.4
		-- Re-arming while shown doesn't restart the light.
		if not self:IsShown() then self.since = GetTime() end
		self:Show()
	end

	function UI.Armed(frame, opts)
		opts = opts or {}
		local arm, out, wide = opts.arm or 9, opts.out or 0, opts.light or 40
		local m = CreateFrame("Frame", nil, frame)
		m:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out)
		m:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
		local thick = PixelUtil.GetNearestPixelSize(opts.thick or 1.6, frame:GetEffectiveScale(), 1)   -- whole screen pixels
		m.brackets = {}
		for _, corner in ipairs(CORNERS) do
			local across, down = m:CreateTexture(nil, "OVERLAY"), m:CreateTexture(nil, "OVERLAY")
			across:SetSize(arm, thick)
			down:SetSize(thick, arm)
			across:SetPoint(corner)
			down:SetPoint(corner)
			m.brackets[#m.brackets + 1] = across
			m.brackets[#m.brackets + 1] = down
		end
		-- A clipping strip between the top two brackets holds the light.
		m.clip = CreateFrame("Frame", nil, m)
		m.clip:SetPoint("TOPLEFT", arm, 0)
		m.clip:SetPoint("TOPRIGHT", -arm, 0)
		m.clip:SetHeight(thick)
		m.clip:SetClipsChildren(true)
		m.light = CreateFrame("Frame", nil, m.clip)
		m.light:SetSize(wide, thick)
		m.light:SetPoint("LEFT", m.clip, "LEFT", -wide, 0)   -- off-strip; Run moves it
		-- Two gradients: up to the bright middle, and down again.
		m.rise, m.fall = m.light:CreateTexture(nil, "OVERLAY"), m.light:CreateTexture(nil, "OVERLAY")
		m.rise:SetPoint("TOPLEFT")
		m.rise:SetPoint("BOTTOMRIGHT", m.light, "BOTTOM")
		m.fall:SetPoint("TOPLEFT", m.light, "TOP")
		m.fall:SetPoint("BOTTOMRIGHT")
		for _, t in ipairs({ m.rise, m.fall }) do
			t:SetColorTexture(1, 1, 1)
			t:SetBlendMode("ADD")
		end
		m.wide, m.cycle, m.crossing, m.since = wide, 2.6, 1.4, 0
		m.Arm, m.Disarm = Arm, m.Hide
		m:Hide()
		m:SetScript("OnUpdate", Run)
		return m
	end
end

-- Shy.Reload("Why, in a sentence.")
--
-- This client blocks C_UI.Reload() from addon code, even on a hardware click ("Interface action failed
-- because of an AddOn"). A secure macro button running /reload works, so this shows a small panel with
-- that button. The button is protected, so the panel waits until combat ends.
--
-- Shy.HoldReload(true) ... Shy.HoldReload(false): for a caller that reloads itself with a secure button
-- of its own (the setup window's Finish). Meanwhile Shy.Reload only notes it was asked; the second call
-- returns whether it was.
-- From a button, a timer or an event, call this. ReloadUI() does work from a typed slash command (/rl).

local reload = { frame = nil, waiting = nil }

local function BuildReload()
	local f = CreateFrame("Frame", "ShyReloadPrompt", UIParent)
	f:SetSize(360, 100)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)   -- so clicks don't fall through to the world
	f:Hide()
	UI.Head(f, { title = "Reload to finish" })
	-- Its words and buttons on its body: clear of the look's work round the edge, the prompt that much bigger.
	local body = UI.Body(f)
	UI.BodyFit(f, 360, 100)
	f.words = UI.Text(body, "", 12)
	f.words:SetPoint("TOPLEFT", 10, -30)
	f.words:SetWidth(340)
	f.words:SetWordWrap(true)

	-- A secure macro button: the click runs /reload.
	local go = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
	go:SetSize(110, 24)
	go:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 8)
	go:RegisterForClicks("AnyUp", "AnyDown")
	go:SetAttribute("type", "macro")
	go:SetAttribute("macrotext", SLASH_RELOAD1)
	UI.ButtonFace(go, "Reload", C.fill)
	go:SetScript("OnEnter", function(self) UI.SetBorder(self, C.hot) end)
	go:SetScript("OnLeave", function(self) UI.SetBorder(self, C.border) end)
	f.go = go

	f.later = UI.Button(f, "Not now", 80, function()
		if InCombatLockdown() then return end
		f:Hide()
	end)
	f.later:SetPoint("RIGHT", go, "LEFT", -8, 0)
	return f
end

local function ShowReload(words)
	reload.frame = reload.frame or BuildReload()
	reload.frame.words:SetText(words)
	reload.frame:Show()
end

function Shy.Reload(words)
	words = words or "A reload is needed to apply this."
	if reload.held then
		reload.asked = true
		return
	end
	if InCombatLockdown() then
		if not reload.waiting then Shy.core:Print("a reload is needed to finish. The Reload button appears after combat.") end
		reload.waiting = words
		return
	end
	ShowReload(words)
end

function Shy.HoldReload(on)
	local asked = reload.asked and true or false
	reload.held, reload.asked = on and true or nil, nil
	return asked
end

local reloadWait = CreateFrame("Frame")
reloadWait:RegisterEvent("PLAYER_REGEN_ENABLED")
reloadWait:SetScript("OnEvent", function()
	local words = reload.waiting
	if not words then return end
	reload.waiting = nil
	ShowReload(words)
end)
