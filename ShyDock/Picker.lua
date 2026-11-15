-- Picking the cooldown manager's size and the tracked bars' side: one section for the setup window's
-- Cooldowns step, the /shy window and ShyDock's options page. The vessel is drawn from the same plan and
-- art as the HUD, and the size and the bars' side are chips that draw their choice: beside the drawing on
-- the setup window's wide page, under it on the narrower ones. Pointing at
-- a choice draws it; a click applies at once (in setup it goes into the plan as well). The housings
-- wear the theme's look (the setup's Theme page picks it, and a setup page draws in that pick). Also the
-- drawing of the vessel itself,
-- which Preview.lua's stage asks for (ns.Vessel.DrawOn): the icons are your own (the viewers' and
-- the stance bar's pictures, when they can be read), else plain tiles.

local ADDON, ns = ...
local T = ns.T
local UI, Skin, Theme = Shy.UI, Shy.Skin, Shy.Theme
local C = UI.colors
local max, min, floor = math.max, math.min, math.floor

local V = ns.Vessel or {}
ns.Vessel = V

local GAP, STAGE_H = 8, 180
local ROW_X = 48                       -- the chips start here, after the row's label
local SIZE_W, SIZE_H = 92, 46          -- a size chip
local SIDE_W = 74                      -- a bars' side chip
-- A page this wide or wider (the setup window's) has two columns: the choices, then the drawing beside them.
local COLUMNS, COLUMN_H, COLUMN_GAP = 700, 170, 24
local CHOICES_W = 3 * SIZE_W + 2 * GAP -- the choices' column: the size's chips
local LABEL_H, ROW_GAP = 20, 16        -- a label over its chips; between the two
local LIT = 3                          -- combo points drawn lit
local sections = {}

-- Your own pictures: the icons the viewers and the stance bar hold, by row, when they can be read.
local function Pictures(key, limit)
	local out = {}
	local function Take(texture)
		if texture ~= nil and not issecretvalue(texture) and #out < limit then out[#out + 1] = texture end
	end
	local function Of(region)
		if type(region) ~= "table" then return nil end
		if type(region.Icon) == "table" then region = region.Icon end   -- a bar item's picture is a frame holding it
		if type(region.GetTexture) == "function" then return region:GetTexture() end
		return nil
	end
	if key == "stances" then
		for i = 1, limit do
			local button = _G["StanceButton" .. i]
			if type(button) == "table" then Take(Of(button.icon)) end
		end
		return out
	end
	local viewer = ({ gems = EssentialCooldownViewer, utility = UtilityCooldownViewer, buffs = BuffIconCooldownViewer, bars = BuffBarCooldownViewer })[key]
	if not (type(viewer) == "table" and type(viewer.itemFramePool) == "table") then return out end
	for item in viewer.itemFramePool:EnumerateActive() do
		Take(Of(item.Icon))
	end
	return out
end

-- The drawing

-- Draws the vessel from plan `c` on stage S (Preview.lua) with its tools, and returns the group's
-- rectangle (left, bottom, right, top) in plan units.
function V.DrawOn(S, c, now)
	local t, L, P = S.tools, ns.Layout, ns.Preview
	local colors = P.COLORS
	-- The plan's own measures (its grid): every icon, gap and pad as planned, on the drawing's pixels.
	local m = c.m
	local present = c.present or L.Present(now)
	local ACCENT = Theme.Accent
	local l, b, r, top
	local function Add(rect)
		if not rect then return end
		l, b = min(l or rect[1], rect[1]), min(b or rect[2], rect[2])
		r, top = max(r or rect[3], rect[3]), max(top or rect[4], rect[4])
	end
	local box = c.rects.box

	-- A housing of the vessel's make (Cockpit.lua's: the bar housing's), in the drawing's look.
	local function Housing(key, rect)
		Add(rect)
		return t.Panel(key, 4, ns.Cockpit.HOUSING, rect[1], rect[2], rect[3], rect[4], ns.CockpitGraphite)
	end
	-- A row's area: nothing is drawn round a row.
	local function Socket(key, rect)
		local f = t.Piece(key, 5)
		t.Put(f, rect[1], rect[2], rect[3], rect[4])
		Add(rect)
		return f
	end
	-- An icon: your own picture when there is one, else a plain tile.
	local function Icon(f, pictures, i, x, y, size)
		local picture = pictures and pictures[i]
		if picture then t.Picture(f, picture, x, y, size) else t.Icon(f, x, y, size) end
	end

	local gems, buff = c.rects.gems, c.rects.buffs
	local buffPad = m.slot
	local count = now.tracked or 0
	local buffsUp = present.buffs and count > 0 and buff ~= nil
	-- Only what the plan has showing is drawn: a row that waits stands in no plate.
	local gemsUp = present.gems and c.shows.gems
	local buffSocket = buffsUp and { c.buffsRight - c.buffsSpan - buffPad, buff[2] - buffPad, c.buffsRight + buffPad, buff[4] + buffPad } or nil
	-- The tracked bars' home beside the plate (a classic layout's; by role it stands by your frames, off this
	-- drawing), then the plate.
	local wing = c.rects.barsWing
	local flapUp = wing and present.bars and S.focus and not S.mini and not ns.Console.ROLES[now.style]
	if flapUp then
		local flap = Housing("flap", wing)
		local rib = c.rects.rib
		if rib and flap then t.Art(flap, UI.RIB, Theme.skin.metal, 1, 2, rib[1], rib[2], rib[3], rib[4], nil, true) end
	end
	local body = Housing("box", box)

	-- The display's block: one frame round its bars (and the swing row, and the cast bar's row while a cast
	-- is up and nothing hangs between), the gaps its dividers.
	local d = c.rects.display
	local swing = c.rects.swing
	local castUp = present.cast and c.casting and c.rects.cast ~= nil
	local castJoined = castUp and c.castIn == "block"
	local seam = m.seam
	-- The cast bar's row: the spell's picture, a seam, the bar.
	local function CastRow(f)
		local y = c.cast
		t.Icon(f, c.castLeft - c.castGap - c.castSide, y, c.castSide)
		t.Flat(f, Theme.skin.metal, 0.85, 2, c.castLeft - c.castGap, y, c.castLeft, y + c.castHeight)
		t.Bar(f, ACCENT, 1, c.castLeft, y, c.castLeft + c.castWidth, y + c.castHeight)
	end
	if present.display then
		local F = m.frame
		local foot = (swing and present.swing) and swing[2] or d[2]
		if castJoined then foot = c.cast end
		local block = t.Piece("block", 6)
		t.Put(block, d[1] - F, foot - F, d[3] + F, d[4] + F)
		-- The bars a seam apart, each seam a hairline of the frame's steel (Cockpit.lua's Block).
		t.Art(block, Skin.FRAME, Theme.skin.metal, 1, 4, d[1] - F, foot - F, d[3] + F, d[4] + F, Skin.FRAME_SLICE)
		t.Bar(block, colors.HEALTH, 1, d[1], d[4] - m.health, d[3], d[4])
		local power = colors.POWER[now.class] or colors.MANA
		local powerTop = d[4] - m.health - seam
		t.Flat(block, Theme.skin.metal, 0.85, 2, d[1], powerTop, d[3], powerTop + seam)
		t.Bar(block, power, 1, d[1], powerTop - m.power, d[3], powerTop)
		if (now.altH or 0) > 0 then
			t.Flat(block, Theme.skin.metal, 0.85, 2, d[1], d[2] + m.power, d[3], d[2] + m.power + seam)
			t.Bar(block, colors.MANA, 1, d[1], d[2], d[3], d[2] + m.power)
		end
		if swing and present.swing then
			t.Flat(block, Theme.skin.metal, 0.85, 2, d[1], swing[4], d[3], swing[4] + seam)
			t.Bar(block, Theme.SCHOOL[1], 1, swing[1], swing[2], swing[3], swing[4], 0.6)
		end
		if castJoined then
			local top = c.cast + c.castHeight
			t.Flat(block, Theme.skin.metal, 0.85, 2, d[1], top, d[3], top + seam)
			CastRow(block)
		end
	elseif swing and present.swing then
		t.Bar(body, Theme.SCHOOL[1], 1, swing[1], swing[2], swing[3], swing[4], 0.6)
	end
	-- The cast bar's row in a frame of its own, under what hangs at the plate's foot.
	if castUp and not castJoined and S.focus and not S.mini then
		local rect = c.rects.cast
		local own = t.Piece("cast", 6)
		t.Put(own, rect[1], rect[2], rect[3], rect[4])
		t.Art(own, Skin.FRAME, Theme.skin.metal, 1, 4, rect[1], rect[2], rect[3], rect[4], Skin.FRAME_SLICE)
		CastRow(own)
	end

	-- The small tiles: the utility cooldowns from the foot's left end, the stances at its right end.
	if present.tiles then
		local under = c.rects.tiles
		local foot = Socket("tiles", under)
		local size, step = m.tile, m.tile + m.tileGap
		local stances = c.rects.stances
		if stances and present.stances then
			local pictures = Pictures("stances", now.forms or 0)
			for i = 1, now.forms or 0 do Icon(foot, pictures, i, stances[1] + (i - 1) * step, c.row, size) end
		end
		local utility = c.rects.utility
		if present.utility and utility[3] - utility[1] > size / 2 then
			local n = max(1, floor((utility[3] - utility[1] + m.tileGap) / step + 0.5))
			local pictures = Pictures("utility", n)
			for i = 1, n do Icon(foot, pictures, i, utility[1] + (i - 1) * step, c.row, size) end
		end
	end

	-- The gems: as many as there are, the first row on top, the last maybe not full.
	if gemsUp then
		local slot = Socket("gems", gems)
		local size, step = m.gem, m.gem + m.gemGap
		local across, n = c.gemsAcross or 1, c.gemsCount or 1
		local down = math.ceil(n / across)
		local pictures = Pictures("gems", n)
		for i = 1, n do
			local row, column = floor((i - 1) / across), (i - 1) % across
			Icon(slot, pictures, i, c.gemsLeft + column * step, c.gems + (down - 1 - row) * step, size)
		end
	end

	-- Tracked buffs in their socket.
	if buffsUp then
		local size = buff[4] - buff[2]
		local tracked = Socket("buffs", buffSocket)
		local gap = m.buffGap
		local n = max(1, floor((c.buffsSpan + gap) / (size + gap) + 0.5))
		local pictures = Pictures("buffs", n)
		for i = 1, n do
			Icon(tracked, pictures, i, c.buffsRight - i * size - (i - 1) * gap, buff[2], size)
		end
	end

	-- The tracked bars in the flap.
	if flapUp then
		local flap = t.Piece("flap", 4)
		local pad, barH = m.pad, m.barH
		local left = wing[1] + pad
		-- As many bars as the flap has room for.
		local up = max(1, floor((wing[4] - wing[2] - 2 * pad + m.barGap) / (barH + m.barGap) + 0.5))
		local pictures = Pictures("bars", up)
		for i = 1, up do
			local foot = wing[2] + pad + (i - 1) * (barH + m.barGap)
			Icon(flap, pictures, i, left, foot, barH)
			t.Bar(flap, ACCENT, 1, left + barH, foot, wing[3] - pad, foot + barH, 0.7 - 0.2 * (i - 1))
		end
	end

	-- Combo blades, drawn from ShyRogue's own art and numbers (Shy.addons.Rogue.Blades).
	local blades, D = c.rects.blades, Shy.addons.Rogue and Shy.addons.Rogue.Blades
	if blades and D then
		local cut = t.Piece("blades", 5)
		t.Put(cut, blades[1], blades[2], blades[3], blades[4])
		-- The blades' own scale: their art is drawn for D.w by D.h.
		local scale = (blades[3] - blades[1]) / D.w
		cut:SetScale(scale)
		Add(blades)
		local x0, y0 = blades[1] / scale, blades[2] / scale
		t.Art(cut, D.slotArt, Theme.skin.metal, 1, 0, x0 - D.slot, y0 - D.slot, x0 + D.w + D.slot, y0 + D.h + D.slot)
		for i = 1, D.count do
			local x, foot = x0 + D.x + (i - 1) * (D.body + D.gap), y0 + D.y
			local red, green, blue = Theme.Combo(i, D.count)
			local bl2, bb = x - D.margin, foot - D.margin
			t.Art(cut, D.well, { 0.05 + red * 0.26, 0.05 + green * 0.26, 0.05 + blue * 0.26 }, 1, 1, bl2, bb, bl2 + D.canvas[1], bb + D.canvas[2])
			if i <= LIT then
				t.Art(cut, D.shadow, { 0, 0, 0 }, 1, 2, bl2, bb, bl2 + D.canvas[1], bb + D.canvas[2])
				t.Art(cut, D.art, { red, green, blue }, 1, 3, bl2, bb, bl2 + D.canvas[1], bb + D.canvas[2])
			end
		end
	end
	return l or box[1], b or box[2], r or box[3], top or box[4]
