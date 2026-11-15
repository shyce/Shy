-- Preview of the arranged screen.
--   P.Section(parent, width)           scaled drawing of the screen with the layouts, sizes and bars to pick from
--   P.Stage(parent, width, opts)       the drawing alone: S:Draw(size, style, grow, vessel), S.holder (the setup pages'
--                                      cards); opts.focus = "vessel" draws the cooldown manager alone, large, `opts.height`
--                                      tall (Picker.lua), opts.mini a thumbnail of it (no names, no flap); `vessel` is a
--                                      choice of its scale and bars' side to draw; opts.look = function() -> look
--                                      dresses every housing drawn in that look (a setup plan's pick), else the theme's
--   P.Choice(section, field, key, width, height, name, words)   a choice tile: section:Choose / section:Look
--   P.BarsDrawing(parent, dot, gap)    a small drawing of a bars step: f:Paint(have, want)
--   P.ShowGhost(size, cockpit, style)  the same plan as labelled outlines on the real screen (layout mode)
--   P.HideGhost()
-- The drawing is a screen-sized frame scaled down, so pieces are placed in
-- screen units straight from Layout.Plan and Layout.Cockpit. The cooldown manager
-- is drawn by Picker.lua (ns.Vessel.DrawOn) with the stage's tools (S.tools).

local ADDON, ns = ...
local T = ns.T
local UI, Skin, Theme, Console = Shy.UI, Shy.Skin, Shy.Theme, ns.Console
local floor, max, min = math.floor, math.max, math.min
local C = UI.colors

local P = {}
ns.Preview = P

local MEDIA = "Interface\\AddOns\\ShyDock\\Media\\"

P.NAMES = { compact = "Compact", roomy = "Roomy", grand = "Grand" }
local WORDS = {
	compact = "Chat and meter level with your unit frames. Small text.",
	roomy = "Wider and a little taller. Medium text.",
	grand = "Widest and tallest. Large text, for a big screen.",
}
P.STYLES = { console = "Console", flanks = "Flanks", open = "Open", stack = "Stack",
	center = "Center", healer = "Healer", tank = "Tank", minimal = "Minimal" }
-- The layouts as they are named in a sentence.
P.STYLE_NAMED = { console = "the console", flanks = "the flanks", open = "the open layout", stack = "the stack",
	center = "the center cluster", healer = "the healer grid", tank = "the tank layout", minimal = "the minimal layout" }
-- The two rows they are offered in, and each row's name.
P.STYLE_ROWS = { { "Classic", ns.Console.CLASSIC_ORDER }, { "By role", ns.Console.ROLE_ORDER } }
local STYLE_WORDS = {
	console = "Chat, bars and meter joined along the bottom.",
	flanks = "Bars in the middle, a rack at each side.",
	open = "Bars in the middle, a shelf at each end.",
	stack = "Every bar in one block in the middle.",
	center = "Your frames either side of your character, the bars under your feet. For damage and levelling.",
	healer = "Your party or raid right under your character, your own frames out to the sides.",
	tank = "The threat meter tall beside your target, your target's target over it.",
	minimal = "Everything small and close to your character. Bars 2 and 3 and the meter only in a fight.",
}
P.STYLE_WORDS = STYLE_WORDS

local DIM, ACCENT = C.dim, Theme.Accent

-- What the bars come to, said in a line: with `grow`, the step the abilities call for.
local COUNT = { "One bar", "Two bars", "Three bars" }
function P.BarsWords(grow)
	if not grow then return "Every bar from the start: three rows and both side bars." end
	local L = ns.Layout
	local step = L.STEPS[L.GrowStep()]
	local sides = step.sides > 1 and "both side bars" or "a side bar for food and potions"
	return COUNT[step.rows] .. " and " .. sides .. " for now; more as you learn abilities."
end

-- The pieces: the planned screen as Parts.lua lists it. cockpit = false leaves the cockpit out. With them
-- the column down from the top's middle, every piece of it in its place (Shy.Top).
local function Pieces(g, now, cockpit)
	local c = cockpit ~= false and ns.Layout.Cockpit(now) or nil
	local skin = Shy.addons.Skin
	local stand = skin and skin.StandPiece and skin:StandPiece() or nil
	local threat = Shy.addons.Threat
	local farm = Shy.addons.Farm
	return ns.Parts.List(g, now, c, { deck = T.db.deck, arrange = T.db.arrange, top = Shy.Top and Shy.Top.Plan(true) or nil,
		stand = stand, threat = threat and threat.Piece and threat:Piece() or nil, farm = farm and farm.Piece and farm:Piece() or nil })
end
P.Pieces = Pieces

-- The ghost: labelled outlines on the real screen, one per piece with a label

local LABEL_W, LABEL_H = 44, 16   -- smallest piece that gets a label

local ghost, ghosts = nil, {}

local function GhostFill()
	local r, g, b = ACCENT()
	return r, g, b, 0.12
end

-- cockpit = false leaves the cockpit out (see Pieces).
function P.ShowGhost(key, cockpit, style)
	if not ghost then
		ghost = CreateFrame("Frame", "ShyDockGhost", UIParent)
		ghost:SetAllPoints(UIParent)
		ghost:SetFrameStrata("HIGH")
		ghost:EnableMouse(false)
	end
	-- As a setup leaves it: bars and meter on, or the bars a growing character's abilities call for.
	local g, now = ns.Layout.Plan(key, true, style, ns.Layout.Grows())
	local used = 0
	for _, piece in ipairs(Pieces(g, now, cockpit)) do
		if piece.label then
			used = used + 1
			local f = ghosts[used]
			if not f then
				f = CreateFrame("Frame", nil, ghost)
				f:EnableMouse(false)
				UI.Skin(f, GhostFill, ACCENT)
				f.label = UI.Text(f, "", 11, false, C.text)
				f.label:SetPoint("CENTER")
				ghosts[used] = f
			end
			local w, h = piece[3] - piece[1], piece[4] - piece[2]
			f.label:SetText(piece.label)
			f.label:SetShown(w >= LABEL_W and h >= LABEL_H)
			f:ClearAllPoints()
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", piece[1], piece[2])
			f:SetSize(w, h)
			f:Show()
		end
	end
	for i = used + 1, #ghosts do ghosts[i]:Hide() end
	ghost:Show()
end

function P.HideGhost()
	if ghost then ghost:Hide() end
end

-- The stage: the scaled drawing

local FIELD = { 0.03, 0.035, 0.045, 1 }            -- backdrop
local WORLD = MEDIA .. "World"                     -- the world behind the drawing: a view of Durotar
local WORLD_SHAPE = 16 / 9                         -- the view's width to its height
local WELL = { 0.02, 0.02, 0.025 }                 -- bar track
local MAP = { 0.09, 0.14, 0.15 }                   -- minimap face
local GEM = { 0.20, 0.23, 0.29 }                   -- placeholder icon
local HEALTH = { 0.17, 0.76, 0.31 }
local POWER = { ROGUE = { 0.94, 0.82, 0.23 }, WARRIOR = { 0.78, 0.25, 0.25 } }
local MANA = { 0.25, 0.47, 0.92 }
local HOUSING = { cap = true, facets = false, line = false, brackets = 10 }   -- housing and racks
local WING = { cap = true, title = UI.HEAD_STRIP, facets = false }             -- pieces with a header
P.COLORS ={ HEALTH = HEALTH, POWER = POWER, MANA = MANA, GEM = GEM }   -- for the vessel's drawing (Picker.lua)
-- The bags drawn open: slots across and down, a slot's size, the gap, the pad round them, the seam before the column.
local BAG = { across = 8, down = 4, size = 34, gap = 4, pad = 10, seam = 13 }
local FAINT = 0.5                                  -- a piece that comes and goes, drawn where it would stand

local function Stage(parent, width, opts)
	opts = opts or {}
	local focus = opts.focus == "vessel"
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local mid = sw / 2
	local holder = CreateFrame("Frame", nil, parent)
	-- A band stage (a layout card's thumbnail) shows the screen's bottom band, BAND wide and tall, where
	-- the layouts differ: it is as tall as the band's shape makes it.
	local band = opts.band == true
	local height = focus and (opts.height or 190) or band and floor(width * P.BAND_SHAPE + 0.5) or floor(width * sh / sw + 0.5)
	holder:SetSize(width, height)
	holder:SetClipsChildren(true)
	UI.Skin(holder, FIELD, C.rowEdge)
	-- The world behind: a view of the game, so the pieces read as standing on a screen in it. The
	-- view is 16:9; a screen of another shape takes its middle,
	-- cropped to the screen's shape, never stretched.
	local world = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
	world:SetPoint("TOPLEFT", 1, -1)
	world:SetPoint("BOTTOMRIGHT", -1, 1)
	world:SetTexture(WORLD)
	local shape = (sw / sh) / WORLD_SHAPE
	local u0, u1, v0, v1 = 0, 1, 0, 1
	if shape > 1 then
		local keep = 1 / shape
		v0, v1 = 0.5 - keep / 2, 0.5 + keep / 2
	else
		u0, u1 = 0.5 - shape / 2, 0.5 + shape / 2
	end
	world:SetTexCoord(u0, u1, v0, v1)
	local stage = CreateFrame("Frame", nil, holder)
	stage:SetSize(sw, sh)
	stage:SetScale(width / sw)
	stage:SetPoint("BOTTOMLEFT")

	local S = { holder = holder, stage = stage, focus = focus, mini = opts.mini == true, mid = mid, corner = opts.corner, band = band,
		look = opts.look }
	local frames = {}

	-- The look the drawing's housings wear: a plan's pick, or nil for the theme's.
	function S:Look()
		return self.look and self.look() or nil
	end

	-- A part of the screen fitted to the holder exactly (no margin): a card's band. The world behind is
	-- cropped to that part.
	function S:Band(l, b, r, t)
		local hw, hh = holder:GetWidth(), holder:GetHeight()
		local fit = min(hw / max(1, r - l), hh / max(1, t - b))
		local cx, cy = mid + (l + r) / 2, (b + t) / 2
		stage:SetScale(fit)
		stage:ClearAllPoints()
		stage:SetPoint("BOTTOMLEFT", holder, "CENTER", -cx, -cy)
		local wx, wy = hw / 2 / fit, hh / 2 / fit
		local function U(x) return u0 + (u1 - u0) * max(0, min(1, x / sw)) end
		local function V(y) return v0 + (v1 - v0) * max(0, min(1, 1 - y / sh)) end
		world:SetTexCoord(U(cx - wx), U(cx + wx), V(cy + wy), V(cy - wy))
	end

	-- Focused on the vessel: the stage scaled so the vessel's group at its largest chip size (Picker.lua)
	-- fills the holder (a little past life size at most), so a smaller size draws smaller; centred; the
	-- world behind cropped to that part of the screen. k: the vessel's scale in this drawing. A `corner`
	-- stage shows the group's top left corner at life size instead (a look's thumbnail: the rim, the
	-- gems' socket, the light), `corner` being how far down from the group's top its window's top lies.
	-- `fixed`: the stage's scale as an earlier fit had it (the vessel planned again for that scale). Returns
	-- the scale.
	function S:Focus(l, b, r, t, k, fixed)
		local hw, hh = holder:GetWidth(), holder:GetHeight() - (self.inset or 0)   -- inset: a caption band at the top
		local margin = min(12, hh / 10)
		local largest = 1.25 / (k or 1)
		local fit = fixed or min(1.35, (hw - 2 * margin) / max(1, (r - l) * largest), (hh - 2 * margin) / max(1, (t - b) * largest))
		local cx, cy = mid + (l + r) / 2, (b + t) / 2
		if self.corner then
			fit = 1
			cx, cy = mid + l + hw / 2 - 6, t - self.corner - hh / 2
		end
		self.fit = fit
		stage:SetScale(fit)
		stage:ClearAllPoints()
		stage:SetPoint("BOTTOMLEFT", holder, "CENTER", -cx, -cy - (self.inset or 0) / 2 / fit)
		-- The screen's part on show: half the holder each way, in screen units.
		local wx, wy = hw / 2 / fit, hh / 2 / fit
		local function U(x) return u0 + (u1 - u0) * max(0, min(1, x / sw)) end
		local function V(y) return v0 + (v1 - v0) * max(0, min(1, 1 - y / sh)) end
		world:SetTexCoord(U(cx - wx), U(cx + wx), V(cy + wy), V(cy - wy))
		return fit
	end

	-- Place a region at a plan rectangle.
	local function Put(region, l, b, r, t)
		region:ClearAllPoints()
		region:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", mid + l, b)
		region:SetSize(max(1, r - l), max(1, t - b))
		region:Show()
	end

	-- Frames are made once; their textures come from per-frame pools reset on each Draw.
	local function Piece(key, level, build)
		local f = frames[key]
		if not f then
			f = CreateFrame("Frame", nil, stage)
			f:SetFrameLevel(stage:GetFrameLevel() + level)
			f.pools = {}
			if build then build(f) end
			frames[key] = f
		end
		return f
	end

	local function Region(f, key, make)
		local pool = f.pools[key]
		if not pool then
			pool = { n = 0 }
			f.pools[key] = pool
		end
		pool.n = pool.n + 1
		local t = pool[pool.n]
		if not t then
			t = make()
			pool[pool.n] = t
		end
		return t
	end

	local function Flat(f, color, alpha, sub, l, b, r, t)
		local tex = Region(f, "flat" .. sub, function() return f:CreateTexture(nil, "ARTWORK", nil, sub) end)
		UI.Paint(tex, color, alpha)
		Put(tex, l, b, r, t)
	end
	-- slice: one margin, or { left, top, right, bottom }; tile: the art repeats a texel a unit.
	local function Art(f, file, color, alpha, sub, l, b, r, t, slice, tile)
		local tex = Region(f, file .. sub .. (tile and "t" or ""), function()
			local made = f:CreateTexture(nil, "ARTWORK", nil, sub)
			if tile then
				made:SetTexture(file, "REPEAT", "REPEAT")
				made:SetHorizTile(true)
				made:SetVertTile(true)
			else
				made:SetTexture(file)
			end
			if type(slice) == "table" then
				made:SetTextureSliceMargins(slice[1], slice[2], slice[3], slice[4])
			elseif slice then
				made:SetTextureSliceMargins(slice, slice, slice, slice)
			end
			return made
		end)
		UI.Tint(tex, color, alpha)
		Put(tex, l, b, r, t)
		return tex
	end
	-- A wash in `color` from alpha a1 at the top to a0 at the foot, additive when `add`.
	local function Wash(f, color, a1, a0, sub, l, b, r, t, add)
		local tex = Region(f, "wash" .. sub .. (add and "a" or ""), function()
			local made = f:CreateTexture(nil, "ARTWORK", nil, sub)
			made:SetTexture("Interface\\Buttons\\WHITE8x8")
			if add then made:SetBlendMode("ADD") end
			return made
		end)
		local cr, cg, cb
		if type(color) == "function" then cr, cg, cb = color() else cr, cg, cb = color[1], color[2], color[3] end
		tex:SetGradient("VERTICAL", CreateColor(cr, cg, cb, a0), CreateColor(cr, cg, cb, a1))
		Put(tex, l, b, r, t)
		return tex
	end
	-- A picture (a texture file or id) in a frame: an ability's icon as the game shows it.
	local function Picture(f, texture, l, b, size)
		local tex = Region(f, "picture", function() return f:CreateTexture(nil, "ARTWORK", nil, 0) end)
		tex:SetTexture(texture)
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		tex:SetVertexColor(1, 1, 1, 1)
		Put(tex, l, b, l + size, b + size)
		Art(f, Skin.FRAME, Theme.skin.metal, 1, 1, l, b, l + size, b + size, Skin.FRAME_SLICE)
	end

	-- A housing of the console's make, in the drawing's look; `fill` for one that isn't the HUD's graphite.
	local function Panel(key, level, opts, l, b, r, t, fill)
		local f = Piece(key, level, function(made) UI.Panel(made, opts) end)
		UI.SetFill(f, fill or ns.Graphite)
		UI.SetLook(f, S:Look())
		Put(f, l, b, r, t)
		return f
	end

	local function Tile(f, l, b, size, alpha)
		Flat(f, C.rowEdge, alpha or 1, 0, l, b, l + size, b + size)
		Flat(f, C.bgHot, alpha or 1, 1, l + 1.5, b + 1.5, l + size - 1.5, b + size - 1.5)
	end
	local function Icon(f, l, b, size)
		Flat(f, GEM, 1, 0, l, b, l + size, b + size)
		Art(f, Skin.FRAME, Theme.skin.metal, 1, 1, l, b, l + size, b + size, Skin.FRAME_SLICE)
	end
	local function Bar(f, color, alpha, l, b, r, t, share)
		Flat(f, WELL, 1, 0, l, b, r, t)
		Art(f, Skin.HATCH, color, alpha, 1, l + 1, b + 1, l + 1 + (r - l - 2) * (share or 1), t - 1)
	end
	local LINES = { 0.9, 0.55, 0.75, 0.4, 0.8, 0.6 }
	local function Lines(f, l, b, r, t)
		local y, i = t - 12, 0
		while y - 5 > b and i < #LINES do
			i = i + 1
			Flat(f, DIM, 0.28, 0, l, y - 5, l + (r - l) * LINES[i], y)
			y = y - 16
		end
	end
	-- A ShyFrames unit frame; `k` fades it (a frame drawn only to show where it would stand).
	local function Plate(f, l, b, r, t, color, k)
		k = k or 1
		local h = t - b
		Flat(f, C.border, k, 0, l, b, r, t)
		Flat(f, WELL, k, 1, l + 1, b + 1, r - 1, t - 1)
		Art(f, Skin.HATCH, color, 0.9 * k, 2, l + 3, b + h * 0.40, r - 3, t - 5)
		Art(f, Skin.HATCH, DIM, 0.55 * k, 2, l + 3, b + 3, r - 3, b + h * 0.34)
		Flat(f, ACCENT, k, 3, l + 2, t - 3, r - 2, t - 1)
	end

	S.tools = { Put = Put, Piece = Piece, Region = Region, Flat = Flat, Art = Art, Panel = Panel, Tile = Tile, Icon = Icon, Bar = Bar,
		Wash = Wash, Picture = Picture }

	-- size, style: the console's, or nil for the one in use. grow: draw the
	-- bars of the step the abilities call for (see Layout.Plan). vessel: the
	-- cooldown manager's scale and bars' side to draw, or nil for the ones in use.
	-- drawer: the menu in a drawer (tucked, as a setup leaves it) or not; nil for as it is.
	-- bags: where the bag buttons are, "screen" (their row under the menu's) or "window" (ShyBags' column);
	-- nil for as they are. look: that choice is being looked at, so the drawer is drawn out, and for
	-- "window" the bags are drawn open with their column.
	function S:Draw(key, style, grow, vessel, drawer, bags, look)
		local L = ns.Layout
		local function Clear()
			for _, f in pairs(frames) do
				f:Hide()
				for _, pool in pairs(f.pools) do
					for i = 1, #pool do pool[i]:Hide() end
					pool.n = 0
				end
			end
		end
		Clear()
		local g, now = L.Plan(key, true, style, grow)
		if vessel then now.vessel = vessel end
		if drawer ~= nil then now.drawer, now.tucked = drawer, drawer end
		if bags ~= nil then L.WithBags(now, bags == "screen") end
		if look then now.tucked = false end
		local c = L.Cockpit(now)
		local half = now.screen / 2
		if focus and ns.Vessel and ns.Vessel.DrawOn then
			-- The vessel with everything it has showing, the cooldowns that wait for a fight and the cast
			-- bar's row too: one state, planned and drawn, so every piece stands in the plate and nothing is
			-- planned where another will come.
			local all = L.Shown(now, true)
			local function Show(plan, fixed)
				local l, b, r, t = ns.Vessel.DrawOn(self, plan, all)
				if self.corner then
					local bx = plan.rects.box
					l, b, r, t = bx[1], bx[2], bx[3], bx[4]
				end
				return self:Focus(l, b, r, t, plan.scale, fixed)
			end
			-- The drawing is the vessel planned for the drawing: once to learn the scale it is shown at, then
			-- again on that scale's own pixels (the stage's and the page's), so a small vessel's paddings and
			-- icons are whole pixels like the real one's, never a big one shrunk.
			local fit = Show(L.Cockpit(all))
			local own = (now.ppu or 1) * fit * holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
			if math.abs(own - (now.ppu or 1)) > 0.001 then
				Clear()
				all.ppu = own
				Show(L.Cockpit(all), fit)
			end
			return
		end

		-- Every piece as Parts.lua lists it, each kind drawn its way: the panels (chat, the meter, the
		-- housing, the racks, the minimap, the guide and the objectives) are frames of their own with
		-- the console's art; the rest (buttons, plates, icons, cells) are textures in one frame over them.
		local loose = Piece("loose", 3)
		Put(loose, -half, 0, half, sh)
		local FILL = { health = HEALTH, bad = C.bad, mana = MANA }
		local share = { 1, 0.78, 0.6, 0.41 }   -- the meter's bars
		local parts = Pieces(g, now)
		for _, part in ipairs(parts) do
			local l, b, r, t, kind = part[1], part[2], part[3], part[4], part.kind
			if part.group then
				-- a labelled outline round smaller pieces: nothing to draw
			elseif kind == "chat" then
				local chat = Panel("chat", 2, WING, l, b, r, t)
				Lines(chat, l + 12, b + 10, r - 12, t - UI.HEAD_STRIP - 6)
			elseif kind == "meter" then
				local meter = Panel("meter", 2, WING, l, b, r, t)
				local top = t - UI.HEAD_STRIP - 6
				for i = 1, #share do
					local y = top - (i - 1) * 18
					if y - 16 > b + 6 then Bar(meter, ACCENT, 0.85, l + 6, y - 16, r - 6, y, share[i]) end
				end
			elseif kind == "housing" then
				Panel("housing", 2, HOUSING, l, b, r, t)
			elseif kind == "rack" then
				Panel(l < 0 and "rackLeft" or "rackRight", 2, HOUSING, l, b, r, t)
			elseif kind == "tray" then
				Panel("tray", 2, HOUSING, l, b, r, t)
			elseif kind == "pull" then
				-- a drawer's pull: a steel strip with the accent's light along the edge it hangs from
				Flat(loose, C.border, 1, 1, l, b, r, t)
				Flat(loose, C.hud, 1, 2, l + 1, b + 1, r - 1, t - 1)
				if part.side == "top" then Flat(loose, ACCENT, 0.9, 3, l + 2, b + 1, r - 2, b + 2)
				elseif part.side == "left" then Flat(loose, ACCENT, 0.9, 3, r - 2, b + 2, r - 1, t - 2)
				else Flat(loose, ACCENT, 0.9, 3, l + 1, b + 2, l + 2, t - 2) end
			elseif kind == "button" then
				Tile(loose, l, b, r - l)
			elseif kind == "xp" then
				Bar(loose, ACCENT, 0.8, l, b, r, t, part.share)
			elseif kind == "plate" or kind == "small" then
				Plate(loose, l, b, r, t, FILL[part.color] or HEALTH, part.faint and 0.5 or 1)
			elseif kind == "petbar" then
				local pitch = (r - l) / part.cells
				for i = 0, part.cells - 1 do Tile(loose, l + i * pitch, b, t - b, 0.5) end
			elseif kind == "map" then
				local map = Panel("map", 2, WING, l, b, r, t)
				Flat(map, MAP, 1, 0, l + 4, b + 4, r - 4, t - UI.HEAD_STRIP - 4)
			elseif kind == "buff" then
				-- an icon (its duration line is too small to draw here)
				Icon(loose, l, b, r - l)
			elseif kind == "debuff" then
				Flat(loose, C.bad, 1, 2, l - 2, b - 2, r + 2, t + 2)
				Icon(loose, l, b, r - l)
			elseif kind == "menu" then
				local cell = (r - l) / part.cells
				for i = 1, part.cells do Flat(loose, C.rowEdge, 1, 0, r - i * cell + 1, b, r - (i - 1) * cell - 1, t) end
			elseif kind == "bags" then
				local size = t - b
				for i = 1, part.cells do Tile(loose, r - i * size, b, size - 2) end
			elseif kind == "guide" or kind == "objectives" then
				local panel = Panel(kind, 2, WING, l, b, r, t)
				Lines(panel, l + 12, b + 10, r - 12, t - UI.HEAD_STRIP - 6)
			elseif kind == "extra" then
				-- the slot an extra ability comes up in, over the cockpit: there only while there is one
				Tile(loose, l, b, r - l, FAINT)
			elseif kind == "threat" and not band then
				-- the threat meter at the deck's lower end, there only in a fight: a seam, the mob's line, then its
				-- bars in the threat colors, the holder's full, faint as what comes and goes
				Flat(loose, C.rowEdge, 0.9 * FAINT, 1, l + 3, t - 1, r - 3, t)
				Flat(loose, DIM, 0.28 * FAINT, 0, l + 12, t - 14, l + (r - l) * 0.5, t - 9)
				local THREAT = Theme.THREAT
				local rows = { { 1, THREAT.held }, { 0.86, THREAT.slipping }, { 0.6, THREAT.held }, { 0.45, THREAT.held } }
				local top = t - 20
				for i, row in ipairs(rows) do
					local y = top - (i - 1) * 18
					if y - 16 > b + 6 then Bar(loose, row[2], 0.85 * FAINT, l + 10, y - 16, r - 6, y, row[1]) end
				end
			elseif kind == "farm" and not band then
				-- a farming session in the top left's corner, there only while you farm: its plate, what it made in gold
				-- and an hour in your color, then loot rows (a picture, a name, its worth), faint as what comes and goes
				local k = FAINT
				Flat(loose, C.panel, 0.85 * k, 0, l, b, r, t)
				Flat(loose, ACCENT, 0.9 * k, 1, l + 2, t - 2, r - 2, t - 1)
				Flat(loose, C.alert, 0.7 * k, 0, l + 10, t - 16, l + 10 + (r - l) * 0.24, t - 9)
				Flat(loose, ACCENT, 0.8 * k, 0, r - 10 - (r - l) * 0.2, t - 16, r - 10, t - 9)
				local share = { 0.5, 0.62, 0.42, 0.3 }
				local y = t - 26
				for i = 1, #share do
					if y - 12 < b + 4 then break end
					Tile(loose, l + 10, y - 12, 12, k)
					Flat(loose, DIM, 0.28 * k, 0, l + 28, y - 9, l + 28 + (r - l - 80) * share[i], y - 4)
					Flat(loose, C.alert, 0.45 * k, 0, r - 34, y - 9, r - 10, y - 4)
					y = y - 17
				end
			elseif (kind == "top" or kind == "stand") and part.piece.sample and not band then
				-- A piece of the top's column (or the armor stand): at this size its own picture is a clutter of
				-- small words, so it stands as a plain plaque, the accent's light along its top; one that comes
				-- and goes is drawn faint, one with no picture keeps its room and is left out. A band shows the
				-- screen's foot: nothing of the column.
				local k = part.piece.passing and FAINT or 1
				Flat(loose, C.panel, 0.85 * k, 0, l, b, r, t)
				Flat(loose, ACCENT, 0.9 * k, 1, l + 2, t - 2, r - 2, t - 1)
			end
		end

		-- The bags open, left of the minimap's column over the console: their items, and past a hairline
		-- the column of bag slots, lit.
		if look and bags == "window" then
			local size, gap, pad, seam = BAG.size, BAG.gap, BAG.pad, BAG.seam
			local wide = pad + BAG.across * (size + gap) - gap + seam + size + pad
			local tall = UI.HEAD_STRIP + pad + BAG.down * (size + gap) - gap + pad
			local r = half - Console.CORNER - now.map.width - 2 * Console.SEAM
			local b = ns.Parts.ColumnFloor(g, now)
			local l, t = r - wide, b + tall
			local window = Panel("bags", 4, WING, l, b, r, t)
			for row = 0, BAG.down - 1 do
				local y = b + pad + row * (size + gap)
				for i = 0, BAG.across - 1 do Tile(window, l + pad + i * (size + gap), y, size) end
			end
			local x = r - pad - size
			Flat(window, C.border, 0.9, 0, x - seam / 2, b + pad, x - seam / 2 + 1, t - UI.HEAD_STRIP - pad)
			for row = 0, BAG.down - 1 do
				local y = b + pad + row * (size + gap)
				Flat(window, ACCENT, 1, 0, x, y, x + size, y + size)
				Flat(window, C.bgHot, 1, 1, x + 2, y + 2, x + size - 2, y + size - 2)
			end
		end

		-- The cockpit (Picker.lua draws it with the stage's tools).
		if ns.Vessel and ns.Vessel.DrawOn then ns.Vessel.DrawOn(self, c, now) end
		-- A card's band: the screen's middle, from the floor up over the plates, where the layouts differ; by role
		-- from the experience bar up over your frames, which stand round your character.
		if band then
			local foot = g.role and max(0, (g.xp or 0) - Console.SEAM) or 0
			self:Band(-P.BAND[1] / 2, foot, P.BAND[1] / 2, foot + P.BAND[2])
		end
	end

	return S
end

P.Stage = Stage
P.WORDS, P.STYLE_WORDS = WORDS, STYLE_WORDS

-- A layout card: a thumbnail of the screen's bottom band with that layout, its name under it, "in use"
-- when the console is set up with it. The band is BAND[1] wide and BAND[2] tall in screen units, so a
-- thumbnail is BAND_SHAPE as tall as it is wide: 200 x 58 on the setup page.
-- Wide enough for the console at its grand size with both wings (470 each) and the seams, so no layout's
-- thumbnail cuts its wings off.
P.BAND = { 1560, 348 }
P.BAND_SHAPE = P.BAND[2] / P.BAND[1]
local CARD_PAD, CARD_NAME = 6, 15   -- the thumbnail's inset; the name's line

function P.CardHeight(width)
	return CARD_PAD + floor((width - 2 * CARD_PAD - 2) * P.BAND_SHAPE + 0.5) + 4 + CARD_NAME + 9
end

-- look: the Stage's opts.look, for a card on a setup page.
function P.Card(parent, width, key, onClick, onLook, look)
	local b = CreateFrame("Button", nil, parent)
	local thumb = width - 2 * CARD_PAD - 2
	b:SetSize(width, P.CardHeight(width))
	UI.Skin(b)
	b.glow = b:CreateTexture(nil, "BORDER", nil, -1)
	b.glow:SetTexture(Skin.GLOW)
	b.glow:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	b.glow:SetPoint("TOPLEFT", -3, 3)
	b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
	UI.Tint(b.glow, C.hot, 0.6)
	b.glow:Hide()
	b.stage = Stage(b, thumb, { band = true, look = look })
	b.stage.holder:SetPoint("TOP", 0, -CARD_PAD)
	b.name = UI.Text(b, P.STYLES[key], 14, true)
	b.name:SetPoint("TOP", b.stage.holder, "BOTTOM", 0, -4)
	b.used = UI.Text(b, "in use", 10, true, C.good)
	b.used:SetPoint("TOPRIGHT", -8, -8)
	b.used:Hide()
	b.key = key

	-- lit: the layout picked. inUse: the console is set up with it. off: the choice is dimmed.
	function b:Paint(lit, inUse, off)
		self:SetAlpha(off and 0.5 or 1)
		self.lit = lit and true or false
		self.inUse = inUse and true or false
		self.used:SetShown(inUse and true or false)
		UI.SetBorder(self, (lit or self.hover) and C.hot or C.border)
		UI.SetFill(self, lit and C.row or C.bg)
		UI.Ink(self.name, lit and C.head or C.text)
		self.glow:SetShown(lit and true or false)
	end
	b:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(key)
	end)
	b:SetScript("OnEnter", function(self)
		self.hover = true
		UI.SetBorder(self, C.hot)
		onLook(key)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		UI.SetBorder(self, self.lit and C.hot or C.border)
		onLook(nil)
	end)
	return b
end

-- A small drawing of the bars of a step: three rows of twelve from the floor up, the side bars
-- beside them (the first at the right). f:Paint(have, want): what step `have` has in the text color,
-- what `want` adds in the accent, every other button an empty slot. Either may be nil.
function P.BarsDrawing(parent, dot, gap)
	dot, gap = dot or 5, gap or 1
	local f = CreateFrame("Frame", nil, parent)
	local across = 12 * dot + 11 * gap
	local side = 2 * dot + gap
	local apart = dot - gap + 2
	f:SetSize(across + 2 * (side + apart), 3 * dot + 2 * gap)
	f.dots = {}
	local function Dot(key, n, x, y)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetSize(dot, dot)
		t:SetPoint("BOTTOMLEFT", x, y)
		f.dots[#f.dots + 1] = { t, key, n }
	end
	for row = 1, 3 do
		for i = 0, 11 do Dot("rows", row, side + apart + i * (dot + gap), (row - 1) * (dot + gap)) end
	end
	for s = 1, 2 do
		local x = s == 1 and side + apart + across + apart or 0
		for row = 0, 2 do
			for i = 0, 1 do Dot("sides", s, x + i * (dot + gap), row * (dot + gap)) end
		end
	end
	function f:Paint(have, want)
		for _, d in ipairs(self.dots) do
			local count = d[2]
			if have and d[3] <= have[count] then
				UI.Paint(d[1], C.text, 0.75)
			elseif want and d[3] <= want[count] then
				UI.Paint(d[1], ACCENT, 1)
			else
				UI.Paint(d[1], C.rowEdge, 1)
			end
		end
	end
	return f
end

-- A small drawing of where the bag buttons are. f:Paint("window"): the bags with a column of slots at
-- their side, in the accent; f:Paint("screen"): the menu's row with the bags' row under it.
function P.BagsDrawing(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(34, 24)
	f.sets = { window = {}, screen = {} }
	local function Dot(set, x, y, w, h, lit)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetSize(w, h)
		t:SetPoint("TOPLEFT", x, -y)
		table.insert(f.sets[set], { t, lit })
	end
	for row = 0, 2 do
		for i = 0, 3 do Dot("window", i * 6, 3 + row * 6, 5, 5) end
		Dot("window", 28, 3 + row * 6, 5, 5, true)
	end
	for i = 0, 6 do Dot("screen", i * 5, 3, 4, 7) end
	for i = 1, 4 do Dot("screen", 35 - i * 7, 13, 6, 6, true) end
	function f:Paint(where)
		for key, set in pairs(self.sets) do
			for _, d in ipairs(set) do
				d[1]:SetShown(key == where)
				if d[2] then UI.Paint(d[1], ACCENT, 1) else UI.Paint(d[1], C.text, 0.4) end
			end
		end
		self.where = where
	end
	return f
end

-- A small drawing of the side bars beside the bars: f:Paint(out, there), each { left =, right = }. A bar out
-- stands as its block of buttons, in the accent; one tucked away is only its pull, a line at the bars' side;
-- with no bar on that side (there) nothing stands there.
function P.SidesDrawing(parent)
	local dot, gap, apart = 4, 1, 4
	local rowsW, block = 10 * dot + 9 * gap, 2 * dot + gap
	local tall = 3 * dot + 2 * gap
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(rowsW + 2 * (block + apart), 24)
	local y = (24 - tall) / 2
	f.rows, f.blocks, f.pulls = {}, { left = {}, right = {} }, {}
	local function Dot(list, x, row)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetSize(dot, dot)
		t:SetPoint("BOTTOMLEFT", x, y + row * (dot + gap))
		list[#list + 1] = t
	end
	for row = 0, 2 do
		for i = 0, 9 do Dot(f.rows, block + apart + i * (dot + gap), row) end
		for i = 0, 1 do
			Dot(f.blocks.left, i * (dot + gap), row)
			Dot(f.blocks.right, block + apart + rowsW + apart + i * (dot + gap), row)
		end
	end
	for side, x in pairs({ left = block + apart - 3, right = block + apart + rowsW + 1 }) do
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetSize(2, tall)
		t:SetPoint("BOTTOMLEFT", x, y)
		f.pulls[side] = t
	end
	for _, t in ipairs(f.rows) do UI.Paint(t, C.text, 0.4) end
	function f:Paint(out, there)
		for _, side in ipairs({ "left", "right" }) do
			local here = there[side] and true or false
			for _, t in ipairs(self.blocks[side]) do
				t:SetShown(here and out[side] == true)
				UI.Paint(t, ACCENT, 1)
			end
			self.pulls[side]:SetShown(here and out[side] ~= true)
			UI.Paint(self.pulls[side], ACCENT, 1)
		end
		self.out, self.there = out, there
	end
	return f
end

-- The section: drawing, choice tiles, status line

local GAP = 8
local LIGHT = 6
local sections = {}

-- A choice tile: a light, a name and a line of words.
local function Choice(section, field, key, width, height, name, words)
	local b = CreateFrame("Button", nil, section)
	b:SetSize(width, height)
	UI.Skin(b)
	b.glow = b:CreateTexture(nil, "BORDER", nil, -1)
	b.glow:SetTexture(Skin.GLOW)
	b.glow:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	b.glow:SetPoint("TOPLEFT", -3, 3)
	b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
	UI.Tint(b.glow, C.hot, 0.7)
	b.glow:Hide()
	local well = CreateFrame("Frame", nil, b)
	well:SetSize(LIGHT + 2, LIGHT + 2)
	well:SetPoint("TOPLEFT", 10, -11)
	UI.Skin(well, C.bg, C.border)
	b.light = well:CreateTexture(nil, "ARTWORK")
	b.light:SetPoint("TOPLEFT", 1, -1)
	b.light:SetPoint("BOTTOMRIGHT", -1, 1)
	b.name = UI.Text(b, name, 14, true)
	b.name:SetPoint("LEFT", well, "RIGHT", 6, 0)
	b.used = UI.Text(b, "in use", 10, true, C.good)
	b.used:SetPoint("TOPRIGHT", -10, -10)
	b.words = UI.Text(b, words, height < 54 and 10 or 11, false, C.dim)
	b.words:SetPoint("TOPLEFT", 10, -28)
	b.words:SetWidth(width - 20)
	b.words:SetWordWrap(true)

	-- lit: the choice picked. inUse: the console is set up with it.
	function b:Paint(lit, inUse)
		lit = lit and true or false
		self.inUse = lit
		self.used:SetShown(inUse and true or false)
		UI.Paint(self.light, lit and ACCENT or C.bg)
		UI.SetBorder(self, (lit or self.hover) and C.hot or C.border)
		UI.SetFill(self, lit and C.row or C.bg)
		self.glow:SetShown(self.hover and true or false)
	end

	b:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		section:Choose(field, key)
	end)
	b:SetScript("OnEnter", function(self)
		self.hover = true
		section:Look(field, key)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		section:Look(nil)
	end)
	return b
end
P.Choice = Choice

-- The console as it is and as it could be, for the /shy window and the options page: the drawing,
-- then the layouts, the sizes, and bars that grow, picked here and set up with the Set up button.
-- The section's picks start as the console in use.
P.DWELL = 0.12   -- seconds the mouse rests on a choice before the drawing shows it
function P.Section(parent, width)
	local L = ns.Layout
	local f = CreateFrame("Frame", nil, parent)
	local own   -- the picks: { style, size }
	local function Picks()
		own = own or { style = L.Style(), size = L.Size() }
		own.grow = L.Grows()
		return own
	end

	local stage = Stage(f, width)
	stage.holder:SetPoint("TOPLEFT")
	local buttons, styles = {}, {}
	local y = -stage.holder:GetHeight() - GAP
	-- The layouts as cards, a row of the classic ones and a row by role: a thumbnail each of the screen's band where
	-- they differ.
	for _, row in ipairs(P.STYLE_ROWS) do
		local count = #row[2]
		local each = (width - (count - 1) * GAP) / count
		for i, key in ipairs(row[2]) do
			local b = P.Card(f, each, key, function(picked) f:Choose("style", picked) end, function(over) f:Look(over and "style" or nil, over) end)
			b:SetPoint("TOPLEFT", (i - 1) * (each + GAP), y)
			styles[key] = b
		end
		y = y - P.CardHeight(each) - GAP
	end
	local each
	each = (width - 2 * GAP) / 3
	for i, key in ipairs(Console.SIZE_ORDER) do
		local b = Choice(f, "size", key, each, 58, P.NAMES[key], WORDS[key])
		b:SetPoint("TOPLEFT", (i - 1) * (each + GAP), y)
		buttons[key] = b
	end
	y = y - 58 - 12
	local grow = UI.Checkbox(f, "Grow with me", function() return L.Grows() end, function(v)
		ns.char.grow = v and true or false
		f:Refresh()
	end, { desc = "Start with one bar and a side bar for food and potions. When your abilities outgrow your bars, you're asked to add one." })
	grow:SetPoint("TOPLEFT", 0, y - 2)
	local bars = UI.Text(f, "", 11, false, C.dim)
	bars:SetPoint("LEFT", grow, "RIGHT", 12, 0)
	bars:SetWidth(width - 140 - 130)
	bars:SetWordWrap(true)
	local apply
	apply = UI.Button(f, "Set up", 120, function()
		if apply.dimmed or InCombatLockdown() then return end
		local picks = Picks()
		L.Report(L.SetUp(picks.size, picks.style))
		own = nil
		f:Refresh()
	end)
	apply:SetPoint("TOPRIGHT", 0, y)
	UI.SetFill(apply, C.fill)
	local foot = -y + 24
	local status = UI.Text(f, "", 12)
	status:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -foot - 10)
	status:SetWidth(width)
	status:SetWordWrap(true)
	f:SetSize(width, foot + 10 + 34)
	f.stage, f.buttons, f.styles, f.grow, f.apply = stage, buttons, styles, grow, apply

	-- A click on a choice.
	function f:Choose(field, key)
		Picks()[field] = key
		self:Refresh()
	end

	-- Preview the choice under the mouse. The drawing is laid again (some 180 ms) once the mouse has rested
	-- P.DWELL on a choice, or off them all: laid at once, crossing the choices laid it at every card's edge,
	-- once to leave one and once to come onto the next.
	local dwell = CreateFrame("Frame", nil, f)
	dwell:Hide()
	dwell:SetScript("OnUpdate", function(self, elapsed)
		self.left = self.left - elapsed
		if self.left > 0 then return end
		self:Hide()
		f:Refresh(true)
	end)
	function f:Look(field, key)
		self.looking = field and { field = field, key = key } or nil
		dwell.left = P.DWELL
		dwell:Show()
	end

	-- Something to set up: not in use, out of date, or picks other than the console's.
	local function Pending(picks)
		if not L.IsActive() or L.IsStale() then return true end
		if picks.style ~= L.Style() or picks.size ~= L.Size() then return true end
		return L.Grows() and L.GrowStep() ~= L.StepNow()
	end

	-- What a fight changes: the choices dimmed and the line under them. `pending` is worked out only if asked.
	local function Status(picks, pending)
		local fighting, active, size, style = InCombatLockdown(), L.IsActive(), L.Size(), L.Style()
		for _, b in pairs(buttons) do b:SetAlpha(fighting and 0.4 or 1) end
		for _, b in pairs(styles) do b:SetAlpha(fighting and 0.4 or 1) end
		apply.dimmed = fighting
		apply:SetAlpha(apply.dimmed and 0.4 or 1)
		local change = picks.style ~= style or picks.size ~= size
		if fighting then
			UI.Ink(status, C.dim)
			status:SetText("You're in combat. You can set up the console after the fight.")
		elseif active and change then
			UI.Ink(status, C.text)
			status:SetText(("Press Set up to switch to %s, %s. Needs a reload."):format(P.STYLES[picks.style], P.NAMES[picks.size]:lower()))
		elseif active and L.IsStale() then
			UI.Ink(status, C.alert)
			status:SetText("Your bars, unit frames or skins changed since the console was set up. Set up refits it. Needs a reload.")
		elseif active and (pending == nil and Pending(picks) or pending) then
			UI.Ink(status, C.text)
			status:SetText(L.GrowStep() > L.StepNow() and "Your abilities have outgrown your bars. Set up adds what they need. Needs a reload."
				or "Set up puts away the bars you don't need yet; their buttons are kept. Needs a reload.")
		elseif active then
			UI.Ink(status, C.good)
			status:SetText("The console is in use. Pick another layout or size, or press Put it back to reset every piece. Needs a reload.")
		else
			UI.Ink(status, C.dim)
			status:SetText(L.Exists() and "You're using another Edit Mode layout. Set up switches back to the console. Needs a reload."
				or "Not set up on this character. Set up adds an Edit Mode layout named \"Shy\"; your own layout is kept. Needs a reload.")
		end
	end

	-- A drawing is some 17 ms and 450 KB to lay, and there are nine: the console's own and a card's each.
	-- One asked for what it already shows is left as it is while only the mouse has moved (looking); the
	-- console's own is laid at once and the cards' one a frame after it (waiting, the painter).
	-- (from: what a drawing is planned from besides the choice: the console's inputs as its setup signs them,
	-- L.Signatures, and the look worn. A card's drawing is left while all of it is the same, at a showing too:
	-- laid again, the game lays the whole room out again for it.)
	local function Shows(st, size, style, grow, from)
		return st.shows == size .. "|" .. style .. "|" .. tostring(grow) .. "|" .. from
	end
	local function Draw(st, size, style, grow, from)
		st.shows = size .. "|" .. style .. "|" .. tostring(grow) .. "|" .. from
		st:Draw(size, style, grow)
	end
	local function From()
		local ok, _, inputs = pcall(L.Signatures)
		-- (Unreadable: never the same, so every drawing is laid.)
		if not ok or inputs == nil then return tostring(GetTime()) end
		return tostring(inputs) .. "|" .. tostring(Shy.Theme.Look())
	end
	local waiting = {}
	local painter = CreateFrame("Frame", nil, f)
	painter:Hide()
	painter:SetScript("OnUpdate", function(self)
		local job = table.remove(waiting, 1)
		if job then Draw(job[1], job[2], job[3], job[4], job[5]) end
		if not waiting[1] then self:Hide() end
	end)

	-- looking: asked only because the mouse rests on another choice, or on none.
	function f:Refresh(looking)
		local active, size, style = L.IsActive(), L.Size(), L.Style()
		local picks = Picks()
		local drawn = { style = picks.style, size = picks.size, grow = picks.grow }
		if self.looking then drawn[self.looking.field] = self.looking.key end
		local from = From()
		if not (looking and Shows(stage, drawn.size, drawn.style, drawn.grow, from)) then Draw(stage, drawn.size, drawn.style, drawn.grow, from) end
		for key, b in pairs(buttons) do b:Paint(picks.size == key, active and size == key) end
		wipe(waiting)
		for key, b in pairs(styles) do
			if not Shows(b.stage, drawn.size, key, drawn.grow, from) then
				waiting[#waiting + 1] = { b.stage, drawn.size, key, drawn.grow, from }
			end
			b:Paint(picks.style == key, active and style == key)
		end
		painter:SetShown(waiting[1] ~= nil)
		grow:Refresh()
		bars:SetText(P.BarsWords(drawn.grow))
		local pending = Pending(picks)
		-- With nothing to change the button sets the console up again as it is: every piece back in its
		-- place and at its size.
		apply.text:SetText((active and not pending) and "Put it back" or "Set up")
		Status(picks, pending)
	end

	-- A fight begins or ends: only what it changes. The drawings stay as they are.
	function f:Dim()
		Status(Picks())
	end

	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(self)
		if self:IsVisible() then self:Dim() end
	end)
	f:SetScript("OnHide", function(self)
		self.looking = nil
		own = nil
	end)
	sections[#sections + 1] = f
	return f
end

function P.Refresh()
	for _, section in ipairs(sections) do
		if section:IsVisible() then section:Refresh() end
	end
end