end

-- The vessel drawn alone, large: a stage of Preview.lua's focused on it; `mini` for a thumbnail; `look`
-- a function giving the look its housings wear (a setup plan's pick), nil for the theme's.
function V.Stage(parent, width, height, mini, look)
	return ns.Preview.Stage(parent, width, { focus = "vessel", height = height or STAGE_H, mini = mini, look = look })
end

-- The size as a word: a chip's name, or the percent.
local function SizeWords(scale)
	local key = V.SizeOf(scale)
	if key then return V.NAMES[key]:lower() end
	return floor(scale * 100 + 0.5) .. "%"
end

-- The section

-- A chip: a small button lit when picked; pointed at, the drawing shows that choice. `draw` adds its drawing:
-- a size chip draws the box at its size, a bars chip the flap at its side.
local function Chip(section, field, key, width, height, draw)
	local b = UI.Button(section, V.NAMES[key], width, function()
		if InCombatLockdown() then return end
		section:Choose(field, key)
	end)
	b:SetHeight(height)
	if draw then
		b.text:ClearAllPoints()
		b.text:SetPoint("BOTTOM", 0, 6)
		draw(b)
	end
	b:HookScript("OnEnter", function() section:Look(field, key) end)
	b:HookScript("OnLeave", function() section:Look(nil) end)
	function b:Paint(lit)
		UI.SetFill(self, lit and C.fill or C.bgHot)
		UI.SetBorder(self, lit and C.hot or C.border)
	end
	return b
end

-- A little box of the vessel's make, for a chip's drawing.
local function Little(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	UI.Skin(f, C.panel, Theme.skin.metal)
	return f
end

local function SizeDrawing(scale)
	return function(chip)
		local w, h = 44 * scale, 12 * scale
		local little = Little(chip, w, h)
		little:SetPoint("TOP", 0, -(16 - h / 2))
	end
end

local function SideDrawing(side)
	return function(chip)
		local box = Little(chip, 30, 16)
		local flap = Little(chip, 14, 10)
		box:SetPoint("TOP", side == "left" and 6 or -6, -8)
		flap:SetPoint(side == "left" and "RIGHT" or "LEFT", box, side == "left" and "LEFT" or "RIGHT", side == "left" and -4 or 4, 0)
	end
end

-- parent, width; plan: the setup window's plan (picks go into plan.cooldowns, and the drawings wear the
-- look its theme page picked), or nil to apply at once.
function V.Section(parent, width, plan)
	local L = ns.Layout
	local f = CreateFrame("Frame", nil, parent)
	local looking
	local sizes, sides = {}, {}
	local look = plan and function() return plan.theme and plan.theme.look end or nil

	local function Label(text, x, y)
		local label = UI.Text(f, text, 12, true, C.head)
		label:SetPoint("TOPLEFT", x, y)
	end
	local function Sizes(x, y)
		for i, key in ipairs(V.SIZES) do
			local chip = Chip(f, "size", key, SIZE_W, SIZE_H, SizeDrawing(V.SCALES[key]))
			chip:SetPoint("TOPLEFT", x + (i - 1) * (SIZE_W + GAP), y)
			sizes[key] = chip
		end
	end
	local function Sides(x, y)
		for i, key in ipairs(V.SIDES) do
			local chip = Chip(f, "side", key, SIDE_W, SIZE_H, SideDrawing(key))
			chip:SetPoint("TOPLEFT", x + (i - 1) * (SIDE_W + 6), y)
			sides[key] = chip
		end
	end
	local stage
	if width >= COLUMNS then
		-- Two columns: the choices at the left, each under its label, in the middle of the drawing's height;
		-- the drawing beside them, the rest of the width.
		local choices = 2 * (LABEL_H + SIZE_H) + ROW_GAP
		local y = -floor((COLUMN_H - choices) / 2)
		Label("Size", 0, y)
		Sizes(0, y - LABEL_H)
		y = y - LABEL_H - SIZE_H - ROW_GAP
		Label("Tracked bars", 0, y)
		Sides(0, y - LABEL_H)
		stage = V.Stage(f, width - CHOICES_W - COLUMN_GAP, COLUMN_H, nil, look)
		stage.holder:SetPoint("TOPLEFT", CHOICES_W + COLUMN_GAP, 0)
		f:SetSize(width, COLUMN_H)
	else
		-- Narrower: the drawing, then the size's chips after their label and the bars' side's after theirs on one row.
		stage = V.Stage(f, width, STAGE_H, nil, look)
		stage.holder:SetPoint("TOPLEFT")
		local y = -STAGE_H - GAP - 16
		Label("Size", 0, y - 16)
		Sizes(ROW_X, y)
		local sideX = ROW_X + 3 * (SIZE_W + GAP) + 18
		Label("Tracked bars", sideX, y - 16)
		Sides(sideX + 92, y)
		f:SetSize(width, -(y - SIZE_H))
	end
	f.stage, f.sizes, f.sides = stage, sizes, sides

	-- What is picked: the plan's, or the settings in use.
	local function Picks()
		if plan then return plan.cooldowns end
		return { scale = L.Scale(), side = L.BarsSide() }
	end

	function f:Choose(field, key)
		local picks = Picks()
		if field == "size" then picks.scale = V.SCALES[key] else picks[field] = key end
		-- At once, in setup too (its window puts back what stood when it closes without Finish).
		T.db.cockpitScale, T.db.barsSide = picks.scale, picks.side
		T:Apply()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self:Refresh()
	end

	function f:Look(field, key)
		looking = field and { field = field, key = key } or nil
		self:Refresh()
	end

	function f:Refresh()
		local picks = Picks()
		local shown = { scale = picks.scale, side = picks.side }
		if looking then
			if looking.field == "size" then shown.scale = V.SCALES[looking.key] else shown[looking.field] = looking.key end
		end
		stage:Draw(nil, nil, nil, shown)
		local size = V.SizeOf(picks.scale)
		for key, chip in pairs(sizes) do chip:Paint(size == key) end
		for key, chip in pairs(sides) do chip:Paint(picks.side == key) end
		self:Dim()
	end

	-- Nothing can be picked in a fight: a fight beginning or ending dims the chips, and the drawing stays.
	function f:Dim()
		local alpha = InCombatLockdown() and 0.4 or 1
		for _, chip in pairs(sizes) do chip:SetAlpha(alpha) end
		for _, chip in pairs(sides) do chip:SetAlpha(alpha) end
	end

	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(self)
		if self:IsVisible() then self:Dim() end
	end)
	f:SetScript("OnShow", function(self) self:Refresh() end)
	f:SetScript("OnHide", function() looking = nil end)
	sections[#sections + 1] = f
	return f
end

-- Settings changed (T:Apply): every section on show draws again.
function V.Refresh()
	for _, section in ipairs(sections) do
		if section:IsVisible() then section:Refresh() end
	end
end

-- The picks are profile settings: written now when the character stays on its profile, else kept by
-- the setup until the profile it switches to (or starts afresh) has loaded after the reload.
local function Keep(p)
	T.db.barsSide = p.side
	T.db.cockpitScale = ns.Layout.ClampScale(p.scale)
	T:Apply()
end

-- The setup window's step, after the screen's: no reload of its own.
Shy.Setup.Step({
	id = "cooldowns", order = 21, title = "Cooldowns", glyph = "clock", tab = "screen",
	ask = "Pick the cooldown manager's size",
	lead = "Its size and the tracked bars' side, under your character. Drag it, size it or take it apart later in layout mode.",
	brief = function(plan)
		local p = plan.cooldowns
		return (SizeWords(p.scale):gsub("^%l", string.upper)) .. ", bars " .. p.side
	end,
	Plan = function(plan)
		local L = ns.Layout
		plan.cooldowns = { scale = L.Scale(), side = L.BarsSide() }
	end,
	Build = function(parent, width, plan) return V.Section(parent, width, plan) end,
	Lines = function(plan)
		local p = plan.cooldowns
		return { { text = ("Cooldown manager: %s"):format(SizeWords(p.scale)),
			sub = "under your character; drag it, size it or take it apart in layout mode" } }
	end,
	Run = function(plan)
		local p = plan.cooldowns
		local answers = { scale = p.scale, side = p.side }
		if Shy.Setup.Act(plan) == "stay" then Keep(answers) else Shy.Setup.Wait("cooldowns", answers) end
		return false
	end,
	Later = Keep,
	-- Live: each pick goes on at once (V.Section); closing without Finish puts back what stood.
	Worn = function()
		return { scale = T.db.cockpitScale, side = T.db.barsSide }
	end,
	PutBack = function(kept)
		if T.db.cockpitScale == kept.scale and T.db.barsSide == kept.side then return end
		T.db.cockpitScale, T.db.barsSide = kept.scale, kept.side
		T:Apply()
	end,
})

-- The /shy window's Screen room, under the console.
Shy.HubSection("screen", function(page, top)
	local head = Shy.HubHead(page, top, "Cooldown manager")
	local words = UI.Text(page, "Its size and the bars' side. Changes apply now; drag it or take it apart in layout mode.", 12, false, C.dim)
	words:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
	words:SetWidth(page.width)
	words:SetWordWrap(false)
	local section = V.Section(page, page.width)
	section:SetPoint("TOPLEFT", words, "BOTTOMLEFT", 0, -12)
	return section, function() section:Refresh() end
end, 40)
